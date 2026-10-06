import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/config/app_config.dart';
import '../../modelos/resultado_analisis.dart';
import '../../motor/analizador.dart';
import '../../motor/especificacion.dart';
import '../../motor/metricas.dart';
import '../../motor/puntos.dart';
import '../../motor/repeticiones.dart';
import '../../servicios/voz_servicio.dart';

enum EtapaSesion { iniciando, sinPermiso, sinCamara, error, encuadre, cuentaRegresiva, activa, finalizando }

class AvisoEnVivo {
  final String titulo;
  final String? detalle;

  /// null = mensaje positivo.
  final Severidad? severidad;
  final DateTime hora;

  AvisoEnVivo(this.titulo, {this.detalle, this.severidad}) : hora = DateTime.now();
}

/// Orquesta la cámara, la detección de pose de ML Kit (en el teléfono) y el
/// motor de análisis. La pantalla solo escucha este controlador y dibuja.
class ControladorTiempoReal extends ChangeNotifier {
  final Especificacion spec;
  final EjercicioSpec ejercicio;
  final VozServicio voz;
  bool vozActiva;
  final bool preferirFrontal;

  ControladorTiempoReal({
    required this.spec,
    required this.ejercicio,
    required this.voz,
    required this.vozActiva,
    required this.preferirFrontal,
  });

  // Cámara y detector
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

  // Estado expuesto a la interfaz
  EtapaSesion etapa = EtapaSesion.iniciando;
  String? mensajeError;
  List<Punto>? puntos;
  Size? tamanoImagen;
  InputImageRotation rotacion = InputImageRotation.rotation0deg;
  CameraLensDirection lente = CameraLensDirection.front;
  List<String> faltantes = const [];
  EstadoFotograma? estado;
  int cuenta = AppConfig.cuentaRegresiva;
  AvisoEnVivo? aviso;
  RepeticionEvaluada? ultimaRep;
  DateTime _horaUltimaRep = DateTime.fromMillisecondsSinceEpoch(0);
  final Stopwatch reloj = Stopwatch();

  Analizador? _analizador;
  int _cuadrosEncuadrados = 0;
  Timer? _temporizador;
  DateTime _ultimoAvisoFaltantes = DateTime.fromMillisecondsSinceEpoch(0);

  bool get puedeCambiarCamara => _camaras.length > 1;
  int get repeticiones => _analizador?.repeticiones.length ?? 0;
  bool get hayRepeticiones => repeticiones > 0;

  /// Avance del movimiento actual (0 = reposo, 1 = rango mínimo alcanzado).
  double get progresoMovimiento => _analizador?.detector.progreso(estado?.valorSenal) ?? 0;

  String get textoFase => switch (estado?.fase) {
    Fase.ida => ejercicio.faseIda,
    Fase.vuelta => ejercicio.faseVuelta,
    _ => 'Listo',
  };

  /// Zonas del cuerpo con error en la última repetición (se pintan en el esqueleto).
  Set<String> get zonasConAlerta {
    final rep = ultimaRep;
    if (rep == null || DateTime.now().difference(_horaUltimaRep) > const Duration(milliseconds: 2500)) return const {};
    return {
      for (final codigo in rep.fallos)
        if (_analizador?.verificacion(codigo) case final v?) v.zona,
    };
  }

  // ------------------------------------------------------------------ cámara
  Future<void> iniciar() async {
    etapa = EtapaSesion.iniciando;
    mensajeError = null;
    notifyListeners();
    try {
      _camaras = await availableCameras();
    } on CameraException catch (e) {
      _fallar(e);
      return;
    }
    if (_camaras.isEmpty) {
      etapa = EtapaSesion.sinCamara;
      notifyListeners();
      return;
    }
    final preferida = preferirFrontal ? CameraLensDirection.front : CameraLensDirection.back;
    await _abrir(_camaras.firstWhere((c) => c.lensDirection == preferida, orElse: () => _camaras.first));
  }

