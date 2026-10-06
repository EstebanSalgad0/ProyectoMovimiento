import 'dart:io';

import 'package:flutter/foundation.dart';

/// Configuración general de la app.
///
/// La URL del servidor se puede fijar al compilar:
///   flutter run --dart-define=API_URL=http://192.168.1.50:8000
/// y también cambiarse en la app (Cuenta → Servidor de análisis).
class AppConfig {
  static const nombreApp = 'Movimiento';
  static const nombreCompleto = 'Proyecto Movimiento';
  static const lema = 'Análisis de movimiento con IA';
  static const version = '2.0.0';
  static const nivelMadurez = 'Prototipo TRL 3–4';

  static const _urlDefinida = String.fromEnvironment('API_URL');

  /// URL por defecto: el emulador de Android llega al PC con 10.0.2.2; el
  /// simulador de iOS, con localhost. En un teléfono físico se usa la IP local
  /// del computador (misma red Wi-Fi).
  static String get urlServidorPorDefecto {
    if (_urlDefinida.isNotEmpty) return _urlDefinida;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// Duración máxima de un video grabado desde la app.
  static const duracionMaximaVideo = Duration(seconds: 60);

  /// Segundos de cuenta regresiva antes de empezar en tiempo real.
  static const cuentaRegresiva = 3;

  static const avisoMedico =
      'Esta app es un apoyo para la práctica de ejercicio. No reemplaza la evaluación de un profesional de la salud.';
}
