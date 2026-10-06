import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/usuario.dart';

class ErrorAuth implements Exception {
  final String mensaje;
  const ErrorAuth(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Contrato de autenticación. Hoy se usa [AuthLocal] (modo demo, sin servidor);
/// para el piloto se reemplaza por una implementación contra el backend (JWT)
/// sin tocar las pantallas.
abstract class RepositorioAuth {
  Usuario? sesionActual();
  Future<Usuario> iniciarSesion(String usuario, String contrasena);
  Future<Usuario> registrar({
    required String nombre,
    required String usuario,
    required String email,
    required String contrasena,
    required RolUsuario rol,
  });
  Future<void> cerrarSesion();
}

/// Autenticación local para el prototipo. Las contraseñas se guardan con sal y
/// SHA-256 (nunca en texto plano), pero esto NO reemplaza un backend seguro.
class AuthLocal implements RepositorioAuth {
  static const _claveUsuarios = 'auth.usuarios';
  static const _claveSesion = 'auth.sesion';

  final SharedPreferences _prefs;

  AuthLocal(this._prefs) {
    _sembrarUsuariosDemo();
  }

  static String _hash(String sal, String contrasena) => sha256.convert(utf8.encode('$sal:$contrasena')).toString();

  static String _nuevaSal() {
    final r = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => r.nextInt(256)));
  }

  static String normalizar(String usuario) => usuario.trim().toLowerCase();

  Map<String, dynamic> _usuarios() {
    final crudo = _prefs.getString(_claveUsuarios);
    if (crudo == null || crudo.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(crudo) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _guardarUsuarios(Map<String, dynamic> usuarios) =>
      _prefs.setString(_claveUsuarios, jsonEncode(usuarios));

  void _sembrarUsuariosDemo() {
    final usuarios = _usuarios();
    var cambio = false;
    void sembrar(String usuario, String nombre, RolUsuario rol) {
      if (usuarios.containsKey(usuario)) return;
      final sal = _nuevaSal();
      usuarios[usuario] = {
        ...Usuario(
          usuario: usuario,
          nombre: nombre,
          email: '$usuario@movimiento.demo',
          rol: rol,
          creadoEn: DateTime.now(),
        ).toJson(),
        'sal': sal,
        'hash': _hash(sal, '1234'),
      };
      cambio = true;
    }

    sembrar('usuario.prueba', 'Usuario Prueba', RolUsuario.paciente);
    sembrar('admin', 'Administrador', RolUsuario.profesional);
    if (cambio) _guardarUsuarios(usuarios);
  }

  @override
  Usuario? sesionActual() {
    final actual = _prefs.getString(_claveSesion);
    if (actual == null) return null;
    final datos = _usuarios()[actual];
    return datos == null ? null : Usuario.fromJson(Map<String, dynamic>.from(datos as Map));
  }

  @override
  Future<Usuario> iniciarSesion(String usuario, String contrasena) async {
    final clave = normalizar(usuario);
    final datos = _usuarios()[clave];
    if (datos == null) throw const ErrorAuth('Usuario o contraseña incorrectos');
    final mapa = Map<String, dynamic>.from(datos as Map);
    if (_hash(mapa['sal'] as String, contrasena) != mapa['hash']) {
      throw const ErrorAuth('Usuario o contraseña incorrectos');
    }
    await _prefs.setString(_claveSesion, clave);
    return Usuario.fromJson(mapa);
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String usuario,
    required String email,
    required String contrasena,
    required RolUsuario rol,
  }) async {
    final clave = normalizar(usuario);
    final usuarios = _usuarios();
    if (usuarios.containsKey(clave)) throw const ErrorAuth('Ese nombre de usuario ya existe');
    final nuevo = Usuario(
      usuario: clave,
      nombre: nombre.trim(),
      email: email.trim(),
      rol: rol,
      creadoEn: DateTime.now(),
    );
    final sal = _nuevaSal();
    usuarios[clave] = {...nuevo.toJson(), 'sal': sal, 'hash': _hash(sal, contrasena)};
    await _guardarUsuarios(usuarios);
    await _prefs.setString(_claveSesion, clave);
    return nuevo;
  }

  @override
  Future<void> cerrarSesion() => _prefs.remove(_claveSesion);
}
