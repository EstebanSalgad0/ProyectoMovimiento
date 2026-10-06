// Fotograma con los 33 puntos corporales de BlazePose. ML Kit (app) y
// MediaPipe (servidor) comparten el mismo orden de puntos.

const numPuntos = 33;

const nariz = 0;
const hombro = [11, 12]; // [izquierdo, derecho]
const codo = [13, 14];
const muneca = [15, 16];
const cadera = [23, 24];
const rodilla = [25, 26];
const tobillo = [27, 28];

const gruposPuntos = <String, List<int>>{
  'cara': [nariz],
  'hombros': hombro,
  'codos': codo,
  'munecas': muneca,
  'caderas': cadera,
  'rodillas': rodilla,
  'tobillos': tobillo,
};

/// Segmentos del esqueleto que se dibujan sobre la cámara.
const conexionesEsqueleto = [
  [11, 12], [11, 13], [13, 15], [12, 14], [14, 16], //
  [11, 23], [12, 24], [23, 24], //
  [23, 25], [25, 27], [24, 26], [26, 28], //
  [27, 31], [28, 32],
];

class Punto {
  final double x;
  final double y;
  final double z;

  /// Visibilidad o probabilidad de estar en cuadro, entre 0 y 1.
  final double v;

  const Punto(this.x, this.y, this.z, [this.v = 1.0]);

  static const ausente = Punto(0, 0, 0, 0);
}

class Fotograma {
  final int tMs;

  /// 33 puntos en píxeles (x, y, z con la misma escala) o null si no hay persona.
  final List<Punto>? imagen;

  /// 33 puntos opcionales en metros. Si existen, los ángulos se calculan con ellos.
  final List<Punto>? mundo;

  const Fotograma(this.tMs, {this.imagen, this.mundo});

  /// Construye desde listas JSON [[x, y, z, v], ...] (formato de la API y fixtures).
  factory Fotograma.desdeListas(int tMs, List<dynamic>? puntos, [List<dynamic>? mundo]) {
    List<Punto>? imagen;
    if (puntos != null) {
      imagen = puntos.map((p) {
        if (p == null) return Punto.ausente;
        final l = (p as List).map((e) => (e as num).toDouble()).toList();
        return Punto(l[0], l[1], l[2], l.length > 3 ? l[3] : 1.0);
      }).toList();
    }
    List<Punto>? m;
    if (mundo != null) {
      m = mundo.map((p) {
        final l = (p as List).map((e) => (e as num).toDouble()).toList();
        return Punto(l[0], l[1], l[2]);
      }).toList();
    }
    return Fotograma(tMs, imagen: imagen, mundo: m);
  }

  List<List<double>>? imagenComoListas() => imagen?.map((p) => [p.x, p.y, p.z, p.v]).toList();
}
