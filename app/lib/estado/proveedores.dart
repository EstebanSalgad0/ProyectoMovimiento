import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../modelos/esqueleto.dart';
import '../modelos/evaluacion.dart';
import '../modelos/logros.dart';
import '../modelos/resultado_analisis.dart';
import '../modelos/rutina.dart';
import '../modelos/sesion.dart';
import '../modelos/usuario.dart';
import '../motor/especificacion.dart';
import '../servicios/adjuntos_servicio.dart';
import '../servicios/auth_servicio.dart';
import '../servicios/evaluaciones_servicio.dart';
import '../servicios/historial_servicio.dart';
import '../servicios/servicio_ia.dart';
import '../servicios/voz_servicio.dart';

// ----------------------------------------------------------------- base
/// Se sobrescriben en main() (y en los tests) con instancias ya cargadas.
final preferenciasProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final especificacionProvider = Provider<Especificacion>((ref) => throw UnimplementedError());

final historialServicioProvider = Provider<HistorialServicio>((ref) => HistorialArchivo());
final evaluacionesServicioProvider = Provider<EvaluacionesServicio>((ref) => EvaluacionesArchivo());
final adjuntosServicioProvider = Provider<AdjuntosServicio>((ref) => AdjuntosArchivo());
final repositorioAuthProvider = Provider<RepositorioAuth>((ref) => AuthLocal(ref.watch(preferenciasProvider)));
final vozProvider = Provider<VozServicio>((ref) => VozServicio());

// -------------------------------------------------------------- ajustes
class Ajustes {
  final ThemeMode tema;
  final String urlServidor;
  final bool voz;
  final bool camaraFrontal;
  final bool bienvenidaVista;
  final int cuentaRegresiva;
  final bool mostrarEsqueleto;
  final double velocidadVoz;
  final bool vibracion;

  /// Guardar una copia de los videos analizados para revisarlos después.
  final bool guardarVideos;

  const Ajustes({
    required this.tema,
    required this.urlServidor,
    required this.voz,
    required this.camaraFrontal,
    required this.bienvenidaVista,
    this.cuentaRegresiva = AppConfig.cuentaRegresiva,
    this.mostrarEsqueleto = true,
    this.velocidadVoz = 0.5,
    this.vibracion = true,
    this.guardarVideos = true,
  });

  Ajustes copyWith({
    ThemeMode? tema,
    String? urlServidor,
    bool? voz,
    bool? camaraFrontal,
    bool? bienvenidaVista,
    int? cuentaRegresiva,
    bool? mostrarEsqueleto,
    double? velocidadVoz,
    bool? vibracion,
    bool? guardarVideos,
  }) => Ajustes(
    tema: tema ?? this.tema,
    urlServidor: urlServidor ?? this.urlServidor,
    voz: voz ?? this.voz,
    camaraFrontal: camaraFrontal ?? this.camaraFrontal,
    bienvenidaVista: bienvenidaVista ?? this.bienvenidaVista,
    cuentaRegresiva: cuentaRegresiva ?? this.cuentaRegresiva,
    mostrarEsqueleto: mostrarEsqueleto ?? this.mostrarEsqueleto,
    velocidadVoz: velocidadVoz ?? this.velocidadVoz,
    vibracion: vibracion ?? this.vibracion,
    guardarVideos: guardarVideos ?? this.guardarVideos,
  );
}

class AjustesNotifier extends Notifier<Ajustes> {
  static const _kTema = 'ajustes.tema';
  static const _kUrl = 'ajustes.url_servidor';
  static const _kVoz = 'ajustes.voz';
  static const _kCamara = 'ajustes.camara_frontal';
  static const _kBienvenida = 'ajustes.bienvenida_vista';
  static const _kCuenta = 'ajustes.cuenta_regresiva';
  static const _kEsqueleto = 'ajustes.mostrar_esqueleto';
  static const _kVelocidad = 'ajustes.velocidad_voz';
  static const _kVibracion = 'ajustes.vibracion';
  static const _kGuardarVideos = 'ajustes.guardar_videos';

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
      cuentaRegresiva: p.getInt(_kCuenta) ?? AppConfig.cuentaRegresiva,
      mostrarEsqueleto: p.getBool(_kEsqueleto) ?? true,
      velocidadVoz: p.getDouble(_kVelocidad) ?? 0.5,
      vibracion: p.getBool(_kVibracion) ?? true,
      guardarVideos: p.getBool(_kGuardarVideos) ?? true,
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

  Future<void> cambiarCuentaRegresiva(int segundos) async {
    state = state.copyWith(cuentaRegresiva: segundos);
    await _p.setInt(_kCuenta, segundos);
  }

