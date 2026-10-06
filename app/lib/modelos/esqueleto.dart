import 'dart:ui';

/// Puntos que se guardan para revisar el movimiento (cara, brazos, piernas y pies).
const indicesEsqueleto = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28, 31, 32];

/// Secuencia de esqueletos de una sesión, en coordenadas normalizadas (0–1)
/// tal como se veían en pantalla. Mismo formato que entrega el servidor en
/// `resultado["esqueleto"]`.
class EsqueletoGrabado {
  /// Ancho / alto de la imagen.
  final double aspecto;
  final List<int> indices;
  final List<int> tMs;

  /// Por cuadro: [x, y, visibilidad] por cada índice (aplanado), o null si no
  /// había persona.
  final List<List<double>?> cuadros;

  const EsqueletoGrabado({required this.aspecto, required this.indices, required this.tMs, required this.cuadros});

  bool get vacio => cuadros.every((c) => c == null);
  int get duracionMs => tMs.isEmpty ? 0 : tMs.last - tMs.first;

  /// Cuadro más cercano a [t] (ms desde el inicio de la grabación).
  int indiceEn(int t) {
    if (tMs.isEmpty) return 0;
    final objetivo = tMs.first + t;
    var lo = 0, hi = tMs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (tMs[mid] < objetivo) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && (objetivo - tMs[lo - 1]) < (tMs[lo] - objetivo)) return lo - 1;
    return lo;
  }

  /// Puntos del cuadro [i] como mapa índice → (posición normalizada, visibilidad).
  Map<int, (Offset, double)> puntosDe(int i) {
    final c = cuadros[i];
    if (c == null) return const {};
    return {for (var k = 0; k < indices.length; k++) indices[k]: (Offset(c[k * 3], c[k * 3 + 1]), c[k * 3 + 2])};
  }

  factory EsqueletoGrabado.fromJson(Map<String, dynamic> j) => EsqueletoGrabado(
    aspecto: (j['aspecto'] as num? ?? 0.5625).toDouble(),
    indices: ((j['indices'] ?? indicesEsqueleto) as List).map((e) => (e as num).toInt()).toList(),
    tMs: ((j['t_ms'] ?? const []) as List).map((e) => (e as num).toInt()).toList(),
    cuadros: ((j['puntos'] ?? const []) as List)
        .map((c) => c == null ? null : (c as List).map((e) => (e as num).toDouble()).toList())
        .toList(),
  );

  Map<String, dynamic> toJson() => {'aspecto': aspecto, 'indices': indices, 't_ms': tMs, 'puntos': cuadros};
}

/// Acumula cuadros durante la sesión, limitando la frecuencia para no ocupar
/// demasiado espacio (~10 cuadros por segundo).
class GrabadorEsqueleto {
  final int intervaloMs;
  double aspecto = 0.5625;
  final List<int> _t = [];
  final List<List<double>?> _cuadros = [];
  int? _ultimo;

  GrabadorEsqueleto({this.intervaloMs = 100});

  bool get vacio => _cuadros.every((c) => c == null);

  void reiniciar() {
    _t.clear();
    _cuadros.clear();
    _ultimo = null;
  }

  /// [puntos]: índice → (posición normalizada en pantalla, visibilidad).
  void agregar(int tMs, Map<int, (Offset, double)>? puntos) {
    final u = _ultimo;
    if (u != null && tMs - u < intervaloMs) return;
    _ultimo = tMs;
    _t.add(tMs);
    if (puntos == null) {
      _cuadros.add(null);
      return;
    }
    double r(double v, [int f = 1000]) => (v * f).roundToDouble() / f;
    _cuadros.add([
      for (final i in indicesEsqueleto) ...[
        r(puntos[i]?.$1.dx ?? 0),
        r(puntos[i]?.$1.dy ?? 0),
        r(puntos[i]?.$2 ?? 0, 100),
      ],
    ]);
  }

  EsqueletoGrabado? resultado() => vacio
      ? null
      : EsqueletoGrabado(aspecto: aspecto, indices: indicesEsqueleto, tMs: List.of(_t), cuadros: List.of(_cuadros));
}
