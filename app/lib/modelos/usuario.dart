enum RolUsuario {
  paciente('Paciente'),
  profesional('Profesional de la salud');

  final String etiqueta;
  const RolUsuario(this.etiqueta);

  static RolUsuario desde(String? valor) =>
      RolUsuario.values.firstWhere((r) => r.name == valor, orElse: () => RolUsuario.paciente);
}

class Usuario {
  final String usuario;
  final String nombre;
  final String email;
  final RolUsuario rol;
  final DateTime creadoEn;

  const Usuario({
    required this.usuario,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.creadoEn,
  });

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return usuario.isNotEmpty ? usuario[0].toUpperCase() : '?';
    final primera = partes.first[0];
    final segunda = partes.length > 1 ? partes[1][0] : '';
    return (primera + segunda).toUpperCase();
  }

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    usuario: j['usuario'] as String,
    nombre: (j['nombre'] ?? j['usuario']) as String,
    email: (j['email'] ?? '') as String,
    rol: RolUsuario.desde(j['rol'] as String?),
    creadoEn: DateTime.tryParse((j['creado_en'] ?? '') as String) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'usuario': usuario,
    'nombre': nombre,
    'email': email,
    'rol': rol.name,
    'creado_en': creadoEn.toIso8601String(),
  };
}