  Future<void> cambiarMostrarEsqueleto(bool mostrar) async {
    state = state.copyWith(mostrarEsqueleto: mostrar);
    await _p.setBool(_kEsqueleto, mostrar);
  }

  Future<void> cambiarVelocidadVoz(double velocidad) async {
    state = state.copyWith(velocidadVoz: velocidad);
    await _p.setDouble(_kVelocidad, velocidad);
    await ref.read(vozProvider).cambiarVelocidad(velocidad);
  }

  Future<void> cambiarVibracion(bool activa) async {
    state = state.copyWith(vibracion: activa);
    await _p.setBool(_kVibracion, activa);
  }

  Future<void> cambiarGuardarVideos(bool guardar) async {
    state = state.copyWith(guardarVideos: guardar);
    await _p.setBool(_kGuardarVideos, guardar);
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
    final nuevo = await _repo.registrar(
      nombre: nombre,
      usuario: usuario,
      email: email,
      contrasena: contrasena,
      rol: rol,
    );
    // Se pide completar el perfil antes de entrar al inicio.
    await ref.read(preferenciasProvider).setBool(ConfiguracionInicialNotifier.clave(nuevo.usuario), true);
    state = nuevo;
  }

  Future<void> actualizarPerfil(Usuario usuario) async {
    state = await _repo.actualizarPerfil(usuario);
  }

  Future<void> cambiarContrasena({required String actual, required String nueva}) =>
      _repo.cambiarContrasena(actual: actual, nueva: nueva);

  /// Elimina la cuenta y todos sus datos guardados en el teléfono.
  Future<void> eliminarCuenta(String contrasena) async {
    final usuario = state;
    if (usuario == null) return;
    await _repo.eliminarCuenta(contrasena);
    final sesiones = await ref.read(historialServicioProvider).obtener(usuario.usuario);
    for (final s in sesiones) {
      await ref.read(adjuntosServicioProvider).eliminar(s.id, videoRuta: s.videoRuta);
    }
    await ref.read(historialServicioProvider).borrarTodo(usuario.usuario);
    await ref.read(evaluacionesServicioProvider).borrarTodo(usuario.usuario);
    final p = ref.read(preferenciasProvider);
    for (final clave in p.getKeys().where((k) => k.endsWith('.${usuario.usuario}')).toList()) {
      await p.remove(clave);
    }
    state = null;
  }

