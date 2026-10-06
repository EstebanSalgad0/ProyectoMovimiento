import 'dart:math';

import 'resultado_analisis.dart';

enum EstadoAnalisis { correcto, advertencia, peligro }

enum OrigenSesion {
  video('Video'),
  tiempoReal('Tiempo real');

  final String etiqueta;
  const OrigenSesion(this.etiqueta);

  static OrigenSesion desde(String? v) =>
      OrigenSesion.values.firstWhere((o) => o.name == v, orElse: () => OrigenSesion.video);
}

EstadoAnalisis estadoDePuntaje(int puntaje) {
  if (puntaje >= 80) return EstadoAnalisis.correcto;
  if (puntaje >= 50) return EstadoAnalisis.advertencia;
  return EstadoAnalisis.peligro;
}

class Sesion {
  final String id;
  final String usuario;
  final DateTime fecha;
  final OrigenSesion origen;
  final ResultadoAnalisis resultado;
  final String? videoNombre;

  const Sesion({
    required this.id,
    required this.usuario,
    required this.fecha,
    required this.origen,
    required this.resultado,
    this.videoNombre,
  });

  String get ejercicio => resultado.ejercicio;
  int get puntaje => resultado.puntaje;
  EstadoAnalisis get estado => estadoDePuntaje(puntaje);

  static String nuevoId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 30).toRadixString(36)}';
  }

  factory Sesion.nueva({
    required String usuario,
    required OrigenSesion origen,
    required ResultadoAnalisis resultado,
    String? videoNombre,
  }) => Sesion(
    id: nuevoId(),
    usuario: usuario,
    fecha: DateTime.now(),
    origen: origen,
    resultado: resultado,
    videoNombre: videoNombre,
  );

  /// Acepta el formato nuevo ({..., resultado: {...}}) y el de la app v1, que
  /// guardaba ejercicio/puntaje/feedback/metricas directamente en la sesión.
  factory Sesion.fromJson(Map<String, dynamic> json) {
    final fecha = DateTime.tryParse((json['fecha'] ?? '') as String) ?? DateTime.now();
    final resultadoJson = json['resultado'] is Map
        ? Map<String, dynamic>.from(json['resultado'] as Map)
        : <String, dynamic>{
            'version': '1',
            'ejercicio': json['ejercicio'] ?? '',
            'puntaje': json['puntaje'] ?? 0,
            'feedback': json['feedback'] ?? const [],
            'metricas': json['metricas'] ?? const {},
          };
    return Sesion(
      id: (json['id'] ?? 'v1-${fecha.microsecondsSinceEpoch}') as String,
      usuario: (json['usuario'] ?? '') as String,
      fecha: fecha,
      origen: OrigenSesion.desde(json['origen'] as String?),
      resultado: ResultadoAnalisis.fromJson(resultadoJson),
      videoNombre: json['videoNombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': usuario,
    'fecha': fecha.toIso8601String(),
    'origen': origen.name,
    'videoNombre': videoNombre,
    'resultado': resultado.toJson(),
  };
}
