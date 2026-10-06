import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../motor/puntos.dart';

enum EstadoCamara { iniciando, lista, sinPermiso, sinCamara, error }

/// Convierte coordenadas de ML Kit (imagen) a un lienzo del tamaño de la vista
/// previa. Compensa la rotación del sensor y el espejo de la cámara frontal
/// (según el ejemplo oficial de google_mlkit).
Offset aLienzo(
  double x,
  double y,
  Size lienzo,
  Size tamanoImagen,
  InputImageRotation rotacion,
  CameraLensDirection lente,
) {
  final ancho = Platform.isIOS ? tamanoImagen.width : tamanoImagen.height;
  final alto = Platform.isIOS ? tamanoImagen.height : tamanoImagen.width;
  switch (rotacion) {
    case InputImageRotation.rotation90deg:
      return Offset(x * lienzo.width / ancho, y * lienzo.height / alto);
    case InputImageRotation.rotation270deg:
      return Offset(lienzo.width - x * lienzo.width / ancho, y * lienzo.height / alto);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      final px = x * lienzo.width / tamanoImagen.width;
      return Offset(
        lente == CameraLensDirection.back ? px : lienzo.width - px,
        y * lienzo.height / tamanoImagen.height,
      );
  }
}

/// Cámara + detección de pose con ML Kit, en el teléfono. Se puede compartir
/// entre varias series (rutinas guiadas) sin volver a abrir la cámara.
class CamaraPose extends ChangeNotifier {
  final bool preferirFrontal;

  /// Se llama con cada cuadro analizado (con o sin persona).
  void Function(Fotograma fotograma)? alFotograma;

  CamaraPose({required this.preferirFrontal});

