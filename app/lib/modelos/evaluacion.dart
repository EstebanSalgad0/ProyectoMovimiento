import 'dart:math';

import 'usuario.dart';

enum TipoEvaluacion {
  sentarsePararse30s('Sentarse y pararse 30 s'),
  rangoArticular('Rango articular');

  final String etiqueta;
  const TipoEvaluacion(this.etiqueta);

  static TipoEvaluacion desde(String? v) =>
      TipoEvaluacion.values.firstWhere((t) => t.name == v, orElse: () => TipoEvaluacion.rangoArticular);
}

/// Prueba de sentarse y pararse de 30 segundos (CDC STEADI).
///
/// Puntajes "bajo el promedio" por edad y sexo, que indican riesgo de caídas.
/// Fuente: CDC STEADI, "Assessment: 30-Second Chair Stand" (60–94 años).
class ReferenciaSts30 {
  static const _tabla = <(int, int, int, int)>[
    // (edad mín, edad máx, hombres <, mujeres <)
    (60, 64, 14, 12),
    (65, 69, 12, 11),
    (70, 74, 12, 10),
    (75, 79, 11, 10),
    (80, 84, 10, 9),
    (85, 89, 8, 8),
    (90, 94, 7, 4),
  ];

  static const fuente = 'CDC STEADI · 30-Second Chair Stand';

  /// Repeticiones mínimas para no quedar "bajo el promedio", o null si no
  /// hay referencia para esa edad o sexo.
  static int? umbral(int? edad, Sexo? sexo) {
    if (edad == null || sexo == null || sexo == Sexo.otro) return null;
    for (final (desde, hasta, hombres, mujeres) in _tabla) {
      if (edad >= desde && edad <= hasta) return sexo == Sexo.masculino ? hombres : mujeres;
    }
    return null;
  }

  static ClasificacionSts30 clasificar(int repeticiones, int? edad, Sexo? sexo) {
    final u = umbral(edad, sexo);
    if (u == null) return ClasificacionSts30.sinReferencia;
    return repeticiones < u ? ClasificacionSts30.bajoPromedio : ClasificacionSts30.enRango;
  }
}

enum ClasificacionSts30 {
  bajoPromedio(
    'Bajo el promedio',
    'Por debajo de lo esperado para tu edad: puede indicar riesgo de caídas. Consulta con un profesional.',
  ),
  enRango('En rango o sobre el promedio', 'Tu resultado está dentro de lo esperado para tu edad.'),
  sinReferencia(
    'Sin referencia',
    'Hay valores de referencia para personas de 60 a 94 años con sexo registrado en el perfil.',
  );

  final String etiqueta;
  final String detalle;
  const ClasificacionSts30(this.etiqueta, this.detalle);

  static ClasificacionSts30 desde(String? v) =>
      ClasificacionSts30.values.firstWhere((c) => c.name == v, orElse: () => ClasificacionSts30.sinReferencia);
}

/// Articulaciones que se pueden medir con la cámara (goniómetro).
enum Articulacion {
  hombro(
    'Hombro',
    'Elevación del brazo',
    180,
    'Grábate de costado para flexión o de frente para abducción. Sube el brazo estirado lo más alto que puedas.',
  ),
  codo('Codo', 'Flexión del codo', 150, 'Grábate de costado. Dobla el codo llevando la mano hacia el hombro.'),
  cadera('Cadera', 'Flexión de cadera', 120, 'Grábate de costado, de pie y con apoyo. Sube la rodilla hacia el pecho.'),
  rodilla(
    'Rodilla',
    'Flexión de rodilla',
    135,
    'Grábate de costado, de pie y con apoyo. Lleva el talón hacia el glúteo.',
  );

  final String etiqueta;
  final String movimiento;

  /// Rango de referencia habitual en adultos (grados).
  final int referencia;
  final String instruccion;
  const Articulacion(this.etiqueta, this.movimiento, this.referencia, this.instruccion);

  static Articulacion desde(String? v) =>
      Articulacion.values.firstWhere((a) => a.name == v, orElse: () => Articulacion.hombro);

  bool get femenina => this == cadera || this == rodilla;

