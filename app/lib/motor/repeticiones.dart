// Detección de repeticiones con máquina de estados e histéresis
// (port de servidor/motor/repeticiones.py).
//
// La señal se orienta con 'signo' para que el movimiento siempre "suba":
//   reposo --(d > inicio)--> movimiento --(d < fin)--> reposo  => repetición

import 'especificacion.dart';

enum Fase { reposo, ida, vuelta }

/// Margen (en unidades de la señal) para pasar de 'ida' a 'vuelta'.
const histeresisFase = 4.0;

class EventoRepeticion {
  final bool valida;
  final int idxReposo;
  final int idxInicio;
  final int idxPico;
  final int idxFin;
  final double tInicioS;
  final double tPicoS;
  final double tFinS;

  const EventoRepeticion({
    required this.valida,
    required this.idxReposo,
    required this.idxInicio,
    required this.idxPico,
    required this.idxFin,
    required this.tInicioS,
    required this.tPicoS,
    required this.tFinS,
  });
}

class DetectorRepeticiones {
  final int signo;
  final double inicio;
  final double fin;
  final double minimo;
  final double duracionMinimaS;

  bool _enMovimiento = false;
  double? _dActual;
  double? _dReposo;
  int _idxReposo = 0;
  int _idxInicio = 0;
  double _tInicio = 0;
  double _dPico = 0;
  int _idxPico = 0;
  double _tPico = 0;

  DetectorRepeticiones(Senal senal, this.duracionMinimaS)
    : signo = senal.signo,
      inicio = senal.signo * senal.inicio,
      fin = senal.signo * senal.fin,
      minimo = senal.signo * senal.minimoRep;

  Fase get fase {
    final d = _dActual;
    if (!_enMovimiento || d == null) return Fase.reposo;
    return _dPico - d > histeresisFase ? Fase.vuelta : Fase.ida;
  }

  /// Avance del movimiento entre el umbral de inicio (0) y el mínimo válido (1).
  double progreso(double? valor) {
    if (valor == null) return 0;
    final d = signo * valor;
    return ((d - fin) / (minimo - fin)).clamp(0.0, 1.0);
  }

  EventoRepeticion? actualizar(int idx, double tS, double? valor) {
    if (valor == null) return null;
    final d = signo * valor;
    _dActual = d;
    if (!_enMovimiento) {
      final reposo = _dReposo;
      if (reposo == null || d < reposo) {
        _dReposo = d;
        _idxReposo = idx;
      }
      if (d > inicio) {
        _enMovimiento = true;
        _idxInicio = idx;
        _tInicio = tS;
        _dPico = d;
        _idxPico = idx;
        _tPico = tS;
      }
      return null;
    }

    if (d > _dPico) {
      _dPico = d;
      _idxPico = idx;
      _tPico = tS;
    }
    if (d >= fin) return null;

    final evento = EventoRepeticion(
      valida: _dPico >= minimo,
      idxReposo: _idxReposo,
      idxInicio: _idxInicio,
      idxPico: _idxPico,
      idxFin: idx,
      tInicioS: _tInicio,
      tPicoS: _tPico,
      tFinS: tS,
    );
    _enMovimiento = false;
    _dReposo = d;
    _idxReposo = idx;
    if (tS - _tInicio < duracionMinimaS) return null;
    return evento;
  }
}
