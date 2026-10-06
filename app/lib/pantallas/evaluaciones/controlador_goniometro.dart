import 'package:flutter/foundation.dart';

import '../../modelos/evaluacion.dart';
import '../../modelos/usuario.dart';
import '../../motor/filtro_one_euro.dart';
import '../../motor/geometria.dart';
import '../../motor/puntos.dart';
import '../tiempo_real/camara_pose.dart';

/// Índices (a, b, c) del ángulo a medir; b es la articulación.
(int, int, int) indicesArticulacion(Articulacion a, Lado lado) {
  final k = lado == Lado.izquierdo ? 0 : 1;
  return switch (a) {
    Articulacion.hombro => (codo[k], hombro[k], cadera[k]),
    Articulacion.codo => (hombro[k], codo[k], muneca[k]),
    Articulacion.cadera => (hombro[k], cadera[k], rodilla[k]),
    Articulacion.rodilla => (cadera[k], rodilla[k], tobillo[k]),
  };
}

/// Ángulo clínico en grados (0 = posición neutra) a partir de los puntos, o
/// null si alguno no se ve. Se usa 2D: la cámara debe quedar perpendicular al
/// plano del movimiento, como con un goniómetro.
double? anguloClinico(List<Punto> p, Articulacion articulacion, Lado lado, {double visibilidadMinima = 0.5}) {
  final (a, b, c) = indicesArticulacion(articulacion, lado);
  if (p[a].v < visibilidadMinima || p[b].v < visibilidadMinima || p[c].v < visibilidadMinima) return null;
  Punto plano(Punto x) => Punto(x.x, x.y, 0);
  final interior = anguloArticular(plano(p[a]), plano(p[b]), plano(p[c]));
  if (interior.isNaN) return null;
  // Hombro: el ángulo brazo-tronco ya es la elevación. El resto: flexión = 180 - interior.
  return articulacion == Articulacion.hombro ? interior : 180 - interior;
}

/// Mide en vivo el ángulo de una articulación y guarda el máximo alcanzado.
class ControladorGoniometro extends ChangeNotifier {
  final CamaraPose camara;
  Articulacion articulacion;
  Lado lado;

  ControladorGoniometro({required this.camara, required this.articulacion, required this.lado}) {
    camara.alFotograma = _alFotograma;
    camara.addListener(_reenviar);
  }

  final FiltroOneEuro _filtro = FiltroOneEuro(minCutoff: 1.0, beta: 0.02);
  final List<double> _recientes = [];
  double? valor;
  double? maximo;
  bool _cerrado = false;

  bool get visible => valor != null;

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  void _reenviar() => _notificar();

  void configurar({Articulacion? articulacion, Lado? lado}) {
    if (articulacion != null) this.articulacion = articulacion;
    if (lado != null) this.lado = lado;
    reiniciar();
  }

  void reiniciar() {
    valor = null;
    maximo = null;
    _recientes.clear();
    _filtro.reiniciar();
    _notificar();
  }

  void _alFotograma(Fotograma f) {
    final p = f.imagen;
    final bruto = p == null ? null : anguloClinico(p, articulacion, lado);
    if (bruto == null) {
      valor = null;
      _recientes.clear();
      return;
    }
    final v = _filtro.filtrar(bruto, f.tMs / 1000);
    valor = v;
    // El máximo exige que el valor se sostenga 3 cuadros (evita picos de ruido).
    _recientes.add(v);
    if (_recientes.length > 3) _recientes.removeAt(0);
    if (_recientes.length == 3) {
      final sostenido = _recientes.reduce((a, b) => a < b ? a : b);
      if (maximo == null || sostenido > maximo!) maximo = sostenido;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    camara.removeListener(_reenviar);
    if (camara.alFotograma == _alFotograma) camara.alFotograma = null;
    super.dispose();
  }
}
