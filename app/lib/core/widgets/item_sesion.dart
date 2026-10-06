import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../tema/colores.dart';
import '../utils/formato.dart';
import 'ilustracion_ejercicio.dart';
import 'insignia_estado.dart';
import 'tarjeta.dart';

/// Fila del historial: ilustración, ejercicio, fecha, repeticiones y puntaje.
class ItemSesion extends ConsumerWidget {
  final Sesion sesion;
  final VoidCallback? onTap;

  const ItemSesion({super.key, required this.sesion, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final spec = ref.watch(especificacionProvider).buscar(sesion.ejercicio);
    final nombre = spec?.nombre ?? sesion.resultado.nombreEjercicio ?? sesion.ejercicio.replaceAll('_', ' ');
    final reps = sesion.resultado.numeroRepeticiones;
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 56, height: 56, child: IlustracionEjercicio(ejercicioId: sesion.ejercicio)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      sesion.origen == OrigenSesion.tiempoReal ? Icons.bolt_rounded : Icons.movie_rounded,
                      size: 14,
                      color: p.textoTerciario,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        [
                          Formato.fechaRelativa(sesion.fecha),
                          if (reps > 0) Formato.plural(reps, 'rep.', 'reps.'),
                        ].join(' · '),
                        style: context.textos.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InsigniaPuntaje(puntaje: sesion.puntaje, tamano: 44),
        ],
      ),
    );
  }
}
