import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/rutina.dart';
import '../../rutas.dart';

/// Rutinas predefinidas y propias (sección de Entrenar).
class ListaRutinas extends ConsumerWidget {
  const ListaRutinas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final propias = ref.watch(rutinasPropiasProvider);
    final usuario = ref.watch(authProvider);
    final sugerida = idRutinaSugerida(usuario?.objetivo, usuario?.edad);
    final predefinidas = [...rutinasPredefinidas]
      ..sort((a, b) => (a.id == sugerida ? 0 : 1).compareTo(b.id == sugerida ? 0 : 1));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 32),
      children: [
        Material(
          color: p.primarioSuave,
          borderRadius: BorderRadius.circular(Medidas.radioL),
          child: InkWell(
            onTap: () => context.push(Rutas.rutinaNueva),
            borderRadius: BorderRadius.circular(Medidas.radioL),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconoCaja(icono: Icons.add_rounded, color: p.sobrePrimario, fondo: p.primario),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crear rutina', style: context.textos.titleSmall?.copyWith(color: p.primario)),
                        const SizedBox(height: 2),
                        Text('Elige ejercicios, series, repeticiones y descansos.', style: context.textos.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.primario),
                ],
              ),
            ),
          ),
        ),
        if (propias.isNotEmpty) ...[
          const SizedBox(height: 24),
          const EncabezadoSeccion(titulo: 'Mis rutinas'),
          for (final r in propias) ...[TarjetaRutina(rutina: r), const SizedBox(height: 12)],
        ],
        const SizedBox(height: 24),
        const EncabezadoSeccion(titulo: 'Recomendadas'),
        for (final r in predefinidas) ...[
          TarjetaRutina(rutina: r, sugerida: r.id == sugerida),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class TarjetaRutina extends ConsumerWidget {
  final Rutina rutina;
  final bool sugerida;
  final bool compacta;

  const TarjetaRutina({super.key, required this.rutina, this.sugerida = false, this.compacta = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final spec = ref.watch(especificacionProvider);
    final ids = <String>{
      for (final i in rutina.items)
        if (spec.buscar(i.ejercicioId) != null) i.ejercicioId,
    }.toList();
    return Tarjeta(
      onTap: () => context.push(Rutas.rutina(rutina.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _MiniaturasEjercicios(ids: ids),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sugerida) ...[
                  Text('SUGERIDA PARA TI', style: context.textos.labelSmall?.copyWith(color: p.acento)),
                  const SizedBox(height: 2),
                ],
                Text(rutina.nombre, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (!compacta && rutina.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rutina.descripcion,
                    style: context.textos.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${ids.length} ${ids.length == 1 ? 'ejercicio' : 'ejercicios'} · ${rutina.totalSeries} series · '
                  '~${rutina.minutosEstimados} min',
                  style: context.textos.labelMedium?.copyWith(color: p.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Comenzar ${rutina.nombre}',
            onPressed: ids.isEmpty ? null : () => context.push(Rutas.sesionGuiada(rutina.id)),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

/// Hasta tres ilustraciones superpuestas de los ejercicios de una rutina.
class _MiniaturasEjercicios extends StatelessWidget {
  final List<String> ids;
  const _MiniaturasEjercicios({required this.ids});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final visibles = ids.take(3).toList();
    const tamano = 46.0;
    const desplazamiento = 14.0;
    return SizedBox(
      width: tamano + desplazamiento * 2,
      height: tamano + desplazamiento,
      child: Stack(
        children: [
          for (var i = visibles.length - 1; i >= 0; i--)
            Positioned(
              left: i * desplazamiento,
              top: i * desplazamiento / 2,
              child: Container(
                width: tamano,
                height: tamano,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.superficie, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: IlustracionEjercicio(ejercicioId: visibles[i]),
              ),
            ),
        ],
      ),
    );
  }
}
