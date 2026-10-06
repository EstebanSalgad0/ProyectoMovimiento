import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/rutina.dart';
import 'package:medicina_app/modelos/usuario.dart';

import '../ayudantes.dart';

void main() {
  const rutina = Rutina(
    id: 'r1',
    nombre: 'Prueba',
    items: [
      ItemRutina(ejercicioId: 'sentadilla', series: 2, repeticiones: 10, descansoS: 60),
      ItemRutina(ejercicioId: 'curl_biceps_sentado', series: 1, repeticiones: 12, descansoS: 30),
    ],
  );

  test('totales y duración estimada', () {
    expect(rutina.totalSeries, 3);
    expect(rutina.totalRepeticiones, 32);
    // 32 reps × 3,5 s + 1 descanso de 60 s + 2 × 20 s para acomodarse ≈ 3,5 min
    expect(rutina.minutosEstimados, 4);
  });

  test('ida y vuelta JSON', () {
    final vuelta = Rutina.fromJson(rutina.toJson());
    expect(vuelta.nombre, 'Prueba');
    expect(vuelta.items.map((i) => i.ejercicioId), ['sentadilla', 'curl_biceps_sentado']);
    expect(vuelta.items.first.descansoS, 60);
  });

  test('las rutinas predefinidas usan ejercicios que existen', () {
    final spec = cargarEspecificacion();
    for (final r in rutinasPredefinidas) {
      expect(r.predefinida, isTrue);
      for (final i in r.items) {
        expect(spec.buscar(i.ejercicioId), isNotNull, reason: '${r.id}: ${i.ejercicioId}');
      }
    }
  });

  test('rutina sugerida según objetivo y edad', () {
    expect(idRutinaSugerida(Objetivo.fuerza, 30), 'fuerza_piernas');
    expect(idRutinaSugerida(Objetivo.prevencionCaidas, 70), 'movilidad_autonomia');
    expect(idRutinaSugerida(null, 72), 'movilidad_autonomia');
    expect(idRutinaSugerida(Objetivo.bienestar, 35), 'activacion_diaria');
    final ids = rutinasPredefinidas.map((r) => r.id).toSet();
    for (final o in [null, ...Objetivo.values]) {
      expect(ids, contains(idRutinaSugerida(o, 40)));
    }
  });

  test('la sesión guiada recorre series y descansos hasta terminar', () {
    final plan = PlanSesionGuiada(rutina, ejecucionId: 'e1');
    expect(plan.pasos, hasLength(3));
    expect(plan.estado, EstadoGuiado.preparando);
    expect(plan.actual.item.ejercicioId, 'sentadilla');
    expect(plan.siguienteCambiaEjercicio, isFalse);

    plan.comenzarSerie();
    expect(plan.estado, EstadoGuiado.serie);
    plan.completarSerie(sesionId: 's1');
    expect(plan.estado, EstadoGuiado.descanso);
    plan.avanzar();
    expect(plan.actual.serie, 2);
    expect(plan.actual.esUltimaSerie, isTrue);
    expect(plan.siguienteCambiaEjercicio, isTrue);

    plan
      ..comenzarSerie()
      ..completarSerie(sesionId: 's2')
      ..avanzar()
      ..comenzarSerie();
    expect(plan.actual.item.ejercicioId, 'curl_biceps_sentado');
    expect(plan.siguiente, isNull);
    plan.completarSerie(); // sin repeticiones: no se guarda sesión
    expect(plan.estado, EstadoGuiado.terminado);
    expect(plan.avance, 1);
    expect(plan.sesionesCompletadas, ['s1', 's2']);

    // Una vez terminada no cambia.
    plan.avanzar();
    expect(plan.estado, EstadoGuiado.terminado);
  });
}
