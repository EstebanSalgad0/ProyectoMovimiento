// Genera capturas de las pantallas principales (con la fuente e íconos reales)
// en docs/capturas/. No forma parte de la suite normal porque el renderizado
// varía entre sistemas operativos.
//
//   flutter test test_capturas --update-goldens

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/esqueleto.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/rutina.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';
import 'package:medicina_app/motor/puntos.dart';
import 'package:medicina_app/pantallas/analizando/analizando_pantalla.dart';
import 'package:medicina_app/rutas.dart';
import 'package:medicina_app/servicios/adjuntos_servicio.dart';

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
  const rutina = ContextoRutina(
    rutinaId: 'activacion_diaria',
    rutinaNombre: 'Activación diaria',
    ejecucionId: 'ej1',
    serie: 1,
    totalSeries: 6,
  );
  Sesion s(
    String fixture,
    int horas,
    String id,
    OrigenSesion origen, {
    Sensaciones? sensaciones,
    ContextoRutina? rutina,
    bool esqueleto = false,
  }) => Sesion(
    id: id,
    usuario: 'usuario.prueba',
    fecha: ahora.subtract(Duration(hours: horas)),
    origen: origen,
    resultado: resultadoDeFixture(spec, fixture),
    sensaciones: sensaciones,
    rutina: rutina,
    tieneEsqueleto: esqueleto,
  );
  ContextoRutina serie(int n) => ContextoRutina(
    rutinaId: rutina.rutinaId,
    rutinaNombre: rutina.rutinaNombre,
    ejecucionId: rutina.ejecucionId,
    serie: n,
    totalSeries: rutina.totalSeries,
  );
  const leve = Sensaciones(esfuerzo: 5, dolor: 1, zonaDolor: 'rodillas');
  return [
    s('sentadilla_frontal_valgo', 1, 'a', OrigenSesion.tiempoReal, sensaciones: leve, esqueleto: true),
    s('curl_frontal_correcto', 20, 'b', OrigenSesion.tiempoReal, sensaciones: const Sensaciones(esfuerzo: 4, dolor: 0)),
    s(
      'sentadilla_lateral_poco_profunda',
      28,
      'c',
      OrigenSesion.video,
      sensaciones: const Sensaciones(esfuerzo: 7, dolor: 3),
    ),
    s(
      'press_extension_incompleta',
      50,
      'd',
      OrigenSesion.tiempoReal,
      sensaciones: const Sensaciones(esfuerzo: 6, dolor: 2),
    ),
    s('sentadilla_lateral_correcta', 74, 'r1', OrigenSesion.tiempoReal, rutina: serie(1), esqueleto: true),
    s('sentadilla_lateral_correcta', 74, 'r2', OrigenSesion.tiempoReal, rutina: serie(2)),
    s('elevacion_lateral_baja', 74, 'r3', OrigenSesion.tiempoReal, rutina: serie(3)),
    s('curl_frontal_correcto', 74, 'r4', OrigenSesion.tiempoReal, rutina: serie(4)),
    s('sentarse_pararse_correcto', 74, 'r5', OrigenSesion.tiempoReal, rutina: serie(5)),
    s('sentadilla_rep_incompleta', 98, 'e', OrigenSesion.video, sensaciones: const Sensaciones(esfuerzo: 6, dolor: 1)),
    s('elevacion_lateral_baja', 146, 'f', OrigenSesion.tiempoReal),
    s('sentadilla_lateral_correcta', 170, 'g', OrigenSesion.tiempoReal),
    s('curl_frontal_correcto', 360, 'h', OrigenSesion.tiempoReal),
    s('sentadilla_lateral_correcta', 600, 'i', OrigenSesion.tiempoReal),
  ];
}

List<EvaluacionFuncional> _evaluacionesDemo() {
  final ahora = DateTime.now();
  EvaluacionFuncional sts(int dias, int reps) => EvaluacionFuncional(
    id: 'sts$dias',
    usuario: 'usuario.prueba',
    fecha: ahora.subtract(Duration(days: dias)),
    tipo: TipoEvaluacion.sentarsePararse30s,
    repeticiones: reps,
    edad: 68,
    sexo: Sexo.femenino,
    umbralReferencia: ReferenciaSts30.umbral(68, Sexo.femenino),
    clasificacion: ReferenciaSts30.clasificar(reps, 68, Sexo.femenino),
  );
  EvaluacionFuncional rom(int dias, Articulacion a, Lado l, double max) => EvaluacionFuncional(
    id: 'rom$dias${a.name}',
    usuario: 'usuario.prueba',
    fecha: ahora.subtract(Duration(days: dias)),
    tipo: TipoEvaluacion.rangoArticular,
    articulacion: a,
    lado: l,
    maximo: max,
  );
  return [
    sts(2, 12),
    sts(30, 10),
    sts(60, 9),
    rom(3, Articulacion.hombro, Lado.derecho, 158),
    rom(3, Articulacion.rodilla, Lado.derecho, 118),
    rom(20, Articulacion.codo, Lado.izquierdo, 142),
  ];
}

/// Esqueleto grabado a partir de un fixture, para la pantalla de revisión.
EsqueletoGrabado _esqueletoDe(String fixture) {
  final fx = jsonDecode(File('../compartido/fixtures/$fixture.json').readAsStringSync()) as Map<String, dynamic>;
  final g = GrabadorEsqueleto()..aspecto = 9 / 16;
  for (final f in fx['fotogramas'] as List) {
    final m = f as Map<String, dynamic>;
    final fot = Fotograma.desdeListas(m['t_ms'] as int, m['puntos'] as List?, m['mundo'] as List?);
    final p = fot.imagen;
    // Los fixtures están en píxeles de un cuadro de 720 × 1280.
    g.agregar(
      fot.tMs,
      p == null ? null : {for (final i in indicesEsqueleto) i: (Offset(p[i].x / 720, p[i].y / 1280), p[i].v)},
    );
  }
  return g.resultado()!;
}

