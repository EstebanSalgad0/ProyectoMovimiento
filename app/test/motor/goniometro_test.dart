import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/usuario.dart';
import 'package:medicina_app/motor/puntos.dart';
import 'package:medicina_app/pantallas/evaluaciones/controlador_goniometro.dart';

/// Esqueleto de frente con brazos y piernas configurables (coordenadas de imagen).
List<Punto> cuerpo({Map<int, Punto> cambios = const {}}) {
  final p = List<Punto>.filled(numPuntos, Punto.ausente);
  void poner(int i, double x, double y) => p[i] = Punto(x, y, 0, 0.95);
  poner(hombro[0], 0.6, 0.3);
  poner(hombro[1], 0.4, 0.3);
  poner(cadera[0], 0.58, 0.6);
  poner(cadera[1], 0.4, 0.6);
  poner(codo[1], 0.4, 0.45); // brazo derecho colgando
  poner(muneca[1], 0.4, 0.6);
  poner(rodilla[1], 0.4, 0.75);
  poner(tobillo[1], 0.4, 0.9);
  for (final e in cambios.entries) {
    p[e.key] = e.value;
  }
  return p;
}

void main() {
  test('codo y rodilla extendidos miden 0°; doblados a 90° miden 90°', () {
    expect(anguloClinico(cuerpo(), Articulacion.codo, Lado.derecho), closeTo(0, 0.5));
    expect(anguloClinico(cuerpo(), Articulacion.rodilla, Lado.derecho), closeTo(0, 0.5));
    final codo90 = cuerpo(cambios: {muneca[1]: const Punto(0.55, 0.45, 0, 0.95)});
    expect(anguloClinico(codo90, Articulacion.codo, Lado.derecho), closeTo(90, 0.5));
  });

  test('hombro: brazo al costado ~0°, horizontal ~90°', () {
    expect(anguloClinico(cuerpo(), Articulacion.hombro, Lado.derecho), closeTo(0, 1));
    final horizontal = cuerpo(cambios: {codo[1]: const Punto(0.25, 0.3, 0, 0.95)});
    expect(anguloClinico(horizontal, Articulacion.hombro, Lado.derecho), closeTo(90, 1));
  });

  test('sin visibilidad no hay medición', () {
    final oculto = cuerpo(cambios: {codo[1]: const Punto(0.4, 0.45, 0, 0.2)});
    expect(anguloClinico(oculto, Articulacion.codo, Lado.derecho), isNull);
    expect(anguloClinico(cuerpo(), Articulacion.codo, Lado.izquierdo), isNull);
  });
}
