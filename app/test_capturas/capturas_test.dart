// Genera capturas de las pantallas principales (con la fuente e íconos reales)
// en docs/capturas/. No forma parte de la suite normal porque el renderizado
// varía entre sistemas operativos.
//
//   flutter test test_capturas --update-goldens

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/pantallas/analizando/analizando_pantalla.dart';
import 'package:medicina_app/rutas.dart';

import '../test/ayudantes.dart';

const _destino = '../../docs/capturas';
const _sesionIniciada = {'ajustes.bienvenida_vista': true, 'auth.sesion': 'usuario.prueba'};

Future<void> _cargarFuentes() async {
  ByteData leer(String ruta) => ByteData.view(File(ruta).readAsBytesSync().buffer);
  final jakarta = FontLoader('PlusJakartaSans');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(Future.value(leer('assets/fuentes/PlusJakartaSans-$peso.ttf')));
  }
  await jakarta.load();
  final raiz = Platform.environment['FLUTTER_ROOT']!;
  final iconos = FontLoader('MaterialIcons')
    ..addFont(Future.value(leer('$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')));
  await iconos.load();
}

List<Sesion> _sesionesDemo() {
  final spec = cargarEspecificacion();
  final ahora = DateTime.now();
  Sesion s(String fixture, int horas, String id, OrigenSesion origen) => Sesion(
    id: id,
    usuario: 'usuario.prueba',
    fecha: ahora.subtract(Duration(hours: horas)),
    origen: origen,
    resultado: resultadoDeFixture(spec, fixture),
  );
  return [
    s('sentadilla_frontal_valgo', 1, 'a', OrigenSesion.tiempoReal),
    s('curl_frontal_correcto', 20, 'b', OrigenSesion.tiempoReal),
    s('sentadilla_lateral_poco_profunda', 28, 'c', OrigenSesion.video),
    s('press_extension_incompleta', 50, 'd', OrigenSesion.tiempoReal),
    s('sentadilla_rep_incompleta', 74, 'e', OrigenSesion.video),
    s('elevacion_lateral_baja', 98, 'f', OrigenSesion.tiempoReal),
    s('sentadilla_lateral_correcta', 122, 'g', OrigenSesion.tiempoReal),
  ];
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  await avanzar(tester, 10);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_destino/$nombre.png'));
}

void main() {
  setUpAll(_cargarFuentes);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2;
  });

  Future<void> montar(WidgetTester tester, {Map<String, Object> prefs = _sesionIniciada, bool sesiones = true}) async {
    await montarApp(tester, preferencias: prefs, sesiones: sesiones ? _sesionesDemo() : const []);
    // montarApp fija 430x932; para capturas se usa el tamaño de un iPhone 14 (390x844).
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await avanzar(tester, 2);
  }

  testWidgets('01 bienvenida', (t) async {
    await montar(t, prefs: const {}, sesiones: false);
    await _capturar(t, '01_bienvenida');
  });

  testWidgets('02 login', (t) async {
    await montar(t, prefs: const {'ajustes.bienvenida_vista': true}, sesiones: false);
    await _capturar(t, '02_login');
  });

  testWidgets('03 inicio', (t) async {
    await montar(t);
    await _capturar(t, '03_inicio');
  });

  testWidgets('04 inicio (desplazado)', (t) async {
    await montar(t);
    await t.drag(find.byType(ListView).first, const Offset(0, -560));
    await _capturar(t, '04_inicio_actividad');
  });

  testWidgets('05 catálogo', (t) async {
    await montar(t);
    await t.tap(find.text('Ejercicios').last);
    await _capturar(t, '05_catalogo');
  });

  testWidgets('06 detalle', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    await t.binding.setSurfaceSize(const Size(390, 844));
    c.read(routerProvider).push(Rutas.ejercicio('sentadilla'));
    await _capturar(t, '06_detalle_ejercicio');
  });

  testWidgets('07 preparación', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    await t.binding.setSurfaceSize(const Size(390, 844));
    c.read(routerProvider).push(Rutas.preparacionDe('sentadilla'));
    await _capturar(t, '07_preparacion_video');
  });

  testWidgets('08 resultado', (t) async {
    final sesiones = _sesionesDemo();
    final c = await montarApp(t, preferencias: _sesionIniciada, sesiones: sesiones);
    await t.binding.setSurfaceSize(const Size(390, 844));
    c.read(routerProvider).push(Rutas.sesion('c', nueva: true), extra: sesiones[2]);
    await _capturar(t, '08_resultado');
    await t.drag(find.byType(ListView).first, const Offset(0, -640));
    await _capturar(t, '09_resultado_detalle');
  });

  testWidgets('10 progreso', (t) async {
    await montar(t);
    await t.tap(find.text('Progreso').last);
    await _capturar(t, '10_progreso');
  });

  testWidgets('11 cuenta', (t) async {
    await montar(t);
    await t.tap(find.text('Cuenta').last);
    await _capturar(t, '11_cuenta');
  });

  testWidgets('12 inicio oscuro', (t) async {
    await montar(t, prefs: {..._sesionIniciada, 'ajustes.tema': 'dark'});
    await _capturar(t, '12_inicio_oscuro');
  });

  testWidgets('13 resultado oscuro', (t) async {
    final sesiones = _sesionesDemo();
    final c = await montarApp(t, preferencias: {..._sesionIniciada, 'ajustes.tema': 'dark'}, sesiones: sesiones);
    await t.binding.setSurfaceSize(const Size(390, 844));
    c.read(routerProvider).push(Rutas.sesion('a', nueva: true), extra: sesiones[0]);
    await _capturar(t, '13_resultado_oscuro');
  });

  testWidgets('14 analizando', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    await t.binding.setSurfaceSize(const Size(390, 844));
    c
        .read(routerProvider)
        .push(
          Rutas.analizando,
          extra: SolicitudAnalisis(video: File('no_existe.mp4'), ejercicio: 'sentadilla'),
        );
    await _capturar(t, '14_analizando');
  });
}
