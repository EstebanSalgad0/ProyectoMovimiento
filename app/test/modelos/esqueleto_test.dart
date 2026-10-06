import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/esqueleto.dart';

void main() {
  Map<int, (Offset, double)> puntos(double x) => {for (final i in indicesEsqueleto) i: (Offset(x, 0.5), 0.9)};

  test('el grabador limita la frecuencia y guarda cuadros sin persona', () {
    final g = GrabadorEsqueleto(intervaloMs: 100);
    expect(g.resultado(), isNull);
    g
      ..agregar(1000, puntos(0.1))
      ..agregar(1050, puntos(0.2)) // se omite (< 100 ms)
      ..agregar(1100, null)
      ..agregar(1200, puntos(0.3));
    final e = g.resultado()!;
    expect(e.tMs, [1000, 1100, 1200]);
    expect(e.cuadros[1], isNull);
    expect(e.duracionMs, 200);
    expect(e.puntosDe(2)[11]!.$1.dx, closeTo(0.3, 1e-9));
    expect(e.puntosDe(1), isEmpty);
  });

  test('busca el cuadro más cercano a un tiempo', () {
    final g = GrabadorEsqueleto()
      ..agregar(0, puntos(0))
      ..agregar(100, puntos(0))
      ..agregar(200, puntos(0));
    final e = g.resultado()!;
    expect(e.indiceEn(0), 0);
    expect(e.indiceEn(140), 1);
    expect(e.indiceEn(160), 2);
    expect(e.indiceEn(999), 2);
  });

  test('lee el formato que entrega el servidor', () {
    final e = EsqueletoGrabado.fromJson({
      'aspecto': 0.5625,
      'indices': [0, 11],
      't_ms': [0, 100],
      'puntos': [
        [0.5, 0.1, 0.99, 0.4, 0.3, 0.9],
        null,
      ],
    });
    expect(e.vacio, isFalse);
    expect(e.puntosDe(0)[11]!.$1, const Offset(0.4, 0.3));
    final vuelta = EsqueletoGrabado.fromJson(e.toJson());
    expect(vuelta.tMs, [0, 100]);
    expect(vuelta.cuadros[1], isNull);
  });
}
