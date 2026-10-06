// Métricas biomecánicas por fotograma (port de servidor/motor/metricas.py).
//
// - Ángulos articulares en 3D (puntos "mundo" si existen; si no, x/y/z en px).
// - Alineaciones en 2D normalizadas por tamaño corporal.
// - Un punto con visibilidad bajo el mínimo se considera ausente.

import 'geometria.dart';
import 'puntos.dart';

const vistaFrontal = 'frontal';
const vistaLateral = 'lateral';
const vistaOblicua = 'oblicua';

const _lados = ['izq', 'der'];
const _basesBilaterales = ['rodilla', 'cadera', 'codo', 'hombro'];

double? _limpio(double x) => x.isNaN ? null : x;

class _Contexto {
  final List<Punto> img;
  final List<Punto> tresD;
  final double vmin;

  _Contexto(Fotograma f, this.vmin) : img = f.imagen!, tresD = f.mundo ?? f.imagen!;

  bool visible(List<int> indices) => indices.every((i) => img[i].v >= vmin);
  Punto p2(int i) => img[i];
  Punto p3(int i) => tresD[i];
}

double? _largoTronco(_Contexto c) {
  if (c.visible([...hombro, ...cadera])) {
    final h = puntoMedio(c.p2(hombro[0]), c.p2(hombro[1]));
    final ca = puntoMedio(c.p2(cadera[0]), c.p2(cadera[1]));
    final largo = distancia2d(h, ca);
    return largo > 1e-6 ? largo : null;
  }
  for (final k in [0, 1]) {
    if (c.visible([hombro[k], cadera[k]])) {
      final largo = distancia2d(c.p2(hombro[k]), c.p2(cadera[k]));
      return largo > 1e-6 ? largo : null;
    }
  }
  return null;
}

(Punto, Punto)? _referenciaTronco(_Contexto c) {
  if (c.visible([...hombro, ...cadera])) {
    return (puntoMedio(c.p2(cadera[0]), c.p2(cadera[1])), puntoMedio(c.p2(hombro[0]), c.p2(hombro[1])));
  }
  for (final k in [0, 1]) {
    if (c.visible([hombro[k], cadera[k]])) return (c.p2(cadera[k]), c.p2(hombro[k]));
  }
  return null;
}

/// Desplazamiento medial de la rodilla respecto de la línea cadera-tobillo,
/// normalizado por el ancho de cadera. Positivo = valgo (rodilla hacia adentro).
double? _valgo(_Contexto c, int k, double? tronco) {
  final otra = 1 - k;
  if (!c.visible([cadera[k], rodilla[k], tobillo[k], cadera[otra]])) return null;
  final ca = c.p2(cadera[k]), ro = c.p2(rodilla[k]), to = c.p2(tobillo[k]);
  final otraCadera = c.p2(cadera[otra]);
  final ancho = (ca.x - otraCadera.x).abs();
  if (ancho < 1e-6 || (tronco != null && ancho < 0.15 * tronco)) return null;
  final dy = to.y - ca.y;
  if (dy.abs() < 1e-6) return null;
  final t = (ro.y - ca.y) / dy;
  final lineaX = ca.x + t * (to.x - ca.x);
  final medioX = (ca.x + otraCadera.x) / 2;
  final direccion = medioX >= lineaX ? 1.0 : -1.0;
  return (ro.x - lineaX) * direccion / ancho;
}

double? _min(List<double> v) => v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
double? _max(List<double> v) => v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);

Map<String, double?> calcularMetricas(Fotograma f, double vmin) {
  final m = <String, double?>{};
  if (f.imagen == null) return m;
  final c = _Contexto(f, vmin);
  final tronco = _largoTronco(c);

  for (var k = 0; k < 2; k++) {
    final lado = _lados[k];
    final h = hombro[k], co = codo[k], mu = muneca[k], ca = cadera[k], r = rodilla[k], t = tobillo[k];
    m['rodilla_$lado'] = c.visible([ca, r, t]) ? _limpio(anguloArticular(c.p3(ca), c.p3(r), c.p3(t))) : null;
    m['cadera_$lado'] = c.visible([h, ca, r]) ? _limpio(anguloArticular(c.p3(h), c.p3(ca), c.p3(r))) : null;
    m['codo_$lado'] = c.visible([h, co, mu]) ? _limpio(anguloArticular(c.p3(h), c.p3(co), c.p3(mu))) : null;
    m['hombro_$lado'] = c.visible([co, h, ca]) ? _limpio(anguloArticular(c.p3(co), c.p3(h), c.p3(ca))) : null;
    m['valgo_$lado'] = _valgo(c, k, tronco);
  }

  for (final base in _basesBilaterales) {
    final valores = [m['${base}_izq'], m['${base}_der']].whereType<double>().toList();
    m['${base}_promedio'] = valores.isEmpty ? null : valores.reduce((a, b) => a + b) / valores.length;
    m['${base}_min'] = _min(valores);
    m['${base}_max'] = _max(valores);
  }

  m['valgo_max'] = _max([m['valgo_izq'], m['valgo_der']].whereType<double>().toList());
  final ri = m['rodilla_izq'], rd = m['rodilla_der'];
  if (ri != null && rd != null) {
    m['valgo_delantera'] = ri <= rd ? m['valgo_izq'] : m['valgo_der'];
  } else {
    m['valgo_delantera'] = ri != null ? m['valgo_izq'] : (rd != null ? m['valgo_der'] : null);
  }

  final ref = _referenciaTronco(c);
  m['tronco_inclinacion'] = ref == null ? null : _limpio(inclinacionDesdeVertical(ref.$1, ref.$2));
  m['pelvis_inclinacion'] = c.visible(cadera)
      ? _limpio(inclinacionDesdeHorizontal(c.p2(cadera[0]), c.p2(cadera[1])))
      : null;
  m['hombros_inclinacion'] = c.visible(hombro)
      ? _limpio(inclinacionDesdeHorizontal(c.p2(hombro[0]), c.p2(hombro[1])))
      : null;

  final munecas = [
    for (final i in muneca)
      if (c.visible([i])) c.p2(i).y,
  ];
  if (c.visible([nariz]) && munecas.isNotEmpty && tronco != null) {
    final promedio = munecas.reduce((a, b) => a + b) / munecas.length;
    m['munecas_sobre_nariz'] = (c.p2(nariz).y - promedio) / tronco;
  } else {
    m['munecas_sobre_nariz'] = null;
  }
  return m;
}

/// Clasifica la vista según la razón ancho de hombros / largo de tronco (2D).
String? detectarVista(Fotograma f, double vmin, double umbralFrontal, double umbralLateral) {
  if (f.imagen == null) return null;
  final c = _Contexto(f, vmin);
  final tronco = _largoTronco(c);
  if (tronco == null) return null;
  if (!c.visible(hombro)) return vistaLateral;
  final razon = distancia2d(c.p2(hombro[0]), c.p2(hombro[1])) / tronco;
  if (razon >= umbralFrontal) return vistaFrontal;
  if (razon <= umbralLateral) return vistaLateral;
  return vistaOblicua;
}

/// Grupos requeridos sin ningún lado visible.
List<String> gruposFaltantes(Fotograma f, double vmin, List<String> requeridos) {
  final img = f.imagen;
  if (img == null) return List.of(requeridos);
  return [
    for (final g in requeridos)
      if (!gruposPuntos[g]!.any((i) => img[i].v >= vmin)) g,
  ];
}
