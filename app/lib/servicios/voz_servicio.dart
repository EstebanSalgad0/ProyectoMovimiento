import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Indicaciones por voz durante el entrenamiento en tiempo real.
class VozServicio {
  final FlutterTts _tts = FlutterTts();
  bool _listo = false;
  double _velocidad = 0.5;
  DateTime _ultima = DateTime.fromMillisecondsSinceEpoch(0);

  /// Velocidad de habla (0,35 lenta · 0,5 normal · 0,6 rápida).
  Future<void> cambiarVelocidad(double velocidad) async {
    _velocidad = velocidad;
    if (!_listo) return;
    try {
      await _tts.setSpeechRate(velocidad);
    } catch (_) {}
  }

  Future<void> _preparar() async {
    if (_listo) return;
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(_velocidad);
      await _tts.awaitSpeakCompletion(false);
      _listo = true;
    } catch (e) {
      debugPrint('Voz no disponible: $e');
    }
  }

  /// Habla [texto]. Si [prioritario] es falso y se habló hace poco, se omite
  /// para no saturar al usuario.
  Future<void> decir(String texto, {bool prioritario = false, Duration espera = const Duration(seconds: 2)}) async {
    final ahora = DateTime.now();
    if (!prioritario && ahora.difference(_ultima) < espera) return;
    _ultima = ahora;
    await _preparar();
    if (!_listo) return;
    try {
      if (prioritario) await _tts.stop();
      await _tts.speak(texto);
    } catch (e) {
      debugPrint('Error de voz: $e');
    }
  }

  Future<void> detener() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
