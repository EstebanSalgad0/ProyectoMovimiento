import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../modelos/resultado_analisis.dart';
import '../modelos/sesion.dart';
import '../modelos/usuario.dart';
import '../motor/especificacion.dart';
import '../servicios/auth_servicio.dart';
import '../servicios/historial_servicio.dart';
import '../servicios/servicio_ia.dart';
import '../servicios/voz_servicio.dart';

// ----------------------------------------------------------------- base
/// Se sobrescriben en main() (y en los tests) con instancias ya cargadas.
final preferenciasProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final especificacionProvider = Provider<Especificacion>((ref) => throw UnimplementedError());

final historialServicioProvider = Provider<HistorialServicio>((ref) => HistorialArchivo());
final repositorioAuthProvider = Provider<RepositorioAuth>((ref) => AuthLocal(ref.watch(preferenciasProvider)));
final vozProvider = Provider<VozServicio>((ref) => VozServicio());

// -------------------------------------------------------------- ajustes
class Ajustes {
  final ThemeMode tema;
  final String urlServidor;
  final bool voz;
  final bool camaraFrontal;
  final bool bienvenidaVista;

  const Ajustes({
    required this.tema,
    required this.urlServidor,
    required this.voz,
    required this.camaraFrontal,
    required this.bienvenidaVista,
  });

  Ajustes copyWith({ThemeMode? tema, String? urlServidor, bool? voz, bool? camaraFrontal, bool? bienvenidaVista}) =>
      Ajustes(
        tema: tema ?? this.tema,
        urlServidor: urlServidor ?? this.urlServidor,
        voz: voz ?? this.voz,
        camaraFrontal: camaraFrontal ?? this.camaraFrontal,
        bienvenidaVista: bienvenidaVista ?? this.bienvenidaVista,
      );
}

class AjustesNotifier extends Notifier<Ajustes> {
  static const _kTema = 'ajustes.tema';
  static const _kUrl = 'ajustes.url_servidor';
  static const _kVoz = 'ajustes.voz';
  static const _kCamara = 'ajustes.camara_frontal';
  static const _kBienvenida = 'ajustes.bienvenida_vista';

  SharedPreferences get _p => ref.read(preferenciasProvider);

  @override
  Ajustes build() {
    final p = ref.watch(preferenciasProvider);
    return Ajustes(
      tema: ThemeMode.values.firstWhere((m) => m.name == p.getString(_kTema), orElse: () => ThemeMode.system),
      urlServidor: p.getString(_kUrl) ?? AppConfig.urlServidorPorDefecto,
      voz: p.getBool(_kVoz) ?? true,
      camaraFrontal: p.getBool(_kCamara) ?? true,
      bienvenidaVista: p.getBool(_kBienvenida) ?? false,
    );
  }

  Future<void> cambiarTema(ThemeMode tema) async {
    state = state.copyWith(tema: tema);
    await _p.setString(_kTema, tema.name);
  }

  Future<void> cambiarUrlServidor(String url) async {
    var limpia = url.trim();
    if (limpia.isEmpty) limpia = AppConfig.urlServidorPorDefecto;
    if (!limpia.startsWith('http://') && !limpia.startsWith('https://')) limpia = 'http://$limpia';
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    state = state.copyWith(urlServidor: limpia);
    await _p.setString(_kUrl, limpia);
  }

  Future<void> cambiarVoz(bool activa) async {
    state = state.copyWith(voz: activa);
    await _p.setBool(_kVoz, activa);
  }

  Future<void> cambiarCamaraFrontal(bool frontal) async {
    state = state.copyWith(camaraFrontal: frontal);
    await _p.setBool(_kCamara, frontal);
  }

  Future<void> marcarBienvenidaVista() async {
    state = state.copyWith(bienvenidaVista: true);
    await _p.setBool(_kBienvenida, true);
  }
}

final ajustesProvider = NotifierProvider<AjustesNotifier, Ajustes>(AjustesNotifier.new);

final servicioIAProvider = Provider<ServicioIA>(
  (ref) => ServicioIA(ref.watch(ajustesProvider.select((a) => a.urlServidor))),
);

