import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/rutina.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';
import 'package:medicina_app/motor/especificacion.dart';
import 'package:medicina_app/servicios/exportacion_servicio.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ayudantes.dart';

void main() {
  final spec = cargarEspecificacion();
  final ahora = DateTime(2025, 10, 8, 18);
  final usuario = Usuario(
    usuario: 'ana',
    nombre: 'Ana Pérez',
    email: 'ana@correo.cl',
    rol: RolUsuario.paciente,
    creadoEn: DateTime(2025),
    fechaNacimiento: DateTime(1955, 5, 2),
    sexo: Sexo.femenino,
    objetivo: Objetivo.prevencionCaidas,
    molestias: const ['rodillas'],
    notasSalud: 'Prótesis de rodilla derecha (2023)',
  );
  final sesiones = [
    Sesion(
      id: 'a',
      usuario: 'ana',
      fecha: ahora.subtract(const Duration(days: 1)),
      origen: OrigenSesion.tiempoReal,
      resultado: resultadoDeFixture(spec, 'sentadilla_lateral_poco_profunda'),
      sensaciones: const Sensaciones(esfuerzo: 6, dolor: 3, zonaDolor: 'rodillas', nota: 'Bien'),
    ),
    Sesion(
      id: 'b',
      usuario: 'ana',
      fecha: ahora.subtract(const Duration(days: 3)),
      origen: OrigenSesion.video,
      resultado: resultadoDeFixture(spec, 'curl_frontal_correcto'),
    ),
  ];
  final evaluaciones = [
    EvaluacionFuncional.sts30(usuario: 'ana', repeticiones: 11, edad: 70, sexo: Sexo.femenino),
    EvaluacionFuncional.rango(usuario: 'ana', articulacion: Articulacion.rodilla, lado: Lado.derecho, maximo: 112),
  ];

  test('exportación JSON con todos los datos', () {
    final datos = ExportacionServicio.datosUsuario(
      usuario: usuario,
      sesiones: sesiones,
      evaluaciones: evaluaciones,
      rutinas: [rutinasPredefinidas.first],
      objetivos: const {
        'sentadilla': {'SQ_PROFUNDIDAD': AjusteVerificacion(umbral: 110)},
      },
      generado: ahora,
    );
    // Se puede serializar y releer.
    final texto = ExportacionServicio.jsonLegible(datos);
    final releido = jsonDecode(texto) as Map<String, dynamic>;
    expect(releido['formato'], ExportacionServicio.formatoExportacion);
    expect(releido['usuario']['nombre'], 'Ana Pérez');
    expect(releido['usuario'].containsKey('hash'), isFalse, reason: 'nunca se exporta la contraseña');
    expect(releido['sesiones'], hasLength(2));
    expect(releido['evaluaciones'], hasLength(2));
    expect(releido['rutinas'], hasLength(1));
    expect(releido['objetivos']['sentadilla']['SQ_PROFUNDIDAD']['umbral'], 110);
    expect(Sesion.fromJson(Map<String, dynamic>.from(releido['sesiones'][0] as Map)).sensaciones?.dolor, 3);
  });

  test('genera un reporte PDF', () async {
    pw.Font fuente(String peso) =>
        pw.Font.ttf(ByteData.view(File('assets/fuentes/PlusJakartaSans-$peso.ttf').readAsBytesSync().buffer));
    final bytes = await ExportacionServicio.reportePdf(
      usuario: usuario,
      sesiones: sesiones,
      evaluaciones: evaluaciones,
      spec: spec,
      regular: fuente('Regular'),
      negrita: fuente('Bold'),
      generado: ahora,
    );
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('reporte PDF sin datos', () async {
    pw.Font fuente(String peso) =>
        pw.Font.ttf(ByteData.view(File('assets/fuentes/PlusJakartaSans-$peso.ttf').readAsBytesSync().buffer));
    final bytes = await ExportacionServicio.reportePdf(
      usuario: usuario,
      sesiones: const [],
      evaluaciones: const [],
      spec: spec,
      regular: fuente('Regular'),
      negrita: fuente('Bold'),
      generado: ahora,
    );
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}