const _rutinaPropia = Rutina(
  id: 'rmia',
  nombre: 'Rodilla post operatoria',
  descripcion: 'Indicada por mi kinesióloga: 3 veces por semana.',
  items: [
    ItemRutina(ejercicioId: 'sentarse_pararse', series: 3, repeticiones: 8, descansoS: 90),
    ItemRutina(ejercicioId: 'sentadilla', series: 2, repeticiones: 6, descansoS: 60),
  ],
);

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

  Future<ProviderContainer> montar(
    WidgetTester tester, {
    Map<String, Object> prefs = _sesionIniciada,
    bool sesiones = true,
    AdjuntosMemoria? adjuntos,
  }) async {
    final c = await montarApp(
      tester,
      preferencias: {
        ...prefs,
        'rutinas.usuario.prueba': jsonEncode([_rutinaPropia.toJson()]),
      },
      sesiones: sesiones ? _sesionesDemo() : const [],
      evaluaciones: sesiones ? _evaluacionesDemo() : const [],
      adjuntos: adjuntos,
    );
    // montarApp fija 430x932; para capturas se usa el tamaño de un iPhone 14 (390x844).
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await avanzar(tester, 2);
    return c;
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
    await t.tap(find.text('Entrenar').last);
    await _capturar(t, '05_catalogo');
  });

  testWidgets('06 detalle', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.ejercicio('sentadilla'));
    await _capturar(t, '06_detalle_ejercicio');
  });

  testWidgets('07 preparación', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.preparacionDe('sentadilla'));
    await _capturar(t, '07_preparacion_video');
  });

  testWidgets('08 resultado', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.sesion('c', nueva: true));
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
    final c = await montar(t, prefs: {..._sesionIniciada, 'ajustes.tema': 'dark'});
    c.read(routerProvider).push(Rutas.sesion('a', nueva: true));
    await _capturar(t, '13_resultado_oscuro');
  });

  testWidgets('14 analizando', (t) async {
    final c = await montar(t);
    c
        .read(routerProvider)
        .push(
          Rutas.analizando,
          extra: SolicitudAnalisis(video: File('no_existe.mp4'), ejercicio: 'sentadilla'),
        );
    await _capturar(t, '14_analizando');
  });

  testWidgets('15 rutinas', (t) async {
    await montar(t);
    await t.tap(find.text('Entrenar').last);
    await avanzar(t, 2);
    await t.tap(find.text('Rutinas'));
    await _capturar(t, '15_rutinas');
  });

  testWidgets('16 detalle de rutina', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.rutina('movilidad_autonomia'));
    await _capturar(t, '16_detalle_rutina');
  });

  testWidgets('17 editor de rutina', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.editarRutina('rmia'));
    await _capturar(t, '17_editor_rutina');
  });

  testWidgets('18 resumen de rutina', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.ejecucion('ej1'));
    await _capturar(t, '18_resumen_rutina');
  });

  testWidgets('19 evaluaciones', (t) async {
    await montar(t);
    await t.tap(find.text('Entrenar').last);
    await avanzar(t, 2);
    await t.tap(find.text('Evaluaciones'));
    await _capturar(t, '19_evaluaciones');
  });

  testWidgets('20 prueba de 30 segundos', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.pruebaSts);
    await _capturar(t, '20_prueba_30s');
  });

  testWidgets('21 perfil', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.perfil);
    await _capturar(t, '21_perfil');
  });

  testWidgets('22 configuración inicial', (t) async {
    await montar(t, prefs: {..._sesionIniciada, 'perfil.pendiente.usuario.prueba': true}, sesiones: false);
    await _capturar(t, '22_configuracion_inicial');
  });

  testWidgets('23 logros', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.logros);
    await _capturar(t, '23_logros');
  });

  testWidgets('24 datos y privacidad', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.datos);
    await _capturar(t, '24_datos_privacidad');
  });

  testWidgets('25 revisión del movimiento', (t) async {
    final adjuntos = AdjuntosMemoria();
    await adjuntos.guardarEsqueleto('r1', _esqueletoDe('sentadilla_lateral_correcta'));
    final c = await montar(t, adjuntos: adjuntos);
    c.read(routerProvider).push(Rutas.revision('r1'));
    await avanzar(t, 4);
    await t.drag(find.byType(Slider), const Offset(60, 0));
    await _capturar(t, '25_revision');
  });

  testWidgets('26 progreso (calendario y tendencias)', (t) async {
    await montar(t);
    await t.tap(find.text('Progreso').last);
    await avanzar(t, 2);
    await t.drag(find.byType(ListView).first, const Offset(0, -520));
    await _capturar(t, '26_progreso_calendario');
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await _capturar(t, '27_progreso_tendencias');
  });

  testWidgets('28 sensaciones', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.sesion('f'));
    await avanzar(t, 10);
    await t.tap(find.text('¿Cómo te sentiste?'));
    await _capturar(t, '28_sensaciones');
  });

  testWidgets('29 objetivos personalizados', (t) async {
    final c = await montar(t);
    c.read(routerProvider).push(Rutas.ejercicio('sentadilla'));
    await avanzar(t, 6);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
    await avanzar(t, 2);
    await t.tap(find.text('Personalizar'));
    await _capturar(t, '29_objetivos');
  });

  testWidgets('30 cuenta (ajustes)', (t) async {
    await montar(t);
    await t.tap(find.text('Cuenta').last);
    await avanzar(t, 2);
    await t.drag(find.byType(ListView).first, const Offset(0, -560));
    await _capturar(t, '30_cuenta_ajustes');
  });
}
