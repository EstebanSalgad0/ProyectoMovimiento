import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/config/app_config.dart';
import '../modelos/evaluacion.dart';
import '../modelos/logros.dart';
import '../modelos/resultado_analisis.dart';
import '../modelos/rutina.dart';
import '../modelos/sesion.dart';
import '../modelos/usuario.dart';
import '../motor/especificacion.dart';

/// Exporta los datos del usuario (JSON) y genera un reporte en PDF para
/// compartir con un profesional de la salud.
class ExportacionServicio {
  static const formatoExportacion = 'proyecto-movimiento/datos';

  /// Todos los datos guardados del usuario, en un formato documentado.
  static Map<String, dynamic> datosUsuario({
    required Usuario usuario,
    required List<Sesion> sesiones,
    required List<EvaluacionFuncional> evaluaciones,
    required List<Rutina> rutinas,
    required AjustesEjercicios objetivos,
    DateTime? generado,
  }) => {
    'formato': formatoExportacion,
    'version': 1,
    'app_version': AppConfig.version,
    'generado': (generado ?? DateTime.now()).toIso8601String(),
    'usuario': usuario.toJson(),
    'sesiones': [for (final s in sesiones) s.toJson()],
    'evaluaciones': [for (final e in evaluaciones) e.toJson()],
    'rutinas': [for (final r in rutinas) r.toJson()],
    'objetivos': ajustesAJson(objetivos),
  };

