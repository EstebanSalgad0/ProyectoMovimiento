import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/logros.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';

import '../ayudantes.dart';

void main() {
  // Miércoles 8 de octubre de 2025, 18:00
  final hoy = DateTime(2025, 10, 8, 18);

  test('rachas y días activos de la semana', () {
    final fechas = [
      DateTime(2025, 10, 8, 9),
      DateTime(2025, 10, 7, 20),
      DateTime(2025, 10, 7, 8), // mismo día: cuenta una vez
      DateTime(2025, 10, 6, 10),
      DateTime(2025, 10, 3, 10), // viernes anterior
      DateTime(2025, 10, 2, 10),
    ];
    expect(rachaDias(fechas, hoy: hoy), 3);
    expect(rachaDias(fechas, hoy: DateTime(2025, 10, 9, 8)), 3, reason: 'si hoy aún no entrena, cuenta desde ayer');
    expect(rachaDias(fechas, hoy: DateTime(2025, 10, 10)), 0);
    expect(mejorRacha(fechas), 3);
    expect(diasActivosSemana(fechas, hoy: hoy), 3, reason: 'lunes 6 a miércoles 8');
  });

  test('mapa de actividad de 12 semanas que empieza en lunes', () {
    final mapa = mapaActividad([DateTime(2025, 10, 7, 9), DateTime(2025, 10, 7, 19)], hoy: hoy);
    expect(mapa, hasLength(84));
    final dias = mapa.keys.toList()..sort();
    expect(dias.first.weekday, DateTime.monday);
    expect(dias.last, DateTime(2025, 10, 12));
    expect(mapa[DateTime(2025, 10, 7)], 2);
  });

  test('logros se desbloquean con el historial', () {
    final spec = cargarEspecificacion();
    final r = resultadoDeFixture(spec, 'sentadilla_lateral_correcta');
    Sesion s(DateTime f, String id, {ContextoRutina? rutina, Sensaciones? sensaciones}) => Sesion(
      id: id,
      usuario: 'u',
      fecha: f,
      origen: OrigenSesion.tiempoReal,
      resultado: r,
      rutina: rutina,
      sensaciones: sensaciones,
    );
    final sesiones = [
      s(DateTime(2025, 10, 8, 9), 'a', sensaciones: const Sensaciones(esfuerzo: 5, dolor: 0)),
      s(
        DateTime(2025, 10, 7, 9),
        'b',
        rutina: const ContextoRutina(rutinaId: 'x', rutinaNombre: 'X', ejecucionId: 'e', serie: 1, totalSeries: 2),
      ),
      s(DateTime(2025, 10, 6, 9), 'c'),
    ];
    final evals = [
      EvaluacionFuncional.rango(usuario: 'u', articulacion: Articulacion.codo, lado: Lado.izquierdo, maximo: 140),
    ];
    final logros = {
      for (final l in calcularLogros(sesiones: sesiones, evaluaciones: evals, metaSemanal: 3, hoy: hoy)) l.id: l,
    };
    expect(logros, hasLength(11));
    for (final id in ['primera_sesion', 'meta_semanal', 'racha_3', 'primera_rutina', 'evaluacion']) {
      expect(logros[id]!.desbloqueado, isTrue, reason: id);
    }
    expect(logros['racha_7']!.desbloqueado, isFalse);
    expect(logros['racha_7']!.avance, greaterThan(0));
    expect(logros['reps_500']!.desbloqueado, isFalse);
    expect(logros['sensaciones']!.avance, closeTo(0.2, 1e-9), reason: '1 de 5 sesiones con sensaciones');
  });

  test('sin historial no hay logros', () {
    final logros = calcularLogros(sesiones: const [], evaluaciones: const [], metaSemanal: 3, hoy: hoy);
    expect(logros.where((l) => l.desbloqueado), isEmpty);
  });
}
