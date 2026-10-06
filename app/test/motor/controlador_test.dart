import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/motor/puntos.dart';
import 'package:medicina_app/pantallas/tiempo_real/camara_pose.dart';
import 'package:medicina_app/pantallas/tiempo_real/controlador_tiempo_real.dart';
import 'package:medicina_app/servicios/voz_servicio.dart';

import '../ayudantes.dart';

/// Fotogramas de un fixture compartido, como si llegaran de la cámara.
List<Fotograma> fotogramasDe(String nombre) {
  final fx = jsonDecode(File('../compartido/fixtures/$nombre.json').readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final f in fx['fotogramas'] as List)
      Fotograma.desdeListas((f as Map<String, dynamic>)['t_ms'] as int, f['puntos'] as List?, f['mundo'] as List?),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // Sin plugins nativos en las pruebas: el detector y la voz no hacen nada.
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final canal in ['google_mlkit_pose_detector', 'flutter_tts']) {
      mensajero.setMockMethodCallHandler(MethodChannel(canal), (_) async => null);
    }
  });

  ControladorTiempoReal crear(CamaraPose camara, {int objetivo = 2, bool autoFinalizar = true}) {
    final spec = cargarEspecificacion();
    return ControladorTiempoReal(
      camara: camara,
      spec: spec,
      ejercicio: spec.buscar('sentarse_pararse')!,
      voz: VozServicio(),
      vozActiva: false,
      vibracion: false,
      objetivo: objetivo,
      autoFinalizar: autoFinalizar,
    );
  }

  test('encuadre → cuenta regresiva → serie que termina sola al llegar al objetivo', () {
    final camara = CamaraPose(preferirFrontal: true);
    final ctrl = crear(camara);
    final fotogramas = fotogramasDe('sentarse_pararse_correcto');

    expect(ctrl.etapa, EtapaSesion.encuadre);
    for (final f in fotogramas.take(8)) {
      camara.alFotograma!(f);
    }
    expect(ctrl.etapa, EtapaSesion.cuentaRegresiva, reason: '8 cuadros con el cuerpo completo');

    ctrl.comenzarAhora();
    expect(ctrl.etapa, EtapaSesion.activa);
    for (final f in fotogramas) {
      if (ctrl.etapa != EtapaSesion.activa) break;
      camara.alFotograma!(f);
    }
    expect(ctrl.etapa, EtapaSesion.serieCompleta);
    expect(ctrl.repeticiones, 2);

    final r = ctrl.tomarResultado()!;
    expect(r.resultado.numeroRepeticiones, 2);
    expect(r.conteoFinal, greaterThanOrEqualTo(2));

    // La misma cámara sirve para la serie siguiente.
    ctrl.prepararSerie(objetivo: 3);
    expect(ctrl.etapa, EtapaSesion.encuadre);
    expect(ctrl.repeticiones, 0);
    expect(ctrl.objetivo, 3);
    expect(identical(camara.alFotograma, null), isFalse);

    ctrl.dispose();
    expect(camara.alFotograma, isNull, reason: 'el controlador suelta la cámara al cerrarse');
    camara.dispose();
  });

  test('sin autoFinalizar cuenta todas las repeticiones del video', () {
    final camara = CamaraPose(preferirFrontal: true);
    final ctrl = crear(camara, objetivo: 1, autoFinalizar: false)..comenzarAhora();
    for (final f in fotogramasDe('sentarse_pararse_correcto')) {
      camara.alFotograma!(f);
    }
    expect(ctrl.etapa, EtapaSesion.activa);
    expect(ctrl.repeticiones, 3);
    ctrl.terminarSerie();
    expect(ctrl.etapa, EtapaSesion.serieCompleta);
    expect(ctrl.tomarResultado()!.conteoFinal, 3);
    ctrl.dispose();
    camara.dispose();
  });

  test('sin persona en cuadro se informa qué falta', () {
    final camara = CamaraPose(preferirFrontal: true);
    final ctrl = crear(camara);
    for (final f in fotogramasDe('sin_persona').take(5)) {
      camara.alFotograma!(f);
    }
    expect(ctrl.etapa, EtapaSesion.encuadre);
    expect(ctrl.faltantes, isNotEmpty);
    ctrl.dispose();
    camara.dispose();
  });
}
