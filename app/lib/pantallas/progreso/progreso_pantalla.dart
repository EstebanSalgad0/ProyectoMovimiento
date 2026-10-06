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
import '../../core/tema/tipografia.dart';
import '../../estado/proveedores.dart';
import '../../modelos/evaluacion.dart';
import '../../modelos/logros.dart';
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
    final evaluaciones = ref.watch(evaluacionesProvider).value ?? const <EvaluacionFuncional>[];
    final fechas = [...todas.map((s) => s.fecha), ...evaluaciones.map((e) => e.fecha)];
    final conSensaciones = sesiones.where((s) => s.sensaciones != null).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(historialProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Progreso', style: context.textos.headlineMedium)),
                  IconButton(
                    tooltip: 'Logros',
                    onPressed: () => context.push(Rutas.logros),
                    icon: const Icon(Icons.emoji_events_outlined),
                  ),
                  IconButton(
                    tooltip: 'Compartir reporte',
                    onPressed: () => context.push(Rutas.datos),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ],
              ),
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
                  accion: FilledButton(onPressed: () => context.go(Rutas.entrenar), child: const Text('Ir a entrenar')),
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
                const EncabezadoSeccion(titulo: 'Tus últimas 12 semanas'),
                _CalendarioActividad(fechas: fechas),
                const SizedBox(height: 24),
                if (sesiones.length >= 2) ...[
                  const EncabezadoSeccion(titulo: 'Evolución del puntaje'),
                  Tarjeta(
                    padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
                    child: _GraficoEvolucion(sesiones: sesiones),
                  ),
                  const SizedBox(height: 24),
                ],
                if (conSensaciones.length >= 2) ...[
                  const EncabezadoSeccion(titulo: 'Esfuerzo y dolor'),
                  Tarjeta(
                    padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
                    child: _GraficoSensaciones(sesiones: conSensaciones),
                  ),
                  const SizedBox(height: 24),
                ],
                _CorreccionesFrecuentes(sesiones: sesiones),
                if (evaluaciones.isNotEmpty) ...[
                  EncabezadoSeccion(
                    titulo: 'Evaluaciones',
                    accion: 'Ver todas',
                    onAccion: () => context.go(Rutas.entrenarEn('evaluaciones')),
                  ),
                  _ResumenEvaluaciones(evaluaciones: evaluaciones),
                  const SizedBox(height: 24),
                ],
                EncabezadoSeccion(titulo: 'Historial', accion: 'Desliza para borrar', onAccion: null),
                ..._historialAgrupado(context, sesiones),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Elimina la sesión con opción de deshacer (la grabación se borra al
  /// cerrarse el aviso sin deshacer).
  Future<void> _eliminar(Sesion s) async {
    final notificador = ref.read(historialProvider.notifier);
    final mensajero = ScaffoldMessenger.of(context);
    await notificador.ocultar(s);
    mensajero.clearSnackBars();
    final razon = await mensajero
        .showSnackBar(
          SnackBar(
            content: const Text('Sesión eliminada'),
            action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
          ),
        )
        .closed;
    if (razon == SnackBarClosedReason.action) {
      await notificador.restaurar(s);
    } else {
      await notificador.borrarAdjuntos(s);
    }
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
          child: Dismissible(
            key: ValueKey('sesion-${s.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: context.paleta.peligroSuave,
                borderRadius: BorderRadius.circular(Medidas.radioL),
              ),
              child: Icon(Icons.delete_outline_rounded, color: context.paleta.peligro),
            ),
            onDismissed: (_) => _eliminar(s),
            child: ItemSesion(
              sesion: s,
              onTap: () => context.push(Rutas.sesion(s.id), extra: s),
            ),
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

/// Calendario tipo mapa de calor: una columna por semana (lunes arriba).
class _CalendarioActividad extends StatelessWidget {
  final List<DateTime> fechas;
  const _CalendarioActividad({required this.fechas});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    const semanas = 12;
    final mapa = mapaActividad(fechas, semanas: semanas);
    final dias = mapa.keys.toList()..sort();
    final hoy = soloDia(DateTime.now());
    final activos = mapa.values.where((v) => v > 0).length;
    Color color(int n) => switch (n) {
      0 => p.superficieAlta,
      1 => p.primario.withValues(alpha: 0.35),
      2 => p.primario.withValues(alpha: 0.65),
      _ => p.primario,
    };
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const etiqueta = 18.0;
              const sep = 4.0;
              final celda = ((c.maxWidth - etiqueta - sep * (semanas - 1)) / semanas).clamp(8.0, 26.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: etiqueta),
                      for (var w = 0; w < semanas; w++) ...[
                        if (w > 0) const SizedBox(width: sep),
                        SizedBox(
                          width: celda,
                          child: Builder(
                            builder: (context) {
                              final lunes = dias[w * 7];
                              final nuevoMes = w == 0 || dias[(w - 1) * 7].month != lunes.month;
                              return Text(
                                nuevoMes ? Formato.mesCorto(lunes.month) : '',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: context.textos.labelSmall?.copyWith(color: p.textoTerciario, fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var d = 0; d < 7; d++) ...[
                    if (d > 0) const SizedBox(height: sep),
                    Row(
                      children: [
                        SizedBox(
                          width: etiqueta,
                          child: Text(
                            d.isEven ? Formato.inicialDia(dias[d]) : '',
                            style: context.textos.labelSmall?.copyWith(color: p.textoTerciario, fontSize: 10),
                          ),
                        ),
                        for (var w = 0; w < semanas; w++) ...[
                          if (w > 0) const SizedBox(width: sep),
                          Builder(
                            builder: (context) {
                              final dia = dias[w * 7 + d];
                              final n = mapa[dia] ?? 0;
                              final futuro = dia.isAfter(hoy);
                              return Tooltip(
                                message:
                                    '${dia.day} ${Formato.mesCorto(dia.month)}: '
                                    '${Formato.plural(n, 'actividad', 'actividades')}',
                                child: Container(
                                  width: celda,
                                  height: celda,
                                  decoration: BoxDecoration(
                                    color: futuro ? Colors.transparent : color(n),
                                    borderRadius: BorderRadius.circular(celda * 0.28),
                                    border: dia == hoy ? Border.all(color: p.primario, width: 1.5) : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Formato.plural(activos, 'día activo', 'días activos')} · mejor racha ${mejorRacha(fechas)}',
                  style: context.textos.bodySmall,
                ),
              ),
              Text('Menos', style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
              for (final n in const [0, 1, 2, 3])
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(color: color(n), borderRadius: BorderRadius.circular(3)),
                ),
              const SizedBox(width: 3),
              Text('Más', style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GraficoSensaciones extends StatelessWidget {
  final List<Sesion> sesiones;
  const _GraficoSensaciones({required this.sesiones});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final orden = sesiones.take(20).toList().reversed.toList();
    LineChartBarData serie(Color color, int Function(Sensaciones s) valor) => LineChartBarData(
      spots: [for (var i = 0; i < orden.length; i++) FlSpot(i.toDouble(), valor(orden[i].sensaciones!).toDouble())],
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 10,
              minX: 0,
              maxX: (orden.length - 1).toDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 5,
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
                    reservedSize: 28,
                    interval: 5,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${v.round()}', style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
                    ),
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [serie(p.primario, (s) => s.esfuerzo), serie(p.peligro, (s) => s.dolor)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Leyenda(color: p.primario, texto: 'Esfuerzo'),
            const SizedBox(width: 18),
            _Leyenda(color: p.peligro, texto: 'Dolor'),
          ],
        ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(texto, style: context.textos.labelMedium),
      ],
    );
  }
}

class _ResumenEvaluaciones extends StatelessWidget {
  final List<EvaluacionFuncional> evaluaciones;
  const _ResumenEvaluaciones({required this.evaluaciones});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final sts = [
      for (final e in evaluaciones)
        if (e.tipo == TipoEvaluacion.sentarsePararse30s) e,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final rom = <String, EvaluacionFuncional>{};
    for (final e in [...evaluaciones]..sort((a, b) => b.fecha.compareTo(a.fecha))) {
      if (e.tipo == TipoEvaluacion.rangoArticular && e.articulacion != null) {
        rom.putIfAbsent('${e.articulacion!.name}-${e.lado?.name}', () => e);
      }
    }
    final maximo = sts.fold<int>(1, (m, e) => (e.repeticiones ?? 0) > m ? e.repeticiones! : m);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sts.isNotEmpty) ...[
            Text('Sentarse y pararse 30 s', style: context.textos.titleSmall),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final e in sts.length > 8 ? sts.sublist(sts.length - 8) : sts)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${e.repeticiones ?? 0}', style: AppTipo.numero(13, p.texto)),
                            const SizedBox(height: 4),
                            Container(
                              height: 8 + 44 * ((e.repeticiones ?? 0) / maximo),
                              decoration: BoxDecoration(
                                color: e.clasificacion == ClasificacionSts30.bajoPromedio ? p.advertencia : p.acento,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${e.fecha.day}/${e.fecha.month}',
                              style: context.textos.labelSmall?.copyWith(color: p.textoTerciario, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (sts.isNotEmpty && rom.isNotEmpty) const Divider(height: 28),
          if (rom.isNotEmpty) ...[
            Text('Rango de movimiento', style: context.textos.titleSmall),
            const SizedBox(height: 8),
            for (final e in rom.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${e.articulacion!.etiqueta} ${e.lado?.etiqueta.toLowerCase() ?? ''}',
                        style: context.textos.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (e.fraccionReferencia ?? 0).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: p.superficieAlta,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${(e.maximo ?? 0).round()}°',
                        textAlign: TextAlign.end,
                        style: AppTipo.numero(15, p.texto),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
