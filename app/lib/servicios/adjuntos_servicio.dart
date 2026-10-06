import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../modelos/esqueleto.dart';

/// Archivos asociados a una sesión que no van dentro del historial (para que
/// este siga siendo liviano): el esqueleto grabado y la copia del video.
abstract class AdjuntosServicio {
  Future<void> guardarEsqueleto(String sesionId, EsqueletoGrabado esqueleto);
  Future<EsqueletoGrabado?> leerEsqueleto(String sesionId);

  /// Copia el video al almacenamiento de la app y devuelve la nueva ruta.
  Future<String?> guardarVideo(String sesionId, File origen);
  Future<void> eliminar(String sesionId, {String? videoRuta});
  Future<int> tamanoVideos();
  Future<void> borrarVideos();
}

class AdjuntosArchivo implements AdjuntosServicio {
  Future<Directory> _dir(String nombre) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$nombre');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _esqueleto(String id) async =>
      File('${(await _dir('esqueletos')).path}${Platform.pathSeparator}$id.json');

  @override
  Future<void> guardarEsqueleto(String sesionId, EsqueletoGrabado esqueleto) async {
    final f = await _esqueleto(sesionId);
    await f.writeAsString(jsonEncode(esqueleto.toJson()), flush: true);
  }

  @override
  Future<EsqueletoGrabado?> leerEsqueleto(String sesionId) async {
    try {
      final f = await _esqueleto(sesionId);
      if (!await f.exists()) return null;
      return EsqueletoGrabado.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> guardarVideo(String sesionId, File origen) async {
    try {
      final ext = origen.path.contains('.') ? origen.path.substring(origen.path.lastIndexOf('.')) : '.mp4';
      final destino = '${(await _dir('videos')).path}${Platform.pathSeparator}$sesionId$ext';
      await origen.copy(destino);
      return destino;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> eliminar(String sesionId, {String? videoRuta}) async {
    try {
      final f = await _esqueleto(sesionId);
      if (await f.exists()) await f.delete();
      if (videoRuta != null) {
        final v = File(videoRuta);
        if (await v.exists()) await v.delete();
      }
    } catch (_) {}
  }

  @override
  Future<int> tamanoVideos() async {
    final d = await _dir('videos');
    var total = 0;
    await for (final e in d.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  @override
  Future<void> borrarVideos() async {
    final d = await _dir('videos');
    await for (final e in d.list()) {
      if (e is File) await e.delete();
    }
  }
}

/// Implementación en memoria (tests).
class AdjuntosMemoria implements AdjuntosServicio {
  final Map<String, EsqueletoGrabado> esqueletos = {};

  @override
  Future<void> guardarEsqueleto(String sesionId, EsqueletoGrabado esqueleto) async => esqueletos[sesionId] = esqueleto;

  @override
  Future<EsqueletoGrabado?> leerEsqueleto(String sesionId) async => esqueletos[sesionId];

  @override
  Future<String?> guardarVideo(String sesionId, File origen) async => null;

  @override
  Future<void> eliminar(String sesionId, {String? videoRuta}) async => esqueletos.remove(sesionId);

  @override
  Future<int> tamanoVideos() async => 0;

  @override
  Future<void> borrarVideos() async {}
}
