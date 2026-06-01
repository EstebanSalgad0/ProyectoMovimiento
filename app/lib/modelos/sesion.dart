import '../core/widgets/insignia_estado.dart';
import 'resultado_analisis.dart';

class Sesion {
  final String usuario;
  final String ejercicio;
  final int puntaje;
  final List<String> feedback;
  final Map<String, double> metricas;
  final DateTime fecha;
  final String? videoNombre;

  const Sesion({
	required this.usuario,
	required this.ejercicio,
	required this.puntaje,
	required this.feedback,
	required this.metricas,
	required this.fecha,
	this.videoNombre,
  });

  EstadoAnalisis get estado {
	if (puntaje >= 80) return EstadoAnalisis.correcto;
	if (puntaje >= 50) return EstadoAnalisis.advertencia;
	return EstadoAnalisis.peligro;
  }

  String get ejercicioFormateado => ejercicio.replaceAll('_', ' ');

  factory Sesion.desdeResultado({
	required String usuario,
	required ResultadoAnalisis resultado,
	DateTime? fecha,
	String? videoNombre,
  }) {
	return Sesion(
	  usuario: usuario,
	  ejercicio: resultado.ejercicio,
	  puntaje: resultado.puntaje,
	  feedback: List<String>.from(resultado.feedback),
	  metricas: Map<String, double>.from(resultado.metricas),
	  fecha: fecha ?? DateTime.now(),
	  videoNombre: videoNombre,
	);
  }

  factory Sesion.fromJson(Map<String, dynamic> json) {
	return Sesion(
	  usuario: json['usuario'] ?? '',
	  ejercicio: json['ejercicio'] ?? '',
	  puntaje: json['puntaje'] ?? 0,
	  feedback: List<String>.from(json['feedback'] ?? const []),
	  metricas: Map<String, double>.from(
		(json['metricas'] ?? const <String, dynamic>{})
			.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
	  ),
	  fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
	  videoNombre: json['videoNombre'],
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'usuario': usuario,
	  'ejercicio': ejercicio,
	  'puntaje': puntaje,
	  'feedback': feedback,
	  'metricas': metricas,
	  'fecha': fecha.toIso8601String(),
	  'videoNombre': videoNombre,
	};
  }
}


