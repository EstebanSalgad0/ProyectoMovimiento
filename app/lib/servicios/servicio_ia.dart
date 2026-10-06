import 'dart:io';

import 'package:dio/dio.dart';

import '../modelos/resultado_analisis.dart';

enum TipoErrorAnalisis { sinConexion, tiempoAgotado, servidor, cancelado, desconocido }

class ErrorAnalisis implements Exception {
  final TipoErrorAnalisis tipo;
  final String mensaje;
  const ErrorAnalisis(this.tipo, this.mensaje);
  @override
  String toString() => mensaje;
}

class EstadoServidor {
  final bool disponible;
  final String? version;
  final String? detalle;
  const EstadoServidor({required this.disponible, this.version, this.detalle});
}

/// Cliente de la API de análisis (servidor/servidor.py).
class ServicioIA {
  final Dio _dio;
  final String urlBase;

  ServicioIA(this.urlBase, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: urlBase,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(minutes: 5),
              responseType: ResponseType.json,
            ),
          );

  Future<EstadoServidor> verificar() async {
    try {
      final r = await _dio.get<dynamic>('/salud', options: Options(receiveTimeout: const Duration(seconds: 6)));
      final datos = r.data is Map ? r.data as Map : const {};
      return EstadoServidor(disponible: true, version: datos['version']?.toString());
    } on DioException catch (e) {
      // Servidor v1: no tiene /salud pero responde en /.
      if (e.response?.statusCode == 404) {
        try {
          await _dio.get<dynamic>('/');
          return const EstadoServidor(disponible: true, version: '1.x');
        } on DioException catch (e2) {
          return EstadoServidor(disponible: false, detalle: _traducir(e2).mensaje);
        }
      }
      return EstadoServidor(disponible: false, detalle: _traducir(e).mensaje);
    }
  }

  /// Sube el video y devuelve el análisis. [onProgreso] informa el avance de
  /// la subida entre 0 y 1.
  Future<ResultadoAnalisis> analizarVideo({
    required File video,
    required String ejercicio,
    CancelToken? cancelar,
    void Function(double progreso)? onProgreso,
  }) async {
    Future<Response<dynamic>> enviar(String ruta) async {
      final formulario = FormData.fromMap({
        'ejercicio': ejercicio,
        'video': await MultipartFile.fromFile(video.path, filename: video.uri.pathSegments.last),
      });
      return _dio.post<dynamic>(
        ruta,
        data: formulario,
        cancelToken: cancelar,
        onSendProgress: (enviado, total) {
          if (total > 0) onProgreso?.call(enviado / total);
        },
      );
    }

    try {
      Response<dynamic> respuesta;
      try {
        respuesta = await enviar('/v1/analisis/video');
      } on DioException catch (e) {
        // Compatibilidad con el servidor v1, que solo expone /analizar.
        if (e.response?.statusCode != 404) rethrow;
        respuesta = await enviar('/analizar');
      }
      final datos = respuesta.data;
      if (datos is! Map) throw const ErrorAnalisis(TipoErrorAnalisis.servidor, 'Respuesta inesperada del servidor');
      return ResultadoAnalisis.fromJson(Map<String, dynamic>.from(datos));
    } on DioException catch (e) {
      throw _traducir(e);
    }
  }

  ErrorAnalisis _traducir(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return const ErrorAnalisis(TipoErrorAnalisis.cancelado, 'Análisis cancelado');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return ErrorAnalisis(
          TipoErrorAnalisis.sinConexion,
          'No se pudo conectar con el servidor ($urlBase). Revisa que esté encendido y que la dirección '
          'en Cuenta → Servidor de análisis sea correcta.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ErrorAnalisis(
          TipoErrorAnalisis.tiempoAgotado,
          'El servidor tardó demasiado en responder. Prueba con un video más corto.',
        );
      case DioExceptionType.badResponse:
        final datos = e.response?.data;
        String? detalle;
        if (datos is Map) detalle = (datos['error'] ?? datos['detail'])?.toString();
        return ErrorAnalisis(
          TipoErrorAnalisis.servidor,
          detalle ?? 'El servidor respondió con un error (${e.response?.statusCode}).',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ErrorAnalisis(TipoErrorAnalisis.desconocido, 'Error inesperado: ${e.message ?? e.error}');
    }
  }
}
