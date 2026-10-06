import 'evaluacion.dart';
import 'logros.dart';
import 'resultado_analisis.dart';
import 'sesion.dart';
import 'usuario.dart';

enum TipoRecomendacion { dolorIntenso, dolorModerado, correccion, evaluacion, meta, metaCumplida }

/// Sugerencia de la sección "Para ti" del inicio.
class Recomendacion {
  final TipoRecomendacion tipo;
  final String titulo;
  final String detalle;

  /// Ejercicio relacionado (para abrir su detalle).
  final String? ejercicioId;

  const Recomendacion({required this.tipo, required this.titulo, required this.detalle, this.ejercicioId});
}

/// Reglas simples y explicables sobre el historial local. Devuelve como
/// máximo [maximo] sugerencias, ordenadas por importancia.
List<Recomendacion> generarRecomendaciones({
  required Usuario? usuario,
  required List<Sesion> sesiones,
  required List<EvaluacionFuncional> evaluaciones,
  String Function(String ejercicioId)? nombreEjercicio,
  DateTime? hoy,
  int maximo = 3,
}) {
  final ahora = hoy ?? DateTime.now();
  final nombre = nombreEjercicio ?? (String id) => id.replaceAll('_', ' ');
  final r = <Recomendacion>[];

  // 1. Dolor reportado en los últimos 3 días.
  final recientes = [...sesiones]..sort((a, b) => b.fecha.compareTo(a.fecha));
  final conSensaciones = recientes
      .where((s) => s.sensaciones != null && ahora.difference(s.fecha) <= const Duration(days: 3))
      .firstOrNull;
  final dolor = conSensaciones?.sensaciones?.dolor ?? 0;
  final zona = conSensaciones?.sensaciones?.zonaDolor;
  final enZona = zona == null ? '' : ' en ${(zonasMolestia[zona] ?? zona).toLowerCase()}';
  if (dolor >= 7) {
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.dolorIntenso,
        titulo: 'Reportaste dolor intenso$enZona',
        detalle:
            'Descansa de los ejercicios que lo provocan y consulta con un profesional de la salud antes de seguir.',
      ),
    );
  } else if (dolor >= 4) {
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.dolorModerado,
        titulo: 'Tuviste molestias$enZona',
        detalle: 'Baja la intensidad: menos repeticiones o un rango más corto. Si el dolor sigue, consulta.',
      ),
    );
  }

  // 2. Corrección más repetida en las últimas 2 semanas.
  final conteo = <String, (Hallazgo, String, int)>{};
  for (final s in recientes.where((s) => ahora.difference(s.fecha) <= const Duration(days: 14))) {
    for (final h in s.resultado.hallazgos.where((h) => h.severidad != Severidad.info)) {
      final clave = '${s.ejercicio}/${h.codigo}';
      conteo[clave] = (h, s.ejercicio, (conteo[clave]?.$3 ?? 0) + 1);
    }
  }
  final frecuentes = conteo.values.where((c) => c.$3 >= 2).toList()..sort((a, b) => b.$3.compareTo(a.$3));
  if (frecuentes.isNotEmpty) {
    final (h, ejercicio, veces) = frecuentes.first;
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.correccion,
        titulo: 'Trabaja en: ${h.titulo.toLowerCase()}',
        detalle: 'Apareció en $veces sesiones recientes de ${nombre(ejercicio).toLowerCase()}. ${h.mensaje}',
        ejercicioId: ejercicio,
      ),
    );
  }

  // 3. Evaluaciones: prueba de 30 s cada mes para quienes más la necesitan.
  final edad = usuario?.edadEn(ahora);
  final ultimaSts = evaluaciones
      .where((e) => e.tipo == TipoEvaluacion.sentarsePararse30s)
      .fold<DateTime?>(null, (m, e) => m == null || e.fecha.isAfter(m) ? e.fecha : m);
  final priorizaSts =
      (edad ?? 0) >= 60 || usuario?.objetivo == Objetivo.prevencionCaidas || usuario?.objetivo == Objetivo.movilidad;
  if (priorizaSts && (ultimaSts == null || ahora.difference(ultimaSts).inDays >= 30)) {
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.evaluacion,
        titulo: ultimaSts == null ? 'Mide tu fuerza de piernas' : 'Repite la prueba de 30 segundos',
        detalle: ultimaSts == null
            ? 'La prueba de sentarse y pararse toma 30 segundos y te muestra cómo estás para tu edad.'
            : 'Pasó un mes desde la última: compárala para ver tu avance.',
      ),
    );
  } else if (evaluaciones.isEmpty && sesiones.length >= 3) {
    r.add(
      const Recomendacion(
        tipo: TipoRecomendacion.evaluacion,
        titulo: 'Conoce tu punto de partida',
        detalle: 'Haz una prueba de 30 segundos o mide tu rango de movimiento para seguir tu progreso.',
      ),
    );
  }

  // 4. Meta semanal.
  final meta = usuario?.metaSemanal ?? 3;
  final fechas = [...sesiones.map((s) => s.fecha), ...evaluaciones.map((e) => e.fecha)];
  final activos = diasActivosSemana(fechas, hoy: ahora);
  final diasRestantes = 8 - ahora.weekday; // incluye hoy
  if (activos >= meta) {
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.metaCumplida,
        titulo: '¡Cumpliste tu meta de la semana!',
        detalle: 'Entrenaste $activos días. Mantener la constancia es lo que más ayuda.',
      ),
    );
  } else if (sesiones.isNotEmpty && meta - activos <= diasRestantes) {
    final faltan = meta - activos;
    r.add(
      Recomendacion(
        tipo: TipoRecomendacion.meta,
        titulo: faltan == 1 ? 'Te falta 1 día para tu meta' : 'Te faltan $faltan días para tu meta',
        detalle: 'Una rutina corta de 5 minutos cuenta. ¡Tú puedes!',
      ),
    );
  }

  return r.take(maximo).toList();
}
