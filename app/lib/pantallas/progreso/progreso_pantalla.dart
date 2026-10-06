import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/item_sesion.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/resultado_analisis.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';

class ProgresoPantalla extends ConsumerStatefulWidget {
  const ProgresoPantalla({super.key});

  @override
  ConsumerState<ProgresoPantalla> createState() => _ProgresoPantallaState();
}

class _ProgresoPantallaState extends ConsumerState<ProgresoPantalla> {
  String? _ejercicio;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final historial = ref.watch(historialProvider);
    final todas = historial.value ?? const <Sesion>[];
    final spec = ref.watch(especificacionProvider);
    final idsConSesiones = {for (final s in todas) s.ejercicio};
    final filtro = idsConSesiones.contains(_ejercicio) ? _ejercicio : null;
    final sesiones = filtro == null ? todas : todas.where((s) => s.ejercicio == filtro).toList();
    final resumen = Resumen.desde(sesiones);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(historialProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 32),
            children: [
              Text('Progreso', style: context.textos.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Tu evolución y las correcciones más frecuentes.',
                style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
              ),
              const SizedBox(height: 16),
              if (historial.isLoading && todas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (todas.isEmpty)
                EstadoVacio(
                  icono: Icons.insights_rounded,
                  titulo: 'Sin datos todavía',
                  mensaje: 'Cuando completes tus primeras sesiones verás aquí tu evolución.',
                  accion: FilledButton(
                    onPressed: () => context.go(Rutas.ejercicios),
                    child: const Text('Ver ejercicios'),
                  ),
                )
              else ...[
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todos'),
                          selected: filtro == null,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _ejercicio = null),
                        ),
                      ),
                      for (final e in spec.ejercicios.where((e) => idsConSesiones.contains(e.id)))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.nombre),
                            selected: filtro == e.id,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _ejercicio = e.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TileEstadistica(
                        icono: Icons.event_available_rounded,
                        valor: '${resumen.sesiones}',
                        etiqueta: 'Sesiones',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TileEstadistica(
                        icono: Icons.speed_rounded,
                        valor: resumen.promedio == null ? '—' : Formato.numero(resumen.promedio!, 0),
                        etiqueta: 'Puntaje promedio',
                        color: p.acento,
                        fondo: p.acentoSuave,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TileEstadistica(
                        icono: Icons.emoji_events_outlined,
                        valor: resumen.mejor == null ? '—' : '${resumen.mejor}',
                        etiqueta: 'Mejor puntaje',
                        color: p.advertencia,
                        fondo: p.advertenciaSuave,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TileEstadistica(
                        icono: Icons.repeat_rounded,
                        valor: '${resumen.repeticiones}',
                        etiqueta: 'Repeticiones',
                        color: p.info,
                        fondo: p.infoSuave,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (sesiones.length >= 2) ...[
                  const EncabezadoSeccion(titulo: 'Evolución del puntaje'),
                  Tarjeta(
                    padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
                    child: _GraficoEvolucion(sesiones: sesiones),
                  ),
                  const SizedBox(height: 24),
                ],
                _CorreccionesFrecuentes(sesiones: sesiones),
                const EncabezadoSeccion(titulo: 'Historial'),
                ..._historialAgrupado(context, sesiones),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _historialAgrupado(BuildContext context, List<Sesion> sesiones) {
    final widgets = <Widget>[];
    String? grupoActual;
    for (final s in sesiones) {
      final grupo = Formato.grupoFecha(s.fecha);
      if (grupo != grupoActual) {
        grupoActual = grupo;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 10, bottom: 8),
            child: Text(
              grupo.toUpperCase(),
              style: context.textos.labelSmall?.copyWith(color: context.paleta.textoTerciario),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ItemSesion(
            sesion: s,
            onTap: () => context.push(Rutas.sesion(s.id), extra: s),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _GraficoEvolucion extends StatelessWidget {
  final List<Sesion> sesiones;
  const _GraficoEvolucion({required this.sesiones});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final orden = sesiones.take(20).toList().reversed.toList();
    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: (orden.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(color: p.borde, strokeWidth: 1, dashArray: const [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.round()}', style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
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
                    '${s.y.round()} pts\n${Formato.fechaRelativa(orden[s.x.round()].fecha)}',
                    context.textos.labelMedium!.copyWith(color: p.superficie),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < orden.length; i++) FlSpot(i.toDouble(), orden[i].puntaje.toDouble())],
              isCurved: true,
              preventCurveOverShooting: true,
              color: p.primario,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4.5,
                  color: Presentacion.coloresEstado(p, estadoDePuntaje(spot.y.round())).$1,
                  strokeWidth: 2,
                  strokeColor: p.superficie,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.primario.withValues(alpha: 0.2), p.primario.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorreccionesFrecuentes extends StatelessWidget {
  final List<Sesion> sesiones;
  const _CorreccionesFrecuentes({required this.sesiones});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final conteo = <String, int>{};
    final ejemplo = <String, Hallazgo>{};
    for (final s in sesiones) {
      for (final h in s.resultado.hallazgos) {
        if (h.severidad == Severidad.info || h.codigo == 'V1') continue;
        conteo[h.codigo] = (conteo[h.codigo] ?? 0) + 1;
        ejemplo[h.codigo] = h;
      }
    }
    if (conteo.isEmpty) return const SizedBox.shrink();
    final top = conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maximo = top.first.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(titulo: 'Correcciones más frecuentes'),
          Tarjeta(
            child: Column(
              children: [
                for (var i = 0; i < top.length && i < 3; i++) ...[
                  Row(
                    children: [
                      Icon(
                        Presentacion.iconoZona(ejemplo[top[i].key]!.zona, top[i].key),
                        size: 20,
                        color: Presentacion.coloresSeveridad(p, ejemplo[top[i].key]!.severidad).$1,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(ejemplo[top[i].key]!.titulo, style: context.textos.titleSmall)),
                      Text(Formato.plural(top[i].value, 'sesión', 'sesiones'), style: context.textos.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: top[i].value / maximo,
                      minHeight: 6,
                      color: Presentacion.coloresSeveridad(p, ejemplo[top[i].key]!.severidad).$1,
                    ),
                  ),
                  if (i < top.length - 1 && i < 2) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
