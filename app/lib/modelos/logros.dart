import 'package:flutter/material.dart';

import 'evaluacion.dart';
import 'sesion.dart';

DateTime soloDia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Lunes de la semana de [f].
DateTime inicioSemana(DateTime f) => soloDia(f).subtract(Duration(days: f.weekday - 1));

/// Días distintos con actividad en la semana actual (lunes a domingo).
int diasActivosSemana(Iterable<DateTime> fechas, {DateTime? hoy}) {
  final lunes = inicioSemana(hoy ?? DateTime.now());
  final fin = lunes.add(const Duration(days: 7));
  return {
    for (final f in fechas)
      if (!f.isBefore(lunes) && f.isBefore(fin)) soloDia(f),
  }.length;
}

/// Racha de días consecutivos con actividad que termina hoy o ayer.
int rachaDias(Iterable<DateTime> fechas, {DateTime? hoy}) {
  final dias = {for (final f in fechas) soloDia(f)};
  var dia = soloDia(hoy ?? DateTime.now());
  if (!dias.contains(dia)) dia = dia.subtract(const Duration(days: 1));
  var racha = 0;
  while (dias.contains(dia)) {
    racha++;
    dia = dia.subtract(const Duration(days: 1));
  }
  return racha;
}

/// Mejor racha histórica.
int mejorRacha(Iterable<DateTime> fechas) {
  final dias = {for (final f in fechas) soloDia(f)}.toList()..sort();
  var mejor = 0, actual = 0;
  DateTime? anterior;
  for (final d in dias) {
    actual = (anterior != null && d.difference(anterior).inDays == 1) ? actual + 1 : 1;
    if (actual > mejor) mejor = actual;
    anterior = d;
  }
  return mejor;
}

/// Actividad por día para el calendario (semanas completas, de lunes a domingo).
Map<DateTime, int> mapaActividad(Iterable<DateTime> fechas, {int semanas = 12, DateTime? hoy}) {
  final lunesActual = inicioSemana(hoy ?? DateTime.now());
  final desde = lunesActual.subtract(Duration(days: 7 * (semanas - 1)));
  final mapa = <DateTime, int>{};
  for (var i = 0; i < semanas * 7; i++) {
    final d = desde.add(Duration(days: i));
    mapa[DateTime(d.year, d.month, d.day)] = 0;
  }
  for (final f in fechas) {
    final d = soloDia(f);
    if (mapa.containsKey(d)) mapa[d] = mapa[d]! + 1;
  }
  return mapa;
}

class Logro {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;

  /// Avance entre 0 y 1 (1 = desbloqueado).
  final double avance;
  final String? detalleAvance;

  const Logro({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.avance,
    this.detalleAvance,
  });

  bool get desbloqueado => avance >= 1;
}

/// Calcula los logros a partir del historial (todo local, sin servidor).
List<Logro> calcularLogros({
  required List<Sesion> sesiones,
  required List<EvaluacionFuncional> evaluaciones,
  required int metaSemanal,
  DateTime? hoy,
}) {
  final fechas = [...sesiones.map((s) => s.fecha), ...evaluaciones.map((e) => e.fecha)];
  final totalReps = sesiones.fold<int>(0, (t, s) => t + s.resultado.numeroRepeticiones);
  final mejorPuntaje = sesiones.fold<int>(0, (m, s) => s.puntaje > m ? s.puntaje : m);
  final racha = mejorRacha(fechas);
  final ejercicios = {for (final s in sesiones) s.ejercicio}.length;
  final rutinas = {for (final s in sesiones) ?s.rutina?.ejecucionId}.length;
  final semana = diasActivosSemana(fechas, hoy: hoy);
  final conSensaciones = sesiones.where((s) => s.sensaciones != null).length;

  double fr(num v, num meta) => meta <= 0 ? 1 : (v / meta).clamp(0, 1).toDouble();
  String de(num v, num meta) => '${v > meta ? meta : v} de $meta';

  return [
    Logro(
      id: 'primera_sesion',
      titulo: 'Primer paso',
      descripcion: 'Completa tu primera sesión.',
      icono: Icons.flag_rounded,
      avance: fr(sesiones.length, 1),
    ),
    Logro(
      id: 'meta_semanal',
      titulo: 'Semana cumplida',
      descripcion: 'Cumple tu meta de $metaSemanal días de entrenamiento esta semana.',
      icono: Icons.event_available_rounded,
      avance: fr(semana, metaSemanal),
      detalleAvance: de(semana, metaSemanal),
    ),
    Logro(
      id: 'racha_3',
      titulo: 'Constancia',
      descripcion: 'Entrena 3 días seguidos.',
      icono: Icons.local_fire_department_rounded,
      avance: fr(racha, 3),
      detalleAvance: de(racha, 3),
    ),
    Logro(
      id: 'racha_7',
      titulo: 'Semana de fuego',
      descripcion: 'Entrena 7 días seguidos.',
      icono: Icons.whatshot_rounded,
      avance: fr(racha, 7),
      detalleAvance: de(racha, 7),
    ),
    Logro(
      id: 'tecnica_perfecta',
      titulo: 'Técnica perfecta',
      descripcion: 'Logra 100 puntos en una sesión.',
      icono: Icons.workspace_premium_rounded,
      avance: fr(mejorPuntaje, 100),
      detalleAvance: 'Mejor: $mejorPuntaje',
    ),
    Logro(
      id: 'reps_100',
      titulo: '100 repeticiones',
      descripcion: 'Acumula 100 repeticiones analizadas.',
      icono: Icons.repeat_rounded,
      avance: fr(totalReps, 100),
      detalleAvance: de(totalReps, 100),
    ),
    Logro(
      id: 'reps_500',
      titulo: '500 repeticiones',
      descripcion: 'Acumula 500 repeticiones analizadas.',
      icono: Icons.military_tech_rounded,
      avance: fr(totalReps, 500),
      detalleAvance: de(totalReps, 500),
    ),
    Logro(
      id: 'primera_rutina',
      titulo: 'En rutina',
      descripcion: 'Completa una rutina guiada.',
      icono: Icons.playlist_add_check_rounded,
      avance: fr(rutinas, 1),
    ),
    Logro(
      id: 'explorador',
      titulo: 'Explorador',
      descripcion: 'Prueba los 6 ejercicios.',
      icono: Icons.explore_rounded,
      avance: fr(ejercicios, 6),
      detalleAvance: de(ejercicios, 6),
    ),
    Logro(
      id: 'evaluacion',
      titulo: 'Me conozco',
      descripcion: 'Haz una prueba funcional o una medición de rango articular.',
      icono: Icons.straighten_rounded,
      avance: fr(evaluaciones.length, 1),
    ),
    Logro(
      id: 'sensaciones',
      titulo: 'Me escucho',
      descripcion: 'Registra cómo te sentiste en 5 sesiones.',
      icono: Icons.favorite_rounded,
      avance: fr(conSensaciones, 5),
      detalleAvance: de(conSensaciones, 5),
    ),
  ];
}