  Future<void> _abrir(CameraDescription descripcion) async {
    final anterior = camara;
    camara = null;
    notifyListeners();
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
      if (etapa == EtapaSesion.iniciando) etapa = EtapaSesion.encuadre;
    } on CameraException catch (e) {
      await c.dispose();
      _fallar(e);
      return;
    }
    notifyListeners();
  }

  void _fallar(CameraException e) {
    const sinPermiso = {'CameraAccessDenied', 'CameraAccessDeniedWithoutPrompt', 'CameraAccessRestricted'};
    etapa = sinPermiso.contains(e.code) ? EtapaSesion.sinPermiso : EtapaSesion.error;
    mensajeError = e.description ?? e.code;
    notifyListeners();
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

  /// La app pasó a segundo plano: se libera la cámara.
  Future<void> pausar() async {
    final c = camara;
    camara = null;
    reloj.stop();
    notifyListeners();
    await _cerrarCamara(c);
  }

  Future<void> reanudar() async {
    final d = _descripcion;
    if (_cerrado || d == null || camara != null) return;
    await _abrir(d);
    if (etapa == EtapaSesion.activa) reloj.start();
  }

  // ------------------------------------------------------------- detección
  InputImage? _aInputImage(CameraImage imagen) {
    final c = camara;
    final d = _descripcion;
    if (c == null || d == null) return null;
    final orientaciones = {
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
      _alFotograma(fotograma);
      notifyListeners();
    } catch (e) {
      debugPrint('Error de detección: $e');
    } finally {
      _procesando = false;
    }
  }

  // ------------------------------------------------------- lógica de sesión
  void _alFotograma(Fotograma f) {
    final vmin = spec.globales.visibilidadMinima;
    switch (etapa) {
      case EtapaSesion.encuadre:
        faltantes = gruposFaltantes(f, vmin, ejercicio.puntosRequeridos);
        if (faltantes.isEmpty) {
          _cuadrosEncuadrados++;
          if (_cuadrosEncuadrados >= 8) _iniciarCuentaRegresiva();
        } else {
          _cuadrosEncuadrados = 0;
        }
      case EtapaSesion.cuentaRegresiva:
        faltantes = gruposFaltantes(f, vmin, ejercicio.puntosRequeridos);
      case EtapaSesion.activa:
        final e = _analizador!.procesar(f);
        estado = e;
        faltantes = e.faltantes;
        final rep = e.nuevaRepeticion;
        if (rep != null) _alRepeticion(rep);
        if (e.repeticionIncompleta) {
          _avisar(
            AvisoEnVivo(
              'Repetición incompleta',
              detalle: 'Completa todo el rango de movimiento.',
              severidad: Severidad.leve,
            ),
          );
          _hablar('Completa el movimiento');
        }
        if (!e.valido && faltantes.isNotEmpty) _avisarFaltantes();
      default:
        break;
    }
  }

  void _iniciarCuentaRegresiva() {
    etapa = EtapaSesion.cuentaRegresiva;
    cuenta = AppConfig.cuentaRegresiva;
    _hablar('Prepárate', prioritario: true);
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      cuenta--;
      if (cuenta <= 0) {
        t.cancel();
        _comenzar();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Omite la espera de encuadre y empieza de inmediato.
  void comenzarAhora() {
    _temporizador?.cancel();
    _comenzar();
  }

  void _comenzar() {
    _analizador = Analizador(spec, ejercicio.id);
    etapa = EtapaSesion.activa;
    reloj
      ..reset()
      ..start();
    _avisar(AvisoEnVivo('¡Comienza!', detalle: '${ejercicio.objetivoRepeticiones} repeticiones como objetivo'));
    _hablar('Comienza', prioritario: true);
    notifyListeners();
  }

  void _alRepeticion(RepeticionEvaluada rep) {
    ultimaRep = rep;
    _horaUltimaRep = DateTime.now();
    HapticFeedback.mediumImpact();
    if (rep.fallos.isEmpty) {
      _avisar(AvisoEnVivo('Repetición ${rep.numero} correcta'));
      _hablar('${rep.numero}', prioritario: true);
      return;
    }
    const orden = {'alta': 0, 'moderada': 1, 'leve': 2, 'info': 3};
    final fallos = [for (final c in rep.fallos) ?_analizador!.verificacion(c)]
      ..sort((a, b) => (orden[a.severidad] ?? 9).compareTo(orden[b.severidad] ?? 9));
    final principal = fallos.first;
    _avisar(AvisoEnVivo(principal.titulo, detalle: principal.mensaje, severidad: Severidad.desde(principal.severidad)));
    _hablar('${rep.numero}. ${fraseCorta(principal.mensaje)}', prioritario: true);
  }

  void _avisarFaltantes() {
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoAvisoFaltantes) < const Duration(seconds: 6)) return;
    _ultimoAvisoFaltantes = ahora;
    _hablar('Aléjate un poco de la cámara');
  }

  void _avisar(AvisoEnVivo a) => aviso = a;

  void _hablar(String texto, {bool prioritario = false}) {
    if (vozActiva) voz.decir(texto, prioritario: prioritario);
  }

  void alternarVoz() {
    vozActiva = !vozActiva;
    if (!vozActiva) voz.detener();
    notifyListeners();
  }

  /// Detiene la cámara y devuelve el resultado (null si no hubo sesión activa).
  Future<ResultadoAnalisis?> finalizar() async {
    etapa = EtapaSesion.finalizando;
    reloj.stop();
    notifyListeners();
    _temporizador?.cancel();
    final c = camara;
    camara = null;
    await _cerrarCamara(c);
    final a = _analizador;
    if (a == null) return null;
    return ResultadoAnalisis.fromJson(a.resultado());
  }

  @override
  void dispose() {
    _cerrado = true;
    _temporizador?.cancel();
    final c = camara;
    camara = null;
    _cerrarCamara(c);
    _detector.close();
    voz.detener();
    super.dispose();
  }
}

/// Primera frase de un mensaje, para indicaciones por voz breves.
String fraseCorta(String mensaje) {
  final corte = mensaje.indexOf(RegExp(r'[:;.]'));
  return corte > 0 ? mensaje.substring(0, corte) : mensaje;
}
