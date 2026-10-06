import 'dart:math' as math;

import 'puntos.dart';

const _gradosPorRadian = 180 / math.pi;

/// Ángulo interior en b formado por a-b-c, en grados (180 = extendido).
double anguloArticular(Punto a, Punto b, Punto c) {
  final v1x = a.x - b.x, v1y = a.y - b.y, v1z = a.z - b.z;
  final v2x = c.x - b.x, v2y = c.y - b.y, v2z = c.z - b.z;
  final n1 = math.sqrt(v1x * v1x + v1y * v1y + v1z * v1z);
  final n2 = math.sqrt(v2x * v2x + v2y * v2y + v2z * v2z);
  if (n1 < 1e-9 || n2 < 1e-9) return double.nan;
  final coseno = ((v1x * v2x + v1y * v2y + v1z * v2z) / (n1 * n2)).clamp(-1.0, 1.0);
  return math.acos(coseno) * _gradosPorRadian;
}

/// Grados entre el segmento inferior→superior y la vertical de la imagen (y hacia abajo).
double inclinacionDesdeVertical(Punto inferior, Punto superior) {
  final dx = superior.x - inferior.x;
  final dy = superior.y - inferior.y;
  if (dx.abs() < 1e-9 && dy.abs() < 1e-9) return double.nan;
  return math.atan2(dx.abs(), -dy) * _gradosPorRadian;
}

/// Grados [0, 90] entre la línea a-b y la horizontal de la imagen.
double inclinacionDesdeHorizontal(Punto a, Punto b) {
  final dx = (b.x - a.x).abs();
  final dy = (b.y - a.y).abs();
  if (dx < 1e-9 && dy < 1e-9) return double.nan;
  return math.atan2(dy, dx) * _gradosPorRadian;
}

double distancia2d(Punto a, Punto b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

Punto puntoMedio(Punto a, Punto b) => Punto((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);

/// Redondeo "mitad hacia arriba", idéntico al del servidor (Python).
int redondear(double x) => (x + 0.5).floor();
