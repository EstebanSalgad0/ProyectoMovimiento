import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../modelos/evaluacion.dart';
import 'historial_servicio.dart';

/// Pruebas funcionales y mediciones de rango articular del usuario.
abstract class EvaluacionesServicio {
  Future<List<EvaluacionFuncional>> obtener(String usuario);
  Future<void> guardar(EvaluacionFuncional evaluacion);
  Future<void> eliminar(String usuario, String id);
  Future<void> borrarTodo(String usuario);
}

class EvaluacionesArchivo implements EvaluacionesServicio {
  Future<File> _archivo(String usuario) async {
    final dir = await getApplicationDocumentsDirectory();
    final nombre = 'evaluaciones_${HistorialArchivo.normalizarUsuario(usuario)}.json';
    return File('${dir.path}${Platform.pathSeparator}$nombre');
  }

  @override
  Future<List<EvaluacionFuncional>> obtener(String usuario) async {
    try {
      final f = await _archivo(usuario);
      if (!await f.exists()) return [];
      final datos = jsonDecode(await f.readAsString());
      if (datos is! List) return [];
      final lista = <EvaluacionFuncional>[];
      for (final e in datos.whereType<Map>()) {
        try {
          lista.add(EvaluacionFuncional.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    } catch (_) {
      return [];
    }
  }

  Future<void> _escribir(String usuario, List<EvaluacionFuncional> lista) async {
    final f = await _archivo(usuario);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final e in lista) e.toJson()]), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> guardar(EvaluacionFuncional evaluacion) async {
    final actuales = await obtener(evaluacion.usuario);
    await _escribir(evaluacion.usuario, [evaluacion, ...actuales.where((e) => e.id != evaluacion.id)]);
  }

  @override
  Future<void> eliminar(String usuario, String id) async {
    final actuales = await obtener(usuario);
    await _escribir(usuario, actuales.where((e) => e.id != id).toList());
  }

  @override
  Future<void> borrarTodo(String usuario) async {
    final f = await _archivo(usuario);
    if (await f.exists()) await f.delete();
  }
}

class EvaluacionesMemoria implements EvaluacionesServicio {
  final Map<String, List<EvaluacionFuncional>> _datos = {};

  EvaluacionesMemoria([List<EvaluacionFuncional> iniciales = const []]) {
    for (final e in iniciales) {
      _datos.putIfAbsent(e.usuario, () => []).add(e);
    }
  }

  @override
  Future<List<EvaluacionFuncional>> obtener(String usuario) async =>
      List.of(_datos[usuario] ?? const <EvaluacionFuncional>[])..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<void> guardar(EvaluacionFuncional evaluacion) async {
    final l = _datos.putIfAbsent(evaluacion.usuario, () => []);
    l.removeWhere((e) => e.id == evaluacion.id);
    l.add(evaluacion);
  }

  @override
  Future<void> eliminar(String usuario, String id) async => _datos[usuario]?.removeWhere((e) => e.id == id);

  @override
  Future<void> borrarTodo(String usuario) async => _datos.remove(usuario);
}
