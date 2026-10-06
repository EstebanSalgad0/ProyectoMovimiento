// Resultado de un análisis. El mismo formato sale del servidor (video) y del
// motor local (tiempo real). También acepta el formato v1 del servidor antiguo
// (solo ejercicio, puntaje, feedback y métricas).

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

enum Severidad {
  alta,
  moderada,
  leve,
  info;

  static Severidad desde(String? v) => Severidad.values.firstWhere((s) => s.name == v, orElse: () => Severidad.info);

  String get etiqueta => switch (this) {
    Severidad.alta => 'Importante',
    Severidad.moderada => 'A corregir',
    Severidad.leve => 'Detalle',
    Severidad.info => 'Sugerencia',
  };
}

class Hallazgo {
  final String codigo;
  final Severidad severidad;
  final String zona;
  final String titulo;
  final String mensaje;
  final List<int> repeticiones;
  final int? totalEvaluadas;
  final double? valor;
  final double? umbral;

  const Hallazgo({
    required this.codigo,
    required this.severidad,
    required this.zona,
    required this.titulo,
    required this.mensaje,
    this.repeticiones = const [],
    this.totalEvaluadas,
    this.valor,
    this.umbral,
  });

  factory Hallazgo.fromJson(Map<String, dynamic> j) => Hallazgo(
    codigo: (j['codigo'] ?? '') as String,
    severidad: Severidad.desde(j['severidad'] as String?),
    zona: (j['zona'] ?? 'general') as String,
    titulo: (j['titulo'] ?? '') as String,
    mensaje: (j['mensaje'] ?? '') as String,
    repeticiones: ((j['repeticiones'] ?? const []) as List).map((e) => (e as num).toInt()).toList(),
    totalEvaluadas: (j['total_evaluadas'] as num?)?.toInt(),
    valor: (j['valor'] as num?)?.toDouble(),
    umbral: (j['umbral'] as num?)?.toDouble(),
  );

  /// "En 2 de 5 repeticiones" (si aplica).
  String? get frecuencia {
    if (repeticiones.isEmpty || totalEvaluadas == null) return null;
    if (repeticiones.length == totalEvaluadas) {
      return totalEvaluadas == 1 ? 'En la repetición' : 'En todas las repeticiones';
    }
    return 'En ${repeticiones.length} de $totalEvaluadas repeticiones';
  }
}

class Acierto {
  final String codigo;
  final String zona;
  final String mensaje;

  const Acierto({required this.codigo, required this.zona, required this.mensaje});

  factory Acierto.fromJson(Map<String, dynamic> j) => Acierto(
    codigo: (j['codigo'] ?? '') as String,
    zona: (j['zona'] ?? 'general') as String,
    mensaje: (j['mensaje'] ?? '') as String,
  );
}

class Repeticion {
  final int numero;
  final int inicioMs;
  final int picoMs;
  final int finMs;
  final double duracionS;
  final double excentricaS;
  final double concentricaS;
  final double valorPico;
  final double valorReposo;
  final double rango;
  final String? vista;
  final int puntaje;
  final List<String> fallos;
  final Map<String, double> valores;

  const Repeticion({
    required this.numero,
    required this.inicioMs,
    required this.picoMs,
    required this.finMs,
    required this.duracionS,
    required this.excentricaS,
    required this.concentricaS,
    required this.valorPico,
    required this.valorReposo,
    required this.rango,
    required this.vista,
    required this.puntaje,
    required this.fallos,
    required this.valores,
  });

  factory Repeticion.fromJson(Map<String, dynamic> j) => Repeticion(
    numero: (j['numero'] as num).toInt(),
    inicioMs: (j['inicio_ms'] as num).toInt(),
    picoMs: (j['pico_ms'] as num).toInt(),
    finMs: (j['fin_ms'] as num).toInt(),
    duracionS: _d(j['duracion_s']),
    excentricaS: _d(j['excentrica_s']),
    concentricaS: _d(j['concentrica_s']),
    valorPico: _d(j['valor_pico']),
    valorReposo: _d(j['valor_reposo']),
    rango: _d(j['rango']),
    vista: j['vista'] as String?,
    puntaje: (j['puntaje'] as num).toInt(),
    fallos: ((j['fallos'] ?? const []) as List).cast<String>(),
    valores: ((j['valores'] ?? const {}) as Map).map((k, v) => MapEntry(k as String, _d(v))),
  );
}

class SerieTemporal {
  final String metrica;
  final String nombre;
  final String unidad;
  final List<int> tMs;
  final List<double?> valores;

  const SerieTemporal({
    required this.metrica,
    required this.nombre,
    required this.unidad,
    required this.tMs,
    required this.valores,
  });

  bool get tieneDatos => valores.any((v) => v != null);

