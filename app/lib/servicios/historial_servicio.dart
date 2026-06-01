import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../modelos/resultado_analisis.dart';
import '../modelos/sesion.dart';

class HistorialServicio {
  static String _normalizarUsuario(String usuario) {
    final limpio = usuario.trim().toLowerCase();
    return limpio.isEmpty ? 'anonimo' : limpio.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
  }

  static Future<Directory> _directorioBase() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<File> _archivoDeUsuario(String usuario) async {
    final directorio = await _directorioBase();
    final nombreArchivo = 'historial_${_normalizarUsuario(usuario)}.json';
    return File('${directorio.path}${Platform.pathSeparator}$nombreArchivo');
  }

  static Future<List<Sesion>> obtenerHistorial(String usuario) async {
    try {
      final archivo = await _archivoDeUsuario(usuario);
      if (!await archivo.exists()) return [];

      final contenido = await archivo.readAsString();
      if (contenido.trim().isEmpty) return [];

      final data = jsonDecode(contenido);
      if (data is! List) return [];

      final historial = data
          .whereType<Map>()
          .map((json) => Sesion.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      historial.sort((a, b) => b.fecha.compareTo(a.fecha));
      return historial;
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardarAnalisis({
    required String usuario,
    required ResultadoAnalisis resultado,
    String? videoNombre,
  }) async {
    final archivo = await _archivoDeUsuario(usuario);
    final historialActual = await obtenerHistorial(usuario);

    historialActual.insert(
      0,
      Sesion.desdeResultado(
        usuario: usuario,
        resultado: resultado,
        fecha: DateTime.now(),
        videoNombre: videoNombre,
      ),
    );

    final contenido = jsonEncode(historialActual.map((sesion) => sesion.toJson()).toList());
    await archivo.writeAsString(contenido, flush: true);
  }
}



