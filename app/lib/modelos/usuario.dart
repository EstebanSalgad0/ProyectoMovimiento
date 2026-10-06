enum RolUsuario {
  paciente('Paciente'),
  profesional('Profesional de la salud');

  final String etiqueta;
  const RolUsuario(this.etiqueta);

  static RolUsuario desde(String? valor) =>
      RolUsuario.values.firstWhere((r) => r.name == valor, orElse: () => RolUsuario.paciente);
}

enum Sexo {
  femenino('Femenino'),
  masculino('Masculino'),
  otro('Prefiero no decir');

  final String etiqueta;
  const Sexo(this.etiqueta);

  static Sexo? desde(String? v) => Sexo.values.where((s) => s.name == v).firstOrNull;
}

enum Lado {
  izquierdo('Izquierdo'),
  derecho('Derecho');

  final String etiqueta;
  const Lado(this.etiqueta);

  static Lado? desde(String? v) => Lado.values.where((s) => s.name == v).firstOrNull;
}

enum NivelActividad {
  sedentario('Sedentario', 'Casi no hago ejercicio'),
  ligero('Ligero', '1–2 veces por semana'),
  moderado('Moderado', '3–4 veces por semana'),
  alto('Alto', '5 o más veces por semana');

  final String etiqueta;
  final String detalle;
  const NivelActividad(this.etiqueta, this.detalle);

  static NivelActividad? desde(String? v) => NivelActividad.values.where((s) => s.name == v).firstOrNull;
}

enum Objetivo {
  rehabilitacion('Rehabilitación', 'Recuperarme de una lesión u operación'),
  fuerza('Fuerza', 'Ganar fuerza y resistencia'),
  movilidad('Movilidad', 'Moverme con más soltura'),
  prevencionCaidas('Equilibrio y autonomía', 'Prevenir caídas y mantener mi independencia'),
  bienestar('Bienestar', 'Mantenerme activo y saludable');

  final String etiqueta;
  final String detalle;
  const Objetivo(this.etiqueta, this.detalle);

  static Objetivo? desde(String? v) => Objetivo.values.where((s) => s.name == v).firstOrNull;
}

/// Zonas del cuerpo que el usuario puede marcar con molestias.
const zonasMolestia = <String, String>{
  'cuello': 'Cuello',
  'hombros': 'Hombros',
  'codos': 'Codos',
  'munecas': 'Muñecas',
  'espalda': 'Espalda',
  'cadera': 'Cadera',
  'rodillas': 'Rodillas',
  'tobillos': 'Tobillos',
};

/// Versión del texto de consentimiento aceptado al registrarse.
const versionConsentimiento = '2026-10';

class Usuario {
  final String usuario;
  final String nombre;
  final String email;
  final RolUsuario rol;
  final DateTime creadoEn;

  // Perfil
  final DateTime? fechaNacimiento;
  final Sexo? sexo;
  final int? estaturaCm;
  final double? pesoKg;
  final Lado? ladoDominante;
  final NivelActividad? nivelActividad;
  final Objetivo? objetivo;
  final List<String> molestias;
  final String notasSalud;
  final int colorAvatar;
  final int metaSemanal;
  final DateTime? consentimientoFecha;
  final String? consentimientoVersion;

