import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/app.dart';
import 'package:medicina_app/estado/proveedores.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/resultado_analisis.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/motor/analizador.dart';
import 'package:medicina_app/motor/especificacion.dart';
import 'package:medicina_app/motor/puntos.dart';
import 'package:medicina_app/servicios/adjuntos_servicio.dart';
import 'package:medicina_app/servicios/evaluaciones_servicio.dart';
import 'package:medicina_app/servicios/historial_servicio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Especificacion cargarEspecificacion() => Especificacion.fromJson(
  jsonDecode(File('assets/especificacion/ejercicios.json').readAsStringSync()) as Map<String, dynamic>,
);

/// Ejecuta el motor local sobre un fixture compartido y devuelve el resultado.
ResultadoAnalisis resultadoDeFixture(Especificacion spec, String nombre) {
  final fx = jsonDecode(File('../compartido/fixtures/$nombre.json').readAsStringSync()) as Map<String, dynamic>;
  final a = Analizador(spec, fx['ejercicio'] as String);
  for (final f in fx['fotogramas'] as List) {
    final m = f as Map<String, dynamic>;
    a.procesar(Fotograma.desdeListas(m['t_ms'] as int, m['puntos'] as List?, m['mundo'] as List?));
  }
  return ResultadoAnalisis.fromJson(a.resultado());
}

Sesion sesionDePrueba(ResultadoAnalisis r, {required DateTime fecha, String id = 's1'}) =>
    Sesion(id: id, usuario: 'usuario.prueba', fecha: fecha, origen: OrigenSesion.tiempoReal, resultado: r);

/// Monta la app completa con preferencias simuladas e historial en memoria.
Future<ProviderContainer> montarApp(
  WidgetTester tester, {
  Map<String, Object> preferencias = const {},
  List<Sesion> sesiones = const [],
  List<EvaluacionFuncional> evaluaciones = const [],
}) async {
  SharedPreferences.setMockInitialValues(preferencias);
  final prefs = await SharedPreferences.getInstance();
  final spec = cargarEspecificacion();
  final contenedor = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      especificacionProvider.overrideWithValue(spec),
      historialServicioProvider.overrideWithValue(HistorialMemoria(sesiones)),
      evaluacionesServicioProvider.overrideWithValue(EvaluacionesMemoria(evaluaciones)),
      adjuntosServicioProvider.overrideWithValue(AdjuntosMemoria()),
    ],
  );
  addTearDown(contenedor.dispose);
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(UncontrolledProviderScope(container: contenedor, child: const MiApp()));
  await avanzar(tester);
  return contenedor;
}

/// Las ilustraciones se animan en bucle, así que no se usa pumpAndSettle.
Future<void> avanzar(WidgetTester tester, [int pasos = 8]) async {
  for (var i = 0; i < pasos; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
