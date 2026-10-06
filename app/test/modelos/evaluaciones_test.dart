import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/usuario.dart';

void main() {
  group('referencias CDC STEADI (30 s)', () {
    test('umbrales por edad y sexo', () {
      expect(ReferenciaSts30.umbral(60, Sexo.masculino), 14);
      expect(ReferenciaSts30.umbral(64, Sexo.femenino), 12);
      expect(ReferenciaSts30.umbral(65, Sexo.masculino), 12);
      expect(ReferenciaSts30.umbral(72, Sexo.femenino), 10);
      expect(ReferenciaSts30.umbral(79, Sexo.masculino), 11);
      expect(ReferenciaSts30.umbral(82, Sexo.femenino), 9);
      expect(ReferenciaSts30.umbral(87, Sexo.masculino), 8);
      expect(ReferenciaSts30.umbral(94, Sexo.femenino), 4);
    });

    test('sin referencia fuera de 60–94 años o sin sexo', () {
      expect(ReferenciaSts30.umbral(59, Sexo.femenino), isNull);
      expect(ReferenciaSts30.umbral(95, Sexo.masculino), isNull);
      expect(ReferenciaSts30.umbral(70, Sexo.otro), isNull);
      expect(ReferenciaSts30.umbral(null, Sexo.femenino), isNull);
      expect(ReferenciaSts30.clasificar(10, 40, Sexo.femenino), ClasificacionSts30.sinReferencia);
    });

    test('bajo el promedio si no se alcanza el umbral', () {
      expect(ReferenciaSts30.clasificar(11, 66, Sexo.masculino), ClasificacionSts30.bajoPromedio);
      expect(ReferenciaSts30.clasificar(12, 66, Sexo.masculino), ClasificacionSts30.enRango);
    });
  });

  test('evaluación de la prueba de 30 s y JSON', () {
    final e = EvaluacionFuncional.sts30(usuario: 'ana', repeticiones: 9, edad: 75, sexo: Sexo.femenino, sesionId: 's1');
    expect(e.umbralReferencia, 10);
    expect(e.clasificacion, ClasificacionSts30.bajoPromedio);
    final vuelta = EvaluacionFuncional.fromJson(e.toJson());
    expect(vuelta.tipo, TipoEvaluacion.sentarsePararse30s);
    expect(vuelta.repeticiones, 9);
    expect(vuelta.sexo, Sexo.femenino);
    expect(vuelta.clasificacion, ClasificacionSts30.bajoPromedio);
    expect(vuelta.sesionId, 's1');
  });

  test('rango articular respecto de la referencia', () {
    final e = EvaluacionFuncional.rango(
      usuario: 'ana',
      articulacion: Articulacion.rodilla,
      lado: Lado.derecho,
      maximo: 108,
    );
    expect(e.fraccionReferencia, closeTo(0.8, 1e-9));
    final vuelta = EvaluacionFuncional.fromJson(e.toJson());
    expect(vuelta.articulacion, Articulacion.rodilla);
    expect(vuelta.lado, Lado.derecho);
    expect(vuelta.maximo, 108);
  });
}
