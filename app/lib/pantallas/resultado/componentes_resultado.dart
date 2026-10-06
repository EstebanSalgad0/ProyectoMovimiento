import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/insignia_estado.dart';
import '../../core/widgets/tarjeta.dart';
import '../../modelos/resultado_analisis.dart';
import '../../motor/especificacion.dart';

/// Gráfico de la señal principal (p. ej. ángulo de rodilla) con las
/// repeticiones sombreadas y la línea objetivo.
class GraficoSenal extends StatelessWidget {
  final SerieTemporal serie;
  final List<Repeticion> repeticiones;
  final double? objetivo;

  const GraficoSenal({super.key, required this.serie, required this.repeticiones, this.objetivo});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final t0 = serie.tMs.isEmpty ? 0 : serie.tMs.first;
    final puntos = <FlSpot>[
      for (var i = 0; i < serie.tMs.length; i++)
        serie.valores[i] == null ? FlSpot.nullSpot : FlSpot((serie.tMs[i] - t0) / 1000, serie.valores[i]!),
    ];
    final valores = serie.valores.whereType<double>();
    var minY = valores.reduce((a, b) => a < b ? a : b);
    var maxY = valores.reduce((a, b) => a > b ? a : b);
    if (objetivo != null) {
      minY = minY < objetivo! ? minY : objetivo!;
      maxY = maxY > objetivo! ? maxY : objetivo!;
    }
    final margen = ((maxY - minY) * 0.12).clamp(4.0, 30.0);
    final maxX = puntos.isEmpty ? 1.0 : puntos.last.x;

    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minY: (minY - margen).floorToDouble(),
          maxY: (maxY + margen).ceilToDouble(),
          minX: 0,
          maxX: maxX <= 0 ? 1 : maxX,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: p.borde, strokeWidth: 1, dashArray: const [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          rangeAnnotations: RangeAnnotations(
            verticalRangeAnnotations: [
              for (final r in repeticiones)
                VerticalRangeAnnotation(
                  x1: (r.inicioMs - t0) / 1000,
                  x2: (r.finMs - t0) / 1000,
                  color: p.primario.withValues(alpha: 0.07),
                ),
            ],
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (objetivo != null)
                HorizontalLine(
                  y: objetivo!,
                  color: p.exito,
                  strokeWidth: 1.6,
                  dashArray: const [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: context.textos.labelSmall?.copyWith(color: p.exito),
                    labelResolver: (l) => 'Objetivo ${l.y.round()}${serie.unidad}',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: 20,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${v.round()}${serie.unidad}',
                    style: context.textos.labelSmall?.copyWith(color: p.textoTerciario),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: maxX > 40 ? 10 : 5,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.round()} s', style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.texto,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.y.round()}${serie.unidad} · ${Formato.numero(s.x)} s',
                    context.textos.labelMedium!.copyWith(color: p.superficie),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: puntos,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: p.primario,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.primario.withValues(alpha: 0.22), p.primario.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una corrección (hallazgo).
class TarjetaHallazgo extends StatelessWidget {
  final Hallazgo hallazgo;

  const TarjetaHallazgo({super.key, required this.hallazgo});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final (color, fondo) = Presentacion.coloresSeveridad(p, hallazgo.severidad);
    final frecuencia = hallazgo.frecuencia;
    return Tarjeta(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoCaja(
            icono: Presentacion.iconoZona(hallazgo.zona, hallazgo.codigo),
            color: color,
            fondo: fondo,
            tamano: 42,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(hallazgo.titulo, style: context.textos.titleSmall)),
                    const SizedBox(width: 8),
                    ChipDato(texto: hallazgo.severidad.etiqueta, color: color, fondo: fondo),
                  ],
                ),
                const SizedBox(height: 6),
                Text(hallazgo.mensaje, style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario)),
                if (frecuencia != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 14, color: p.textoTerciario),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(frecuencia, style: context.textos.labelMedium?.copyWith(color: p.textoTerciario)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de una repetición; al tocarla abre su detalle.
class ChipRepeticion extends StatelessWidget {
  final Repeticion rep;
  final VoidCallback onTap;

  const ChipRepeticion({super.key, required this.rep, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return SizedBox(
      width: 84,
      child: Tarjeta(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Rep. ${rep.numero}', style: context.textos.labelMedium?.copyWith(color: p.textoSecundario)),
            const SizedBox(height: 8),
            InsigniaPuntaje(puntaje: rep.puntaje, tamano: 42),
            const SizedBox(height: 8),
            Icon(
              rep.fallos.isEmpty ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 16,
              color: rep.fallos.isEmpty ? p.exito : p.advertencia,
            ),
          ],
        ),
      ),
    );
  }
}

/// Duraciones en segundos; razones normalizadas (valgo, altura de muñecas)
/// con dos decimales; el resto son ángulos en grados.
String _formatearValor(Verificacion? v, double valor) {
  if (v?.tipo == 'duracion_min') return Formato.segundos(valor);
  final metrica = v?.metrica ?? '';
  if (metrica.startsWith('valgo') || metrica.startsWith('munecas')) return Formato.numero(valor, 2);
  return '${Formato.numero(valor, 0)}°';
}

/// Hoja con el detalle de una repetición.
void mostrarDetalleRepeticion(BuildContext context, Repeticion rep, EjercicioSpec? ejercicio) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final p = context.paleta;
      final unidad = ejercicio?.senal.unidad ?? '';
      Widget dato(String etiqueta, String valor) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: context.textos.titleMedium),
            const SizedBox(height: 2),
            Text(etiqueta, style: context.textos.bodySmall),
          ],
        ),
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Expanded(child: Text('Repetición ${rep.numero}', style: context.textos.titleLarge)),
                InsigniaPuntaje(puntaje: rep.puntaje),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                dato(ejercicio?.senal.nombre ?? 'Pico', '${Formato.numero(rep.valorPico, 0)}$unidad'),
                dato('Rango de movimiento', '${Formato.numero(rep.rango, 0)}$unidad'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                dato(ejercicio?.faseIda ?? 'Ida', Formato.segundos(rep.excentricaS)),
                dato(ejercicio?.faseVuelta ?? 'Vuelta', Formato.segundos(rep.concentricaS)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Revisiones', style: context.textos.titleSmall),
            const SizedBox(height: 8),
            for (final entrada in rep.valores.entries)
              Builder(
                builder: (context) {
                  Verificacion? v;
                  for (final x in ejercicio?.verificaciones ?? const <Verificacion>[]) {
                    if (x.codigo == entrada.key) v = x;
                  }
                  final falla = rep.fallos.contains(entrada.key);
                  final valor = _formatearValor(v, entrada.value);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      falla ? Icons.cancel_rounded : Icons.check_circle_rounded,
                      color: falla ? p.advertencia : p.exito,
                    ),
                    title: Text(falla ? (v?.titulo ?? entrada.key) : (v?.mensajeOk ?? v?.titulo ?? entrada.key)),
                    trailing: Text(valor, style: context.textos.labelLarge),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}
