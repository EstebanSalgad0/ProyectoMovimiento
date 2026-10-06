import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/insignia_estado.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/rutina.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';

class DetalleRutinaPantalla extends ConsumerWidget {
  final String rutinaId;

  const DetalleRutinaPantalla({super.key, required this.rutinaId});

  Future<void> _duplicar(BuildContext context, WidgetRef ref, Rutina r) async {
    final copia = Rutina(
      id: Rutina.nuevoId(),
      nombre: '${r.nombre} (mía)',
      descripcion: r.descripcion,
      items: r.items,
      nivel: r.nivel,
    );
    await ref.read(rutinasPropiasProvider.notifier).guardar(copia);
    if (context.mounted) context.pushReplacement(Rutas.editarRutina(copia.id));
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Rutina r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar la rutina?'),
        content: Text('«${r.nombre}» se eliminará. Las sesiones que ya hiciste se mantienen en tu historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(rutinasPropiasProvider.notifier).eliminar(r.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final r = buscarRutina(ref.watch(todasLasRutinasProvider), rutinaId);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No encontramos esta rutina')),
      );
    }
    final spec = ref.watch(especificacionProvider);

    // Ejecuciones anteriores de esta rutina (una por ejecucionId).
    final ejecuciones = <String, List<Sesion>>{};
    for (final s in ref.watch(historialProvider).value ?? const <Sesion>[]) {
      final c = s.rutina;
      if (c != null && c.rutinaId == r.id) ejecuciones.putIfAbsent(c.ejecucionId, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.predefinida ? 'Rutina recomendada' : 'Mi rutina'),
        actions: [
          if (r.predefinida)
            IconButton(
              tooltip: 'Duplicar y editar',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => _duplicar(context, ref, r),
            )
          else ...[
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Rutas.editarRutina(r.id)),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _eliminar(context, ref, r),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: p.gradiente, borderRadius: BorderRadius.circular(Medidas.radioXL)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nombre, style: context.textos.headlineSmall?.copyWith(color: AppColores.blanco)),
                if (r.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    r.descripcion,
                    style: context.textos.bodyMedium?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Dato(valor: '${r.items.length}', etiqueta: 'Ejercicios'),
                    _Dato(valor: '${r.totalSeries}', etiqueta: 'Series'),
                    _Dato(valor: '${r.totalRepeticiones}', etiqueta: 'Reps.'),
                    _Dato(valor: '~${r.minutosEstimados}', etiqueta: 'Minutos'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion(titulo: 'Ejercicios'),
          for (var i = 0; i < r.items.length; i++) ...[
            Builder(
              builder: (context) {
                final item = r.items[i];
                final e = spec.buscar(item.ejercicioId);
                return Tarjeta(
                  padding: const EdgeInsets.all(12),
                  onTap: e == null ? null : () => context.push(Rutas.ejercicio(e.id)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: IlustracionEjercicio(ejercicioId: item.ejercicioId),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e?.nombre ?? 'Ejercicio no disponible',
                              style: context.textos.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.series} × ${item.repeticiones} reps. · descanso ${item.descansoS} s',
                              style: context.textos.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text('${i + 1}', style: AppTipo.numero(18, p.textoTerciario)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Tarjeta(
            color: p.infoSuave,
            colorBorde: p.infoSuave,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: p.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La app cuenta tus repeticiones y pasa sola a la siguiente serie. Deja el teléfono apoyado '
                    'donde se vea todo tu cuerpo; al cambiar de ejercicio te dirá cómo ubicarlo.',
                    style: context.textos.bodySmall?.copyWith(color: p.texto),
                  ),
                ),
              ],
            ),
          ),
          if (ejecuciones.isNotEmpty) ...[
            const SizedBox(height: 24),
            const EncabezadoSeccion(titulo: 'Veces que la hiciste'),
            for (final entrada in ejecuciones.entries.take(5)) ...[
              Builder(
                builder: (context) {
                  final series = entrada.value;
                  final promedio = (series.fold(0, (t, s) => t + s.puntaje) / series.length).round();
                  return Tarjeta(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    onTap: () => context.push(Rutas.ejecucion(entrada.key)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Formato.fechaRelativa(series.first.fecha), style: context.textos.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                '${series.length} de ${series.first.rutina!.totalSeries} series',
                                style: context.textos.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        InsigniaPuntaje(puntaje: promedio, tamano: 40),
                        Icon(Icons.chevron_right_rounded, color: p.textoTerciario),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Medidas.margen, 12, Medidas.margen, 8),
          decoration: BoxDecoration(
            color: p.superficie,
            border: Border(top: BorderSide(color: p.borde)),
          ),
          child: BotonPrincipal(
            texto: 'Comenzar rutina',
            icono: Icons.play_arrow_rounded,
            onPressed: r.items.isEmpty ? null : () => context.push(Rutas.sesionGuiada(r.id)),
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String valor;
  final String etiqueta;
  const _Dato({required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: AppTipo.numero(22, AppColores.blanco)),
          Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
