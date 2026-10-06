import 'dart:math' as math;

/// Filtro One Euro (Casiez et al., 2012): suaviza el temblor de la detección
/// sin agregar retardo perceptible en movimientos rápidos.
class FiltroOneEuro {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _x;
  double _dx = 0;
  double? _t;

  FiltroOneEuro({this.minCutoff = 1.0, this.beta = 0.0, this.dCutoff = 1.0});

  double? get ultimoT => _t;

  void reiniciar() {
    _x = null;
    _dx = 0;
    _t = null;
  }

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double filtrar(double x, double tS) {
    final xPrev = _x;
    final tPrev = _t;
    if (xPrev == null || tPrev == null) {
      _x = x;
      _t = tS;
      return x;
    }
    final dt = tS - tPrev;
    if (dt <= 0) return xPrev;
    final dx = (x - xPrev) / dt;
    final aD = _alpha(dCutoff, dt);
    final dxSuave = aD * dx + (1.0 - aD) * _dx;
    final cutoff = minCutoff + beta * dxSuave.abs();
    final a = _alpha(cutoff, dt);
    final xSuave = a * x + (1.0 - a) * xPrev;
    _x = xSuave;
    _dx = dxSuave;
    _t = tS;
    return xSuave;
  }
}