  /// "Rodilla derecha", "Hombro izquierdo"…
  String conLado(Lado? lado) {
    if (lado == null) return etiqueta;
    final l = switch (lado) {
      Lado.izquierdo => femenina ? 'izquierda' : 'izquierdo',
      Lado.derecho => femenina ? 'derecha' : 'derecho',
    };
    return '$etiqueta $l';
  }

  /// "la rodilla derecha", "el hombro izquierdo".
  String conArticulo(Lado? lado) => '${femenina ? 'la' : 'el'} ${conLado(lado).toLowerCase()}';
}

class EvaluacionFuncional {
  final String id;
  final String usuario;
  final DateTime fecha;
  final TipoEvaluacion tipo;

  // Prueba de 30 s
  final int? repeticiones;
  final int? edad;
  final Sexo? sexo;
  final int? umbralReferencia;
  final ClasificacionSts30? clasificacion;

  /// Sesión con el detalle de técnica de la prueba.
  final String? sesionId;

  // Rango articular
  final Articulacion? articulacion;
  final Lado? lado;
  final double? maximo;

  final String nota;

  const EvaluacionFuncional({
    required this.id,
    required this.usuario,
    required this.fecha,
    required this.tipo,
    this.repeticiones,
    this.edad,
    this.sexo,
    this.umbralReferencia,
    this.clasificacion,
    this.sesionId,
    this.articulacion,
    this.lado,
    this.maximo,
    this.nota = '',
  });

  static String nuevoId() =>
      'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  factory EvaluacionFuncional.sts30({
    required String usuario,
    required int repeticiones,
    int? edad,
    Sexo? sexo,
    String? sesionId,
  }) => EvaluacionFuncional(
    id: nuevoId(),
    usuario: usuario,
    fecha: DateTime.now(),
    tipo: TipoEvaluacion.sentarsePararse30s,
    repeticiones: repeticiones,
    edad: edad,
    sexo: sexo,
    umbralReferencia: ReferenciaSts30.umbral(edad, sexo),
    clasificacion: ReferenciaSts30.clasificar(repeticiones, edad, sexo),
    sesionId: sesionId,
  );

  factory EvaluacionFuncional.rango({
    required String usuario,
    required Articulacion articulacion,
    required Lado lado,
    required double maximo,
  }) => EvaluacionFuncional(
    id: nuevoId(),
    usuario: usuario,
    fecha: DateTime.now(),
    tipo: TipoEvaluacion.rangoArticular,
    articulacion: articulacion,
    lado: lado,
    maximo: maximo,
  );

  /// Porcentaje del rango de referencia alcanzado (0–1+).
  double? get fraccionReferencia {
    final a = articulacion, m = maximo;
    if (a == null || m == null) return null;
    return m / a.referencia;
  }

  factory EvaluacionFuncional.fromJson(Map<String, dynamic> j) => EvaluacionFuncional(
    id: j['id'] as String,
    usuario: (j['usuario'] ?? '') as String,
    fecha: DateTime.tryParse((j['fecha'] ?? '') as String) ?? DateTime.now(),
    tipo: TipoEvaluacion.desde(j['tipo'] as String?),
    repeticiones: (j['repeticiones'] as num?)?.toInt(),
    edad: (j['edad'] as num?)?.toInt(),
    sexo: Sexo.desde(j['sexo'] as String?),
    umbralReferencia: (j['umbral_referencia'] as num?)?.toInt(),
    clasificacion: j['clasificacion'] == null ? null : ClasificacionSts30.desde(j['clasificacion'] as String?),
    sesionId: j['sesion_id'] as String?,
    articulacion: j['articulacion'] == null ? null : Articulacion.desde(j['articulacion'] as String?),
    lado: Lado.desde(j['lado'] as String?),
    maximo: (j['maximo'] as num?)?.toDouble(),
    nota: (j['nota'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': usuario,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo.name,
    'repeticiones': repeticiones,
    'edad': edad,
    'sexo': sexo?.name,
    'umbral_referencia': umbralReferencia,
    'clasificacion': clasificacion?.name,
    'sesion_id': sesionId,
    'articulacion': articulacion?.name,
    'lado': lado?.name,
    'maximo': maximo,
    'nota': nota,
  };
}
