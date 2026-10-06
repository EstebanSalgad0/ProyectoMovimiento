import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/motor/especificacion.dart';

import '../ayudantes.dart';

void main() {
  final spec = cargarEspecificacion();

  test('los ajustes cambian umbrales y desactivan verificaciones (igual que el servidor)', () {
    final propia = spec.conAjustes({
      'sentadilla': {
        'SQ_PROFUNDIDAD': const AjusteVerificacion(umbral: 120),
        'SQ_TRONCO': const AjusteVerificacion(activa: false),
      },
      'inexistente': {'X': const AjusteVerificacion(umbral: 1)},
    });
    final r = resultadoDeFixture(propia, 'sentadilla_lateral_poco_profunda');
    expect(r.hallazgos.map((h) => h.codigo), isEmpty);
    expect(r.puntaje, 100);
    // La especificación original no cambia.
    expect(resultadoDeFixture(spec, 'sentadilla_lateral_poco_profunda').puntaje, 70);
    expect(propia.buscar('sentadilla')!.verificaciones.any((v) => v.codigo == 'SQ_TRONCO'), isFalse);
  });

  test('sin ajustes se devuelve la misma especificación', () {
    expect(identical(spec.conAjustes(const {}), spec), isTrue);
  });

  test('los ajustes van y vuelven en JSON con el formato del servidor', () {
    final ajustes = {
      'sentadilla': {
        'SQ_PROFUNDIDAD': const AjusteVerificacion(umbral: 110),
        'SQ_TRONCO': const AjusteVerificacion(activa: false),
      },
    };
    final json = ajustesAJson(ajustes);
    expect(json, {
      'sentadilla': {
        'SQ_PROFUNDIDAD': {'umbral': 110.0, 'activa': true},
        'SQ_TRONCO': {'activa': false},
      },
    });
    final vuelta = ajustesDesdeJson(json);
    expect(vuelta['sentadilla']!['SQ_PROFUNDIDAD']!.umbral, 110);
    expect(vuelta['sentadilla']!['SQ_TRONCO']!.activa, isFalse);
  });

  test('cada verificación tiene un rango de ajuste que contiene su valor recomendado', () {
    for (final e in spec.ejercicios) {
      for (final v in e.verificaciones) {
        final r = v.rangoAjuste;
        expect(r.min, lessThanOrEqualTo(v.umbral), reason: '${e.id}/${v.codigo}');
        expect(r.max, greaterThanOrEqualTo(v.umbral), reason: '${e.id}/${v.codigo}');
        expect(r.paso, greaterThan(0));
      }
    }
  });
}