// ----------------------------------------------------------------- sesión
class AuthNotifier extends Notifier<Usuario?> {
  RepositorioAuth get _repo => ref.read(repositorioAuthProvider);

  @override
  Usuario? build() => ref.watch(repositorioAuthProvider).sesionActual();

  Future<void> iniciarSesion(String usuario, String contrasena) async {
    state = await _repo.iniciarSesion(usuario, contrasena);
  }

  Future<void> registrar({
    required String nombre,
    required String usuario,
    required String email,
    required String contrasena,
    required RolUsuario rol,
  }) async {
    state = await _repo.registrar(nombre: nombre, usuario: usuario, email: email, contrasena: contrasena, rol: rol);
  }

  Future<void> cerrarSesion() async {
    await _repo.cerrarSesion();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, Usuario?>(AuthNotifier.new);

// --------------------------------------------------------------- historial
class HistorialNotifier extends AsyncNotifier<List<Sesion>> {
  @override
  Future<List<Sesion>> build() async {
    final usuario = ref.watch(authProvider);
    if (usuario == null) return const [];
    return ref.watch(historialServicioProvider).obtener(usuario.usuario);
  }

  /// Guarda un resultado como sesión del usuario actual y la devuelve.
  Future<Sesion> registrar(ResultadoAnalisis resultado, OrigenSesion origen, {String? videoNombre}) async {
    final usuario = ref.read(authProvider)?.usuario ?? 'anonimo';
    final sesion = Sesion.nueva(usuario: usuario, origen: origen, resultado: resultado, videoNombre: videoNombre);
    try {
      await ref.read(historialServicioProvider).guardar(sesion);
    } catch (e) {
      debugPrint('No se pudo guardar la sesión: $e');
    }
    final actual = state.value ?? const <Sesion>[];
    state = AsyncData([sesion, ...actual]);
    return sesion;
  }

  Future<void> borrarTodo() async {
    final usuario = ref.read(authProvider);
    if (usuario == null) return;
    await ref.read(historialServicioProvider).borrarTodo(usuario.usuario);
    state = const AsyncData([]);
  }
}

final historialProvider = AsyncNotifierProvider<HistorialNotifier, List<Sesion>>(HistorialNotifier.new);

/// Estadísticas derivadas del historial para inicio y progreso.
class Resumen {
  final int sesiones;
  final int sesionesSemana;
  final double? promedio;
  final int? mejor;
  final int repeticiones;
  final int racha;
  final List<int> sesionesPorDia; // últimos 7 días, hoy al final

  const Resumen({
    required this.sesiones,
    required this.sesionesSemana,
    required this.promedio,
    required this.mejor,
    required this.repeticiones,
    required this.racha,
    required this.sesionesPorDia,
  });

  factory Resumen.desde(List<Sesion> sesiones, {DateTime? hoy}) {
    final ahora = hoy ?? DateTime.now();
    final dia0 = DateTime(ahora.year, ahora.month, ahora.day);
    int diasAtras(DateTime f) => dia0.difference(DateTime(f.year, f.month, f.day)).inDays;

    final porDia = List<int>.filled(7, 0);
    final dias = <int>{};
    for (final s in sesiones) {
      final d = diasAtras(s.fecha);
      if (d >= 0 && d < 7) porDia[6 - d]++;
      if (d >= 0) dias.add(d);
    }
    // Racha: días consecutivos con actividad terminando hoy (o ayer).
    var racha = 0;
    var inicio = dias.contains(0) ? 0 : (dias.contains(1) ? 1 : -1);
    if (inicio >= 0) {
      while (dias.contains(inicio)) {
        racha++;
        inicio++;
      }
    }
    final puntajes = sesiones.map((s) => s.puntaje).toList();
    return Resumen(
      sesiones: sesiones.length,
      sesionesSemana: porDia.reduce((a, b) => a + b),
      promedio: puntajes.isEmpty ? null : puntajes.reduce((a, b) => a + b) / puntajes.length,
      mejor: puntajes.isEmpty ? null : puntajes.reduce((a, b) => a > b ? a : b),
      repeticiones: sesiones.fold(0, (t, s) => t + s.resultado.numeroRepeticiones),
      racha: racha,
      sesionesPorDia: porDia,
    );
  }
}
