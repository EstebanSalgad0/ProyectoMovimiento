import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/app.dart';
import 'package:medicina_app/estado/proveedores.dart';
import 'package:medicina_app/modelos/resultado_analisis.dart';
import 'package:medicina_app/pantallas/analizando/analizando_pantalla.dart';
import 'package:medicina_app/rutas.dart';
import 'package:medicina_app/servicios/historial_servicio.dart';
import 'package:medicina_app/servicios/servicio_ia.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ayudantes.dart';

const _sesionIniciada = {'ajustes.bienvenida_vista': true, 'auth.sesion': 'usuario.prueba'};

/// Servidor simulado: devuelve un resultado fijo o falla.
class _ServidorFalso extends ServicioIA {
  final ResultadoAnalisis? resultado;
  final ErrorAnalisis? error;
  _ServidorFalso({this.resultado, this.error}) : super('http://falso');

  @override
  Future<ResultadoAnalisis> analizarVideo({
    required File video,
    required String ejercicio,
    CancelToken? cancelar,
    void Function(double progreso)? onProgreso,
  }) async {
    onProgreso?.call(0.5);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    onProgreso?.call(1);
    // Simula el tiempo de procesamiento en el servidor.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (error != null) throw error!;
    return resultado!;
  }
}

Future<ProviderContainer> _montarConServidor(WidgetTester tester, ServicioIA servidor) async {
  SharedPreferences.setMockInitialValues(_sesionIniciada);
  final prefs = await SharedPreferences.getInstance();
  final contenedor = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      especificacionProvider.overrideWithValue(cargarEspecificacion()),
      historialServicioProvider.overrideWithValue(HistorialMemoria()),
      servicioIAProvider.overrideWithValue(servidor),
    ],
  );
  addTearDown(contenedor.dispose);
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(UncontrolledProviderScope(container: contenedor, child: const MiApp()));
  await avanzar(tester);
  return contenedor;
}

void main() {
  testWidgets('bienvenida completa con "Siguiente"', (tester) async {
    await montarApp(tester);
    await tester.tap(find.text('Siguiente'));
    await avanzar(tester, 4);
    expect(find.textContaining('Correcciones'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await avanzar(tester, 4);
    expect(find.textContaining('Sigue tu progreso'), findsOneWidget);
    await tester.tap(find.text('Comenzar'));
    await avanzar(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('progreso con datos: gráfico, correcciones frecuentes e historial', (tester) async {
    final spec = cargarEspecificacion();
    final ahora = DateTime.now();
    final sesiones = [
      sesionDePrueba(resultadoDeFixture(spec, 'sentadilla_lateral_correcta'), fecha: ahora, id: 'a'),
      sesionDePrueba(
        resultadoDeFixture(spec, 'sentadilla_lateral_poco_profunda'),
        fecha: ahora.subtract(const Duration(days: 1)),
        id: 'b',
      ),
      sesionDePrueba(
        resultadoDeFixture(spec, 'press_extension_incompleta'),
        fecha: ahora.subtract(const Duration(days: 3)),
        id: 'c',
      ),
    ];
    await montarApp(tester, preferencias: _sesionIniciada, sesiones: sesiones);
    await tester.tap(find.text('Progreso').last);
    await avanzar(tester);

    expect(find.text('Evolución del puntaje'), findsOneWidget);
    expect(find.text('Sesiones'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sentadilla'));
    await avanzar(tester, 3);
    await tester.scrollUntilVisible(
      find.text('Correcciones más frecuentes'),
      300,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
    );
    expect(find.text('Profundidad insuficiente'), findsOneWidget);
  });

  testWidgets('preparación de video muestra opciones y consejos', (tester) async {
    final c = await montarApp(tester, preferencias: _sesionIniciada);
    c.read(routerProvider).push(Rutas.preparacionDe('zancada'));
    await avanzar(tester);
    expect(find.text('Zancada'), findsOneWidget);
    expect(find.text('Grabar'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.text('Elige un video para continuar'), findsOneWidget);
  });

  testWidgets('análisis de video sin servidor muestra el error y la ayuda', (tester) async {
    final c = await _montarConServidor(
      tester,
      _ServidorFalso(error: const ErrorAnalisis(TipoErrorAnalisis.sinConexion, 'No se pudo conectar')),
    );
    c
        .read(routerProvider)
        .push(
          Rutas.analizando,
          extra: SolicitudAnalisis(video: File('video.mp4'), ejercicio: 'sentadilla'),
        );
    await avanzar(tester, 12);
    expect(find.text('Sin conexión con el servidor'), findsOneWidget);
    expect(find.text('Configurar servidor'), findsOneWidget);
  });

  testWidgets('análisis de video exitoso guarda la sesión y abre el resultado', (tester) async {
    final r = resultadoDeFixture(cargarEspecificacion(), 'press_extension_incompleta');
    final c = await _montarConServidor(tester, _ServidorFalso(resultado: r));
    c
        .read(routerProvider)
        .push(
          Rutas.analizando,
          extra: SolicitudAnalisis(video: File('video.mp4'), ejercicio: 'press_hombros_sentado'),
        );
    await avanzar(tester, 3);
    expect(find.text('Analizando tu técnica'), findsOneWidget);
    await avanzar(tester, 12);
    expect(find.text('Tu resultado'), findsOneWidget);
    expect(c.read(historialProvider).value?.length, 1);
  });
}
