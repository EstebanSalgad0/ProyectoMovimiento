import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../modelos/sesion.dart';

/// Contrato del historial de sesiones. Hoy se guarda en el teléfono; en la fase
/// de backend se agrega sincronización con el servidor (ver plan).
abstract class HistorialServicio {
  Future<List<Sesion>> obtener(String usuario);

  /// Crea o reemplaza (por id) una sesión.
  Future<void> guardar(Sesion sesion);
  Future<void> eliminar(String usuario, String id);
  Future<void> borrarTodo(String usuario);
}

/// Historial en un archivo JSON por usuario (mismo archivo que usaba la app v1,
/// por lo que las sesiones anteriores se conservan).
class HistorialArchivo implements HistorialServicio {
  static String normalizarUsuario(String usuario) {
    final limpio = usuario.trim().toLowerCase();
    return limpio.isEmpty ? 'anonimo' : limpio.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
  }

  Future<File> _archivo(String usuario) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}historial_${normalizarUsuario(usuario)}.json');
  }

  @override
  Future<List<Sesion>> obtener(String usuario) async {
    try {
      final archivo = await _archivo(usuario);
      if (!await archivo.exists()) return [];
      final contenido = await archivo.readAsString();
      if (contenido.trim().isEmpty) return [];
      final datos = jsonDecode(contenido);
      if (datos is! List) return [];
      final sesiones = <Sesion>[];
      for (final item in datos.whereType<Map>()) {
        try {
          sesiones.add(Sesion.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Una sesión dañada no debe impedir leer el resto.
        }
      }
      sesiones.sort((a, b) => b.fecha.compareTo(a.fecha));
      return sesiones;
    } catch (_) {
      return [];
    }
  }

  Future<void> _escribir(String usuario, List<Sesion> sesiones) async {
    final archivo = await _archivo(usuario);
    // Escritura atómica: primero a un temporal y luego se reemplaza.
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(jsonEncode([for (final s in sesiones) s.toJson()]), flush: true);
    await temporal.rename(archivo.path);
  }

  @override
  Future<void> guardar(Sesion sesion) async {
    final actuales = await obtener(sesion.usuario);
    await _escribir(sesion.usuario, [sesion, ...actuales.where((s) => s.id != sesion.id)]);
  }

  @override
  Future<void> eliminar(String usuario, String id) async {
    final actuales = await obtener(usuario);
    await _escribir(usuario, actuales.where((s) => s.id != id).toList());
  }

  @override
  Future<void> borrarTodo(String usuario) async {
    final archivo = await _archivo(usuario);
    if (await archivo.exists()) await archivo.delete();
  }
}

/// Implementación en memoria (tests y modo demostración).
class HistorialMemoria implements HistorialServicio {
  final Map<String, List<Sesion>> _datos = {};

  HistorialMemoria([List<Sesion> iniciales = const []]) {
    for (final s in iniciales) {
      _datos.putIfAbsent(s.usuario, () => []).add(s);
    }
  }

  @override
  Future<List<Sesion>> obtener(String usuario) async =>
      List.of(_datos[usuario] ?? const <Sesion>[])..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<void> guardar(Sesion sesion) async {
    final lista = _datos.putIfAbsent(sesion.usuario, () => []);
    lista.removeWhere((s) => s.id == sesion.id);
    lista.add(sesion);
  }

  @override
  Future<void> eliminar(String usuario, String id) async => _datos[usuario]?.removeWhere((s) => s.id == id);

  @override
  Future<void> borrarTodo(String usuario) async => _datos.remove(usuario);
}
