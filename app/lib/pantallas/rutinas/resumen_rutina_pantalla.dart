import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/hoja_sensaciones.dart';
import '../../core/widgets/insignia_estado.dart';
import '../../core/widgets/item_sesion.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';

/// Resumen de una ejecución de rutina: series hechas, repeticiones, puntaje
/// por ejercicio y cómo se sintió la persona.
class ResumenRutinaPantalla extends ConsumerWidget {
  final String ejecucionId;

  const ResumenRutinaPantalla({super.key, required this.ejecucionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final todas = ref.watch(historialProvider).value ?? const <Sesion>[];
    final series = [
      for (final s in todas)
        if (s.rutina?.ejecucionId == ejecucionId) s,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));

    if (series.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No encontramos esta rutina')),
      );
    }
    final contexto = series.first.rutina!;
    final completa = series.length >= contexto.totalSeries;
    final reps = series.fold(0, (t, s) => t + s.resultado.numeroRepeticiones);
    final promedio = (series.fold(0, (t, s) => t + s.puntaje) / series.length).round();
    final duracion =
        series.last.fecha.difference(series.first.fecha) +
        Duration(milliseconds: ((series.first.resultado.duracionS ?? 0) * 1000).round());
    final spec = ref.watch(especificacionProvider);

    // Agrupa por ejercicio, en el orden en que se hicieron.
    final porEjercicio = <String, List<Sesion>>{};
    for (final s in series) {
      porEjercicio.putIfAbsent(s.ejercicio, () => []).add(s);
    }
    final sensaciones = series.first.sensaciones;

    Future<void> registrarSensaciones() async {
      final nuevas = await mostrarHojaSensaciones(
        context,
        inicial: sensaciones,
        subtitulo: 'Se guardará en las ${series.length} series de esta rutina.',
      );
      if (nuevas != null) {
        await ref.read(historialProvider.notifier).guardarSensaciones(series.map((s) => s.id), nuevas);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
          onPressed: () => context.canPop() ? context.pop() : context.go(Rutas.inicio),
        ),
        title: const Text('Resumen de la rutina'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: p.gradiente, borderRadius: BorderRadius.circular(Medidas.radioXL)),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, e, child) => Transform.scale(scale: e, child: child),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColores.blanco.withValues(alpha: 0.16)),
                    child: Icon(
                      completa ? Icons.emoji_events_rounded : Icons.flag_rounded,
                      color: AppColores.blanco,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  completa ? '¡Rutina completada!' : 'Rutina terminada',
                  style: context.textos.headlineSmall?.copyWith(color: AppColores.blanco),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${contexto.rutinaNombre} · ${Formato.fechaRelativa(series.first.fecha)}',
                  style: context.textos.bodyMedium?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _DatoHero(valor: '${series.length}/${contexto.totalSeries}', etiqueta: 'Series'),
                    _DatoHero(valor: '$reps', etiqueta: 'Repeticiones'),
                    _DatoHero(valor: Formato.cronometro(duracion), etiqueta: 'Duración'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TileEstadistica(icono: Icons.star_rounded, valor: '$promedio', etiqueta: 'Técnica promedio'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TileEstadistica(
                  icono: Icons.fitness_center_rounded,
                  valor: '${porEjercicio.length}',
                  etiqueta: porEjercicio.length == 1 ? 'Ejercicio' : 'Ejercicios',
                  color: p.acento,
                  fondo: p.acentoSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TarjetaSensaciones(sensaciones: sensaciones, onEditar: registrarSensaciones),
          const SizedBox(height: 24),
          const EncabezadoSeccion(titulo: 'Por ejercicio'),
          for (final entrada in porEjercicio.entries) ...[
            Tarjeta(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.buscar(entrada.key)?.nombre ?? entrada.key.replaceAll('_', ' '),
                          style: context.textos.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${Formato.plural(entrada.value.length, 'serie', 'series')} · '
                          '${Formato.plural(entrada.value.fold(0, (t, s) => t + s.resultado.numeroRepeticiones), 'repetición', 'repeticiones')}',
                          style: context.textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  for (final s in entrada.value) ...[
                    const SizedBox(width: 6),
                    InsigniaPuntaje(puntaje: s.puntaje, tamano: 36),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const EncabezadoSeccion(titulo: 'Detalle de cada serie'),
          for (final s in series) ...[
            ItemSesion(
              sesion: s,
              onTap: () => context.push(Rutas.sesion(s.id), extra: s),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: 'Volver al inicio',
            icono: Icons.home_rounded,
            onPressed: () => context.go(Rutas.inicio),
          ),
        ],
      ),
    );
  }
}

class _DatoHero extends StatelessWidget {
  final String valor;
  final String etiqueta;
  const _DatoHero({required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor, style: AppTipo.numero(24, AppColores.blanco)),
          ),
          const SizedBox(height: 2),
          Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