  CameraController? camara;
  CameraDescription? _descripcion;
  List<CameraDescription> _camaras = const [];
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base),
  );
  bool _procesando = false;
  bool _cerrado = false;
  final Stopwatch _base = Stopwatch()..start();
  int _ultimoTMs = -1;

  EstadoCamara estado = EstadoCamara.iniciando;
  String? mensajeError;
  List<Punto>? puntos;
  Size? tamanoImagen;
  InputImageRotation rotacion = InputImageRotation.rotation0deg;
  CameraLensDirection lente = CameraLensDirection.front;

  /// Cuadros analizados por segundo (promedio móvil), útil para diagnosticar
  /// el rendimiento en cada teléfono.
  double cuadrosPorSegundo = 0;

  bool get puedeCambiarCamara => _camaras.length > 1;
  bool get lista => estado == EstadoCamara.lista && camara != null;

  /// Relación de aspecto (ancho/alto) de la vista previa en vertical.
  double get aspecto {
    final t = camara?.value.previewSize;
    return t == null ? 9 / 16 : t.height / t.width;
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  Future<void> iniciar() async {
    estado = EstadoCamara.iniciando;
    mensajeError = null;
    _notificar();
    try {
      _camaras = await availableCameras();
    } on CameraException catch (e) {
      _fallar(e);
      return;
    } catch (e) {
      // Plataformas sin cámara (escritorio, pruebas) lanzan otros errores.
      estado = EstadoCamara.sinCamara;
      mensajeError = '$e';
      _notificar();
      return;
    }
    if (_cerrado) return;
    if (_camaras.isEmpty) {
      estado = EstadoCamara.sinCamara;
      _notificar();
      return;
    }
    final preferida = preferirFrontal ? CameraLensDirection.front : CameraLensDirection.back;
    await _abrir(_camaras.firstWhere((c) => c.lensDirection == preferida, orElse: () => _camaras.first));
  }

  Future<void> _abrir(CameraDescription descripcion) async {
    final anterior = camara;
    camara = null;
    _notificar();
    await _cerrarCamara(anterior);

    final c = CameraController(
      descripcion,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await c.initialize();
      if (_cerrado) {
        await c.dispose();
        return;
      }
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _descripcion = descripcion;
      lente = descripcion.lensDirection;
      camara = c;
      puntos = null;
      await c.startImageStream(_procesarImagen);
      estado = EstadoCamara.lista;
    } on CameraException catch (e) {
      await c.dispose();
      _fallar(e);
      return;
    }
    _notificar();
  }

  void _fallar(CameraException e) {
    const sinPermiso = {'CameraAccessDenied', 'CameraAccessDeniedWithoutPrompt', 'CameraAccessRestricted'};
    estado = sinPermiso.contains(e.code) ? EstadoCamara.sinPermiso : EstadoCamara.error;
    mensajeError = e.description ?? e.code;
    _notificar();
  }

  Future<void> _cerrarCamara(CameraController? c) async {
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c.dispose();
  }

  Future<void> cambiarCamara() async {
    if (!puedeCambiarCamara) return;
    final otra = _camaras.firstWhere((c) => c.lensDirection != lente, orElse: () => _camaras.first);
    await _abrir(otra);
  }

  /// Libera la cámara (app en segundo plano o al terminar).
  Future<void> pausar() async {
    final c = camara;
    camara = null;
    _notificar();
    await _cerrarCamara(c);
  }

  Future<void> reanudar() async {
    final d = _descripcion;
    if (_cerrado || d == null || camara != null) return;
    await _abrir(d);
  }

  InputImage? _aInputImage(CameraImage imagen) {
    final c = camara;
    final d = _descripcion;
    if (c == null || d == null) return null;
    const orientaciones = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    InputImageRotation? rot;
    if (Platform.isIOS) {
      rot = InputImageRotationValue.fromRawValue(d.sensorOrientation);
    } else {
      var compensacion = orientaciones[c.value.deviceOrientation];
      if (compensacion == null) return null;
      compensacion = d.lensDirection == CameraLensDirection.front
          ? (d.sensorOrientation + compensacion) % 360
          : (d.sensorOrientation - compensacion + 360) % 360;
      rot = InputImageRotationValue.fromRawValue(compensacion);
    }
    if (rot == null) return null;
    final formato = InputImageFormatValue.fromRawValue(imagen.format.raw as int);
    if (formato == null ||
        (Platform.isAndroid && formato != InputImageFormat.nv21) ||
        (Platform.isIOS && formato != InputImageFormat.bgra8888)) {
      return null;
    }
    if (imagen.planes.length != 1) return null;
    final plano = imagen.planes.first;
    rotacion = rot;
    return InputImage.fromBytes(
      bytes: plano.bytes,
      metadata: InputImageMetadata(
        size: Size(imagen.width.toDouble(), imagen.height.toDouble()),
        rotation: rot,
        format: formato,
        bytesPerRow: plano.bytesPerRow,
      ),
    );
  }

  Future<void> _procesarImagen(CameraImage imagen) async {
    // Si el detector sigue ocupado se descarta el cuadro: siempre se analiza el más reciente.
    if (_procesando || _cerrado) return;
    _procesando = true;
    try {
      final entrada = _aInputImage(imagen);
      if (entrada == null) return;
      final poses = await _detector.processImage(entrada);
      if (_cerrado) return;
      var tMs = _base.elapsedMilliseconds;
      if (tMs <= _ultimoTMs) tMs = _ultimoTMs + 1;
      if (_ultimoTMs > 0) {
        final instantaneo = 1000 / (tMs - _ultimoTMs);
        cuadrosPorSegundo = cuadrosPorSegundo == 0 ? instantaneo : cuadrosPorSegundo * 0.9 + instantaneo * 0.1;
      }
      _ultimoTMs = tMs;
      tamanoImagen = Size(imagen.width.toDouble(), imagen.height.toDouble());

      Fotograma fotograma;
      if (poses.isEmpty) {
        puntos = null;
        fotograma = Fotograma(tMs);
      } else {
        final marcas = poses.first.landmarks;
        final lista = List<Punto>.generate(numPuntos, (i) {
          final m = marcas[PoseLandmarkType.values[i]];
          return m == null ? Punto.ausente : Punto(m.x, m.y, m.z, m.likelihood);
        });
        puntos = lista;
        fotograma = Fotograma(tMs, imagen: lista);
      }
      alFotograma?.call(fotograma);
      _notificar();
    } catch (e) {
      debugPrint('Error de detección: $e');
    } finally {
      _procesando = false;
    }
  }

  /// Puntos actuales en coordenadas de pantalla normalizadas (0–1), para
  /// grabar el esqueleto tal como lo vio la persona.
  Map<int, (Offset, double)>? puntosNormalizados(List<int> indices) {
    final p = puntos, t = tamanoImagen;
    if (p == null || t == null) return null;
    const lienzo = Size(1, 1);
    return {for (final i in indices) i: (aLienzo(p[i].x, p[i].y, lienzo, t, rotacion, lente), p[i].v)};
  }

  @override
  void dispose() {
    _cerrado = true;
    final c = camara;
    camara = null;
    _cerrarCamara(c);
    _detector.close();
    super.dispose();
  }
}