  const Usuario({
    required this.usuario,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.creadoEn,
    this.fechaNacimiento,
    this.sexo,
    this.estaturaCm,
    this.pesoKg,
    this.ladoDominante,
    this.nivelActividad,
    this.objetivo,
    this.molestias = const [],
    this.notasSalud = '',
    this.colorAvatar = 0,
    this.metaSemanal = 3,
    this.consentimientoFecha,
    this.consentimientoVersion,
  });

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return usuario.isNotEmpty ? usuario[0].toUpperCase() : '?';
    final primera = partes.first[0];
    final segunda = partes.length > 1 ? partes[1][0] : '';
    return (primera + segunda).toUpperCase();
  }

  int? edadEn(DateTime fecha) {
    final n = fechaNacimiento;
    if (n == null) return null;
    var edad = fecha.year - n.year;
    if (fecha.month < n.month || (fecha.month == n.month && fecha.day < n.day)) edad--;
    return edad;
  }

  int? get edad => edadEn(DateTime.now());

  double? get imc {
    final e = estaturaCm, p = pesoKg;
    if (e == null || p == null || e <= 0) return null;
    final m = e / 100;
    return p / (m * m);
  }

  /// Campos del perfil completados (para mostrar el avance de la configuración).
  double get avancePerfil {
    final campos = [
      fechaNacimiento != null,
      sexo != null,
      estaturaCm != null,
      pesoKg != null,
      ladoDominante != null,
      nivelActividad != null,
      objetivo != null,
    ];
    return campos.where((c) => c).length / campos.length;
  }

  bool get perfilCompleto => fechaNacimiento != null && sexo != null && objetivo != null;

  Usuario copyWith({
    String? nombre,
    String? email,
    RolUsuario? rol,
    DateTime? fechaNacimiento,
    Sexo? sexo,
    int? estaturaCm,
    double? pesoKg,
    Lado? ladoDominante,
    NivelActividad? nivelActividad,
    Objetivo? objetivo,
    List<String>? molestias,
    String? notasSalud,
    int? colorAvatar,
    int? metaSemanal,
    DateTime? consentimientoFecha,
    String? consentimientoVersion,
    bool borrarEstatura = false,
    bool borrarPeso = false,
  }) => Usuario(
    usuario: usuario,
    nombre: nombre ?? this.nombre,
    email: email ?? this.email,
    rol: rol ?? this.rol,
    creadoEn: creadoEn,
    fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
    sexo: sexo ?? this.sexo,
    estaturaCm: borrarEstatura ? null : (estaturaCm ?? this.estaturaCm),
    pesoKg: borrarPeso ? null : (pesoKg ?? this.pesoKg),
    ladoDominante: ladoDominante ?? this.ladoDominante,
    nivelActividad: nivelActividad ?? this.nivelActividad,
    objetivo: objetivo ?? this.objetivo,
    molestias: molestias ?? this.molestias,
    notasSalud: notasSalud ?? this.notasSalud,
    colorAvatar: colorAvatar ?? this.colorAvatar,
    metaSemanal: metaSemanal ?? this.metaSemanal,
    consentimientoFecha: consentimientoFecha ?? this.consentimientoFecha,
    consentimientoVersion: consentimientoVersion ?? this.consentimientoVersion,
  );

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    usuario: j['usuario'] as String,
    nombre: (j['nombre'] ?? j['usuario']) as String,
    email: (j['email'] ?? '') as String,
    rol: RolUsuario.desde(j['rol'] as String?),
    creadoEn: DateTime.tryParse((j['creado_en'] ?? '') as String) ?? DateTime.now(),
    fechaNacimiento: DateTime.tryParse((j['fecha_nacimiento'] ?? '') as String),
    sexo: Sexo.desde(j['sexo'] as String?),
    estaturaCm: (j['estatura_cm'] as num?)?.toInt(),
    pesoKg: (j['peso_kg'] as num?)?.toDouble(),
    ladoDominante: Lado.desde(j['lado_dominante'] as String?),
    nivelActividad: NivelActividad.desde(j['nivel_actividad'] as String?),
    objetivo: Objetivo.desde(j['objetivo'] as String?),
    molestias: ((j['molestias'] ?? const []) as List).cast<String>(),
    notasSalud: (j['notas_salud'] ?? '') as String,
    colorAvatar: (j['color_avatar'] as num?)?.toInt() ?? 0,
    metaSemanal: (j['meta_semanal'] as num?)?.toInt() ?? 3,
    consentimientoFecha: DateTime.tryParse((j['consentimiento_fecha'] ?? '') as String),
    consentimientoVersion: j['consentimiento_version'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'usuario': usuario,
    'nombre': nombre,
    'email': email,
    'rol': rol.name,
    'creado_en': creadoEn.toIso8601String(),
    'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
    'sexo': sexo?.name,
    'estatura_cm': estaturaCm,
    'peso_kg': pesoKg,
    'lado_dominante': ladoDominante?.name,
    'nivel_actividad': nivelActividad?.name,
    'objetivo': objetivo?.name,
    'molestias': molestias,
    'notas_salud': notasSalud,
    'color_avatar': colorAvatar,
    'meta_semanal': metaSemanal,
    'consentimiento_fecha': consentimientoFecha?.toIso8601String(),
    'consentimiento_version': consentimientoVersion,
  };
}
