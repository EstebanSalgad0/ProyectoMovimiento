// Ahora empiezo a programar el backend teniendo el sv.py en el modelo
// La idea es recibir el resultado del análisis del modelo y convertirlo en un objeto, json, para usarlo

class ResultadoAnalisis {
  final String ejercicio;
  final int puntaje;
  final List<String> feedback;
  final Map<String, double> metricas;

  ResultadoAnalisis({
    required this.ejercicio,
    required this.puntaje,
    required this.feedback,
    required this.metricas,
  });

  factory ResultadoAnalisis.fromJson(Map<String, dynamic> json) {
    return ResultadoAnalisis(
      ejercicio: json['ejercicio'] ?? '',
      puntaje:   json['puntaje']   ?? 0,
      feedback:  List<String>.from(json['feedback'] ?? []),
      metricas:  Map<String, double>.from(
          (json['metricas'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))
      ),
    );
  }
}