  factory SerieTemporal.fromJson(Map<String, dynamic> j) => SerieTemporal(
    metrica: (j['metrica'] ?? '') as String,
    nombre: (j['nombre'] ?? '') as String,
    unidad: (j['unidad'] ?? '') as String,
    tMs: ((j['t_ms'] ?? const []) as List).map((e) => (e as num).toInt()).toList(),
    valores: ((j['valores'] ?? const []) as List).map((e) => (e as num?)?.toDouble()).toList(),
  );
}

class CalidadRegistro {
  final int fotogramas;
  final int fotogramasValidos;
  final double porcentajeValidos;
  final String? vista;
  final double confianza;

  const CalidadRegistro({
    required this.fotogramas,
    required this.fotogramasValidos,
    required this.porcentajeValidos,
    required this.vista,
    required this.confianza,
  });

  factory CalidadRegistro.fromJson(Map<String, dynamic> j) => CalidadRegistro(
    fotogramas: (j['fotogramas'] as num? ?? 0).toInt(),
    fotogramasValidos: (j['fotogramas_validos'] as num? ?? 0).toInt(),
    porcentajeValidos: _d(j['porcentaje_validos']),
    vista: j['vista'] as String?,
    confianza: _d(j['confianza']),
  );
}

// Palabras que en la v1 indicaban una corrección dentro del feedback.
const _palabrasCorreccionV1 = [
  'mejore', 'alinee', 'flexione', 'extienda', 'nivele', //
  'acerque', 'aumente', 'distribuya', 'baje', 'cierre', 'controle',
];

class ResultadoAnalisis {
  /// JSON original: se guarda tal cual en el historial (ida y vuelta sin pérdida).
  final Map<String, dynamic> crudo;

  final String version;
  final String ejercicio;
  final String? nombreEjercicio;
  final int puntaje;
  final List<String> feedback;
  final Map<String, double> metricas;
  final List<Repeticion> repeticiones;
  final List<Hallazgo> hallazgos;
  final List<Acierto> aciertos;
  final SerieTemporal? serie;
  final CalidadRegistro? calidad;
  final double? duracionS;

  const ResultadoAnalisis._({
    required this.crudo,
    required this.version,
    required this.ejercicio,
    required this.nombreEjercicio,
    required this.puntaje,
    required this.feedback,
    required this.metricas,
    required this.repeticiones,
    required this.hallazgos,
    required this.aciertos,
    required this.serie,
    required this.calidad,
    required this.duracionS,
  });

  bool get esV2 => version.startsWith('2');

  int get numeroRepeticiones => repeticiones.isNotEmpty ? repeticiones.length : (metricas['repeticiones'] ?? 0).round();

  factory ResultadoAnalisis.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] ?? '1') as String;
    final feedback = ((json['feedback'] ?? const []) as List).map((e) => e.toString()).toList();
    var hallazgos = ((json['hallazgos'] ?? const []) as List)
        .map((h) => Hallazgo.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList();
    var aciertos = ((json['aciertos'] ?? const []) as List)
        .map((a) => Acierto.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();

    // Compatibilidad v1: se reconstruyen hallazgos y aciertos desde el texto.
    if (!version.startsWith('2') && hallazgos.isEmpty && aciertos.isEmpty) {
      for (final f in feedback) {
        final esCorreccion = _palabrasCorreccionV1.any(f.toLowerCase().contains);
        final partes = f.split(':');
        final titulo = partes.length > 1 ? partes.first.trim() : 'Observación';
        final mensaje = partes.length > 1 ? partes.sublist(1).join(':').trim() : f;
        if (esCorreccion) {
          hallazgos.add(
            Hallazgo(codigo: 'V1', severidad: Severidad.moderada, zona: 'general', titulo: titulo, mensaje: mensaje),
          );
        } else {
          aciertos.add(Acierto(codigo: 'V1', zona: 'general', mensaje: f));
        }
      }
    }

    return ResultadoAnalisis._(
      crudo: json,
      version: version,
      ejercicio: (json['ejercicio'] ?? '') as String,
      nombreEjercicio: json['nombre_ejercicio'] as String?,
      puntaje: (json['puntaje'] as num? ?? 0).toInt(),
      feedback: feedback,
      metricas: ((json['metricas'] ?? const {}) as Map).map((k, v) => MapEntry(k.toString(), _d(v))),
      repeticiones: ((json['repeticiones'] ?? const []) as List)
          .map((r) => Repeticion.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      hallazgos: hallazgos,
      aciertos: aciertos,
      serie: json['serie'] is Map ? SerieTemporal.fromJson(Map<String, dynamic>.from(json['serie'] as Map)) : null,
      calidad: json['calidad'] is Map
          ? CalidadRegistro.fromJson(Map<String, dynamic>.from(json['calidad'] as Map))
          : null,
      duracionS: (json['duracion_s'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => crudo;
}
