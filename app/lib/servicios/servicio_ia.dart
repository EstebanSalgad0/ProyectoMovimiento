// IMPORTANTE, ACÁ USO LA IP LOCAL. LA 10.0.2.2. LLEGO AL PC LOCAL DONDE CORRO.
// DEBO CAMBIARLA SI LO CORRO EN UN DISPOSITIVO REAL
// LA PASO A LA IP LOCAL DEL PC EN LA RED WIFI
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../modelos/resultado_analisis.dart';

class ServicioIA {
  static const String _baseUrl = 'http://10.0.2.2:8000';

  static Future<ResultadoAnalisis> analizarVideo({
    required File video,
    required String ejercicio,
  }) async {
    final uri = Uri.parse('$_baseUrl/analizar');

    final request = http.MultipartRequest('POST', uri);
    request.fields['ejercicio'] = ejercicio;
    request.files.add(await http.MultipartFile.fromPath('video', video.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return ResultadoAnalisis.fromJson(jsonDecode(body));
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }
}