  Future<void> cerrarSesion() async {
    await _repo.cerrarSesion();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, Usuario?>(AuthNotifier.new);

/// Si el usuario recién registrado aún debe completar la configuración inicial.
class ConfiguracionInicialNotifier extends Notifier<bool> {
  static String clave(String usuario) => 'perfil.pendiente.$usuario';

  @override
  bool build() {
    final u = ref.watch(authProvider);
    if (u == null) return false;
    return ref.watch(preferenciasProvider).getBool(clave(u.usuario)) ?? false;
  }

  Future<void> completar() async {
    final u = ref.read(authProvider);
    if (u != null) await ref.read(preferenciasProvider).remove(clave(u.usuario));
    state = false;
  }
}

final configuracionInicialProvider = NotifierProvider<ConfiguracionInicialNotifier, bool>(
  ConfiguracionInicialNotifier.new,
);

// --------------------------------------------------------------- historial
class HistorialNotifier extends AsyncNotifier<List<Sesion>> {
  @override
  Future<List<Sesion>> build() async {
    final usuario = ref.watch(authProvider);
    if (usuario == null) return const [];
    return ref.watch(historialServicioProvider).obtener(usuario.usuario);
  }

  /// Guarda un resultado como sesión del usuario actual y la devuelve. El
  /// esqueleto (del servidor o grabado en vivo) y el video se guardan aparte.
  Future<Sesion> registrar(
    ResultadoAnalisis resultado,
    OrigenSesion origen, {
    String? videoNombre,
    ContextoRutina? rutina,
    EsqueletoGrabado? esqueleto,
    File? video,
  }) async {
    final usuario = ref.read(authProvider)?.usuario ?? 'anonimo';
    final adjuntos = ref.read(adjuntosServicioProvider);
    var esq = esqueleto;
    final crudo = resultado.esqueletoCrudo;
    if (esq == null && crudo != null) {
      try {
        esq = EsqueletoGrabado.fromJson(crudo);
      } catch (_) {}
    }
    var sesion = Sesion.nueva(
      usuario: usuario,
      origen: origen,
      resultado: resultado.sinEsqueleto(),
      videoNombre: videoNombre,
      rutina: rutina,
    );
    // Un adjunto que falla (sin espacio, archivo movido) no impide guardar la sesión.
    if (esq != null && !esq.vacio) {
      try {
        await adjuntos.guardarEsqueleto(sesion.id, esq);
        sesion = sesion.copyWith(tieneEsqueleto: true);
      } catch (e) {
        debugPrint('No se pudo guardar el esqueleto: $e');
      }
    }
    if (video != null) {
      try {
        final ruta = await adjuntos.guardarVideo(sesion.id, video);
        if (ruta != null) sesion = sesion.copyWith(videoRuta: ruta);
      } catch (e) {
        debugPrint('No se pudo copiar el video: $e');
      }
    }
    try {
      await ref.read(historialServicioProvider).guardar(sesion);
    } catch (e) {
      debugPrint('No se pudo guardar la sesión: $e');
    }
    final actual = state.value ?? const <Sesion>[];
    state = AsyncData([sesion, ...actual]);
    return sesion;
  }

  Future<void> actualizar(Sesion sesion) async {
    await ref.read(historialServicioProvider).guardar(sesion);
    final actual = state.value ?? const <Sesion>[];
    state = AsyncData([for (final s in actual) s.id == sesion.id ? sesion : s]);
  }

  Future<void> guardarSensaciones(Iterable<String> ids, Sensaciones sensaciones) async {
    final actual = state.value ?? const <Sesion>[];
    for (final s in actual.where((s) => ids.contains(s.id))) {
      await actualizar(s.copyWith(sensaciones: sensaciones));
    }
  }

  Future<void> eliminar(Sesion sesion) async {
    await ref.read(historialServicioProvider).eliminar(sesion.usuario, sesion.id);
    await ref.read(adjuntosServicioProvider).eliminar(sesion.id, videoRuta: sesion.videoRuta);
    final actual = state.value ?? const <Sesion>[];
    state = AsyncData([
      for (final s in actual)
        if (s.id != sesion.id) s,
    ]);
  }

  /// Quita la sesión del historial pero conserva su grabación, para poder
  /// deshacer. Si no se deshace, se llama a [borrarAdjuntos].
  Future<void> ocultar(Sesion sesion) async {
    await ref.read(historialServicioProvider).eliminar(sesion.usuario, sesion.id);
    state = AsyncData([for (final s in state.value ?? const <Sesion>[]) if (s.id != sesion.id) s]);
  }

  Future<void> borrarAdjuntos(Sesion sesion) =>
      ref.read(adjuntosServicioProvider).eliminar(sesion.id, videoRuta: sesion.videoRuta);

  /// Vuelve a insertar una sesión eliminada (deshacer).
  Future<void> restaurar(Sesion sesion) async {
    await ref.read(historialServicioProvider).guardar(sesion);
    final actual = [...?state.value, sesion]..sort((a, b) => b.fecha.compareTo(a.fecha));
    state = AsyncData(actual);
  }

  Future<void> borrarVideos() async {
    await ref.read(adjuntosServicioProvider).borrarVideos();
    final actual = state.value ?? const <Sesion>[];
    for (final s in actual.where((s) => s.videoRuta != null)) {
      await actualizar(s.copyWith(borrarVideo: true));
    }
  }

  Future<void> borrarTodo() async {
    final usuario = ref.read(authProvider);
    if (usuario == null) return;
    for (final s in state.value ?? const <Sesion>[]) {
      await ref.read(adjuntosServicioProvider).eliminar(s.id, videoRuta: s.videoRuta);
    }
    await ref.read(historialServicioProvider).borrarTodo(usuario.usuario);
    state = const AsyncData([]);
  }
}

final historialProvider = AsyncNotifierProvider<HistorialNotifier, List<Sesion>>(HistorialNotifier.new);

// ------------------------------------------------------------ evaluaciones
class EvaluacionesNotifier extends AsyncNotifier<List<EvaluacionFuncional>> {
  @override
  Future<List<EvaluacionFuncional>> build() async {
    final usuario = ref.watch(authProvider);
    if (usuario == null) return const [];
    return ref.watch(evaluacionesServicioProvider).obtener(usuario.usuario);
  }

  Future<void> agregar(EvaluacionFuncional e) async {
    await ref.read(evaluacionesServicioProvider).guardar(e);
    state = AsyncData([e, ...?state.value]);
  }

  Future<void> eliminar(EvaluacionFuncional e) async {
    await ref.read(evaluacionesServicioProvider).eliminar(e.usuario, e.id);
    state = AsyncData([
      for (final x in state.value ?? const <EvaluacionFuncional>[])
        if (x.id != e.id) x,
    ]);
  }

  Future<void> borrarTodo() async {
    final usuario = ref.read(authProvider);
    if (usuario == null) return;
    await ref.read(evaluacionesServicioProvider).borrarTodo(usuario.usuario);
    state = const AsyncData([]);
  }
}

final evaluacionesProvider = AsyncNotifierProvider<EvaluacionesNotifier, List<EvaluacionFuncional>>(
  EvaluacionesNotifier.new,
);

// ---------------------------------------------------------------- rutinas
/// Rutinas creadas por el usuario (las predefinidas están en el código).
class RutinasNotifier extends Notifier<List<Rutina>> {
  String? get _clave {
    final u = ref.read(authProvider);
    return u == null ? null : 'rutinas.${u.usuario}';
  }

  @override
  List<Rutina> build() {
    final u = ref.watch(authProvider);
    if (u == null) return const [];
    final crudo = ref.watch(preferenciasProvider).getString('rutinas.${u.usuario}');
    if (crudo == null) return const [];
    try {
      return [for (final r in jsonDecode(crudo) as List) Rutina.fromJson(Map<String, dynamic>.from(r as Map))];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistir() async {
    final clave = _clave;
    if (clave == null) return;
    await ref.read(preferenciasProvider).setString(clave, jsonEncode([for (final r in state) r.toJson()]));
  }

  Future<void> guardar(Rutina rutina) async {
    final existe = state.any((r) => r.id == rutina.id);
    state = existe ? [for (final r in state) r.id == rutina.id ? rutina : r] : [...state, rutina];
    await _persistir();
  }

  Future<void> eliminar(String id) async {
    state = [
      for (final r in state)
        if (r.id != id) r,
    ];
    await _persistir();
  }
}

final rutinasPropiasProvider = NotifierProvider<RutinasNotifier, List<Rutina>>(RutinasNotifier.new);

final todasLasRutinasProvider = Provider<List<Rutina>>(
  (ref) => [...rutinasPredefinidas, ...ref.watch(rutinasPropiasProvider)],
);

Rutina? buscarRutina(List<Rutina> rutinas, String id) {
  for (final r in rutinas) {
    if (r.id == id) return r;
  }
  return null;
}

// ------------------------------------------------------ objetivos personales
class ObjetivosNotifier extends Notifier<AjustesEjercicios> {
  @override
  AjustesEjercicios build() {
    final u = ref.watch(authProvider);
    if (u == null) return const {};
    final crudo = ref.watch(preferenciasProvider).getString('objetivos.${u.usuario}');
    if (crudo == null) return const {};
    try {
      return ajustesDesdeJson(Map<String, dynamic>.from(jsonDecode(crudo) as Map));
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persistir() async {
    final u = ref.read(authProvider);
    if (u == null) return;
    await ref.read(preferenciasProvider).setString('objetivos.${u.usuario}', jsonEncode(ajustesAJson(state)));
  }

  /// Cambia (o con null, restablece) el ajuste de una verificación.
  Future<void> ajustar(String ejercicioId, String codigo, AjusteVerificacion? ajuste) async {
    final copia = {for (final e in state.entries) e.key: Map<String, AjusteVerificacion>.from(e.value)};
    final del = copia.putIfAbsent(ejercicioId, () => {});
    if (ajuste == null) {
      del.remove(codigo);
    } else {
      del[codigo] = ajuste;
    }
    state = copia;
    await _persistir();
  }

  Future<void> restablecer(String ejercicioId) async {
    state = {
      for (final e in state.entries)
        if (e.key != ejercicioId) e.key: e.value,
    };
    await _persistir();
  }
}

final objetivosProvider = NotifierProvider<ObjetivosNotifier, AjustesEjercicios>(ObjetivosNotifier.new);

/// Especificación con los objetivos del usuario aplicados (motor en vivo).
final especificacionPersonalizadaProvider = Provider<Especificacion>(
  (ref) => ref.watch(especificacionProvider).conAjustes(ref.watch(objetivosProvider)),
);

// ------------------------------------------------------------------ logros
final logrosProvider = Provider<List<Logro>>((ref) {
  return calcularLogros(
    sesiones: ref.watch(historialProvider).value ?? const [],
    evaluaciones: ref.watch(evaluacionesProvider).value ?? const [],
    metaSemanal: ref.watch(authProvider)?.metaSemanal ?? 3,
  );
});

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
    for (final s in sesiones) {
      final d = diasAtras(s.fecha);
      if (d >= 0 && d < 7) porDia[6 - d]++;
    }
    final puntajes = sesiones.map((s) => s.puntaje).toList();
    return Resumen(
      sesiones: sesiones.length,
      sesionesSemana: porDia.reduce((a, b) => a + b),
      promedio: puntajes.isEmpty ? null : puntajes.reduce((a, b) => a + b) / puntajes.length,
      mejor: puntajes.isEmpty ? null : puntajes.reduce((a, b) => a > b ? a : b),
      repeticiones: sesiones.fold(0, (t, s) => t + s.resultado.numeroRepeticiones),
      racha: rachaDias(sesiones.map((s) => s.fecha), hoy: ahora),
      sesionesPorDia: porDia,
    );
  }
}