  static Future<File> guardarTemporal(String nombre, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nombre');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> compartir(File archivo, {required String asunto, String? tipo}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(archivo.path, mimeType: tipo)],
        subject: asunto,
        title: asunto,
      ),
    );
  }

  static String marcaFecha(DateTime f) =>
      '${f.year}${f.month.toString().padLeft(2, '0')}${f.day.toString().padLeft(2, '0')}';

  static Future<(pw.Font, pw.Font)> fuentesDeAssets() async {
    final regular = await rootBundle.load('assets/fuentes/PlusJakartaSans-Regular.ttf');
    final negrita = await rootBundle.load('assets/fuentes/PlusJakartaSans-Bold.ttf');
    return (pw.Font.ttf(regular), pw.Font.ttf(negrita));
  }

  // ---------------------------------------------------------------- PDF
  static const _azul = PdfColor.fromInt(0xFF2F6FED);
  static const _marino = PdfColor.fromInt(0xFF14285E);
  static const _gris = PdfColor.fromInt(0xFF55617B);
  static const _grisClaro = PdfColor.fromInt(0xFFEEF2F9);
  static const _borde = PdfColor.fromInt(0xFFE3E8F2);

  static String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  /// Reporte de los últimos [dias] días.
  static Future<Uint8List> reportePdf({
    required Usuario usuario,
    required List<Sesion> sesiones,
    required List<EvaluacionFuncional> evaluaciones,
    required Especificacion spec,
    required pw.Font regular,
    required pw.Font negrita,
    int dias = 30,
    DateTime? generado,
  }) async {
    final ahora = generado ?? DateTime.now();
    final desde = soloDia(ahora).subtract(Duration(days: dias - 1));
    final periodo = [
      for (final s in sesiones)
        if (!s.fecha.isBefore(desde)) s,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final evals = [
      for (final e in evaluaciones)
        if (!e.fecha.isBefore(desde)) e,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));

    final reps = periodo.fold(0, (t, s) => t + s.resultado.numeroRepeticiones);
    final diasActivos = {for (final s in periodo) soloDia(s.fecha)}.length;
    final promedio = periodo.isEmpty ? null : periodo.fold(0, (t, s) => t + s.puntaje) / periodo.length;

    // Por ejercicio
    final porEjercicio = <String, List<Sesion>>{};
    for (final s in periodo) {
      porEjercicio.putIfAbsent(s.ejercicio, () => []).add(s);
    }

    // Correcciones más frecuentes
    final conteo = <String, (Hallazgo, String, int)>{};
    for (final s in periodo) {
      for (final h in s.resultado.hallazgos.where((h) => h.severidad != Severidad.info)) {
        final clave = '${s.ejercicio}/${h.codigo}';
        final previo = conteo[clave];
        conteo[clave] = (h, s.ejercicio, (previo?.$3 ?? 0) + 1);
      }
    }
    final frecuentes = conteo.values.toList()..sort((a, b) => b.$3.compareTo(a.$3));

    // Sensaciones
    final conSensaciones = [
      for (final s in periodo)
        if (s.sensaciones != null) s.sensaciones!,
    ];
    double? media(Iterable<int> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    final zonas = <String, int>{};
    for (final s in conSensaciones.where((s) => s.dolor > 0 && s.zonaDolor != null)) {
      zonas[s.zonaDolor!] = (zonas[s.zonaDolor!] ?? 0) + 1;
    }

    String nombreEjercicio(String id) => spec.buscar(id)?.nombre ?? id.replaceAll('_', ' ');
    String n1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

    final tema = pw.ThemeData.withFont(base: regular, bold: negrita);
    final doc = pw.Document(title: 'Reporte de actividad', author: AppConfig.nombreCompleto, theme: tema);

    pw.Widget titulo(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(
        t,
        style: pw.TextStyle(font: negrita, fontSize: 13, color: _marino),
      ),
    );

    pw.Widget dato(String valor, String etiqueta) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: _grisClaro, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              valor,
              style: pw.TextStyle(font: negrita, fontSize: 18, color: _marino),
            ),
            pw.SizedBox(height: 2),
            pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: _gris)),
          ],
        ),
      ),
    );

    pw.Widget tabla(List<String> encabezados, List<List<String>> filas, {Map<int, pw.TableColumnWidth>? anchos}) =>
        pw.TableHelper.fromTextArray(
          headers: encabezados,
          data: filas,
          columnWidths: anchos,
          headerStyle: pw.TextStyle(font: negrita, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _azul),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {for (var i = 1; i < encabezados.length; i++) i: pw.Alignment.centerRight},
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.5)),
          ),
          border: null,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        );

    final perfil = <String>[
      if (usuario.edad != null) '${usuario.edad} años',
      if (usuario.sexo != null && usuario.sexo != Sexo.otro) usuario.sexo!.etiqueta,
      if (usuario.estaturaCm != null) '${usuario.estaturaCm} cm',
      if (usuario.pesoKg != null) '${n1(usuario.pesoKg!)} kg',
      if (usuario.ladoDominante != null) 'lado dominante ${usuario.ladoDominante!.etiqueta.toLowerCase()}',
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Reporte de actividad · ${usuario.nombre}',
                  style: const pw.TextStyle(fontSize: 8, color: _gris),
                ),
              ),
        footer: (context) => pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '${AppConfig.nombreCompleto} ${AppConfig.version} · ${AppConfig.nivelMadurez}. '
                'Datos generados por la app; no constituyen un diagnóstico.',
                style: const pw.TextStyle(fontSize: 7, color: _gris),
              ),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _gris),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: _marino, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Reporte de actividad',
                        style: pw.TextStyle(font: negrita, fontSize: 20, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        usuario.nombre,
                        style: pw.TextStyle(font: negrita, fontSize: 12, color: PdfColors.white),
                      ),
                      if (perfil.isNotEmpty)
                        pw.Text(perfil.join(' · '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Período: ${_fecha(desde)} – ${_fecha(ahora)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    ),
                    pw.Text(
                      'Generado: ${_fecha(ahora)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (usuario.objetivo != null || usuario.molestias.isNotEmpty || usuario.notasSalud.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            if (usuario.objetivo != null)
              pw.Text('Objetivo: ${usuario.objetivo!.etiqueta} (${usuario.objetivo!.detalle.toLowerCase()})'),
            if (usuario.molestias.isNotEmpty)
              pw.Text('Molestias declaradas: ${usuario.molestias.map((m) => zonasMolestia[m] ?? m).join(', ')}'),
            if (usuario.notasSalud.isNotEmpty) pw.Text('Notas: ${usuario.notasSalud}'),
          ],
          titulo('Resumen del período'),
          pw.Row(
            children: [
              dato('${periodo.length}', 'Sesiones'),
              dato('$diasActivos', 'Días activos'),
              dato('$reps', 'Repeticiones'),
              dato(promedio == null ? '—' : '${promedio.round()}', 'Técnica promedio (0–100)'),
            ],
          ),
          if (porEjercicio.isNotEmpty) ...[
            titulo('Por ejercicio'),
            tabla(
              ['Ejercicio', 'Sesiones', 'Reps.', 'Promedio', 'Primera', 'Última'],
              [
                for (final e in porEjercicio.entries)
                  [
                    nombreEjercicio(e.key),
                    '${e.value.length}',
                    '${e.value.fold(0, (t, s) => t + s.resultado.numeroRepeticiones)}',
                    '${(e.value.fold(0, (t, s) => t + s.puntaje) / e.value.length).round()}',
                    '${e.value.first.puntaje}',
                    '${e.value.last.puntaje}',
                  ],
              ],
              anchos: {0: const pw.FlexColumnWidth(3)},
            ),
          ],
          if (frecuentes.isNotEmpty) ...[
            titulo('Correcciones más frecuentes'),
            tabla(
              ['Corrección', 'Ejercicio', 'Sesiones'],
              [
                for (final (h, ej, n) in frecuentes.take(6)) [h.titulo, nombreEjercicio(ej), '$n'],
              ],
              anchos: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
            ),
          ],
          if (conSensaciones.isNotEmpty) ...[
            titulo('Esfuerzo y dolor reportados'),
            pw.Row(
              children: [
                dato(n1(media(conSensaciones.map((s) => s.esfuerzo))!), 'Esfuerzo promedio (0–10)'),
                dato(n1(media(conSensaciones.map((s) => s.dolor))!), 'Dolor promedio (0–10)'),
                dato('${conSensaciones.map((s) => s.dolor).reduce((a, b) => a > b ? a : b)}', 'Dolor máximo (0–10)'),
                dato('${conSensaciones.length}', 'Sesiones con registro'),
              ],
            ),
            if (zonas.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Zonas con dolor: ${zonas.entries.map((z) => '${zonasMolestia[z.key] ?? z.key} (${z.value})').join(', ')}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ],
          if (evals.any((e) => e.tipo == TipoEvaluacion.sentarsePararse30s)) ...[
            titulo('Prueba de sentarse y pararse 30 s (CDC STEADI)'),
            tabla(
              ['Fecha', 'Repeticiones', 'Referencia', 'Clasificación'],
              [
                for (final e in evals.where((e) => e.tipo == TipoEvaluacion.sentarsePararse30s))
                  [
                    _fecha(e.fecha),
                    '${e.repeticiones ?? 0}',
                    e.umbralReferencia == null ? '—' : '${e.umbralReferencia} o más',
                    (e.clasificacion ?? ClasificacionSts30.sinReferencia).etiqueta,
                  ],
              ],
            ),
          ],
          if (evals.any((e) => e.tipo == TipoEvaluacion.rangoArticular)) ...[
            titulo('Rango de movimiento (goniómetro con cámara)'),
            tabla(
              ['Fecha', 'Articulación', 'Máximo', '% referencia'],
              [
                for (final e in evals.where((e) => e.tipo == TipoEvaluacion.rangoArticular))
                  [
                    _fecha(e.fecha),
                    '${e.articulacion?.movimiento ?? ''} (lado ${e.lado?.etiqueta.toLowerCase() ?? '—'})',
                    '${(e.maximo ?? 0).round()}°',
                    '${((e.fraccionReferencia ?? 0) * 100).round()} %',
                  ],
              ],
              anchos: {1: const pw.FlexColumnWidth(3)},
            ),
          ],
          if (periodo.isNotEmpty) ...[
            titulo('Detalle de sesiones'),
            tabla(
              ['Fecha', 'Ejercicio', 'Origen', 'Reps.', 'Puntaje', 'Esf./Dolor'],
              [
                for (final s in periodo.reversed)
                  [
                    _fecha(s.fecha),
                    nombreEjercicio(s.ejercicio),
                    s.rutina == null ? s.origen.etiqueta : 'Rutina',
                    '${s.resultado.numeroRepeticiones}',
                    '${s.puntaje}',
                    s.sensaciones == null ? '—' : '${s.sensaciones!.esfuerzo}/${s.sensaciones!.dolor}',
                  ],
              ],
              anchos: {1: const pw.FlexColumnWidth(3)},
            ),
          ],
          if (periodo.isEmpty && evals.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text('No hay sesiones ni evaluaciones registradas en este período.'),
            ),
          pw.SizedBox(height: 18),
          pw.Text(AppConfig.avisoMedico, style: const pw.TextStyle(fontSize: 8, color: _gris)),
          pw.Text(
            'El puntaje de técnica (0–100) resume las verificaciones automáticas de cada repetición. '
            'Las mediciones con cámara son aproximadas y dependen del encuadre.',
            style: const pw.TextStyle(fontSize: 8, color: _gris),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static String jsonLegible(Map<String, dynamic> datos) => const JsonEncoder.withIndent('  ').convert(datos);
}
