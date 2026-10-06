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

/// Cómo se sintió la persona después de la sesión (escalas 0–10).
class Sensaciones {
  /// Esfuerzo percibido (escala de Borg modificada, 0 = reposo, 10 = máximo).
  final int esfuerzo;

  /// Dolor (escala numérica, 0 = sin dolor, 10 = el peor imaginable).
  final int dolor;
  final String? zonaDolor;
  final String nota;

  const Sensaciones({required this.esfuerzo, required this.dolor, this.zonaDolor, this.nota = ''});

  factory Sensaciones.fromJson(Map<String, dynamic> j) => Sensaciones(
    esfuerzo: (j['esfuerzo'] as num? ?? 0).toInt(),
    dolor: (j['dolor'] as num? ?? 0).toInt(),
    zonaDolor: j['zona_dolor'] as String?,
    nota: (j['nota'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => {'esfuerzo': esfuerzo, 'dolor': dolor, 'zona_dolor': zonaDolor, 'nota': nota};

  static String etiquetaEsfuerzo(int v) => switch (v) {
    0 => 'Reposo',
    1 || 2 => 'Muy suave',
    3 || 4 => 'Suave',
    5 || 6 => 'Moderado',
    7 || 8 => 'Intenso',
    _ => 'Máximo',
  };

  static String etiquetaDolor(int v) => switch (v) {
    0 => 'Sin dolor',
    1 || 2 || 3 => 'Leve',
    4 || 5 || 6 => 'Moderado',
    _ => 'Intenso',
  };
}

/// Datos de la rutina guiada a la que pertenece una serie.
class ContextoRutina {
  final String rutinaId;
  final String rutinaNombre;

  /// Identifica una ejecución completa de la rutina (agrupa sus series).
  final String ejecucionId;
  final int serie;
  final int totalSeries;

  const ContextoRutina({
    required this.rutinaId,
    required this.rutinaNombre,
    required this.ejecucionId,
    required this.serie,
    required this.totalSeries,
  });

  factory ContextoRutina.fromJson(Map<String, dynamic> j) => ContextoRutina(
    rutinaId: (j['rutina_id'] ?? '') as String,
    rutinaNombre: (j['rutina_nombre'] ?? '') as String,
    ejecucionId: (j['ejecucion_id'] ?? '') as String,
    serie: (j['serie'] as num? ?? 1).toInt(),
    totalSeries: (j['total_series'] as num? ?? 1).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'rutina_id': rutinaId,
    'rutina_nombre': rutinaNombre,
    'ejecucion_id': ejecucionId,
    'serie': serie,
    'total_series': totalSeries,
  };
}

class Sesion {
  final String id;
  final String usuario;
  final DateTime fecha;
  final OrigenSesion origen;
  final ResultadoAnalisis resultado;
  final String? videoNombre;
  final Sensaciones? sensaciones;
  final ContextoRutina? rutina;

  /// Hay un esqueleto guardado aparte para revisar el movimiento.
  final bool tieneEsqueleto;

  /// Copia local del video analizado (solo sesiones de video).
  final String? videoRuta;

  const Sesion({
    required this.id,
    required this.usuario,
    required this.fecha,
    required this.origen,
    required this.resultado,
    this.videoNombre,
    this.sensaciones,
    this.rutina,
    this.tieneEsqueleto = false,
    this.videoRuta,
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
    ContextoRutina? rutina,
  }) => Sesion(
    id: nuevoId(),
    usuario: usuario,
    fecha: DateTime.now(),
    origen: origen,
    resultado: resultado,
    videoNombre: videoNombre,
    rutina: rutina,
  );

  Sesion copyWith({Sensaciones? sensaciones, bool? tieneEsqueleto, String? videoRuta, bool borrarVideo = false}) =>
      Sesion(
        id: id,
        usuario: usuario,
        fecha: fecha,
        origen: origen,
        resultado: resultado,
        videoNombre: videoNombre,
        sensaciones: sensaciones ?? this.sensaciones,
        rutina: rutina,
        tieneEsqueleto: tieneEsqueleto ?? this.tieneEsqueleto,
        videoRuta: borrarVideo ? null : (videoRuta ?? this.videoRuta),
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
      sensaciones: json['sensaciones'] is Map
          ? Sensaciones.fromJson(Map<String, dynamic>.from(json['sensaciones'] as Map))
          : null,
      rutina: json['rutina'] is Map ? ContextoRutina.fromJson(Map<String, dynamic>.from(json['rutina'] as Map)) : null,
      tieneEsqueleto: (json['tiene_esqueleto'] ?? false) as bool,
      videoRuta: json['video_ruta'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': usuario,
    'fecha': fecha.toIso8601String(),
    'origen': origen.name,
    'videoNombre': videoNombre,
    'resultado': resultado.toJson(),
    if (sensaciones != null) 'sensaciones': sensaciones!.toJson(),
    if (rutina != null) 'rutina': rutina!.toJson(),
    'tiene_esqueleto': tieneEsqueleto,
    if (videoRuta != null) 'video_ruta': videoRuta,
  };
}
