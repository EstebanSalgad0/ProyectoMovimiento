import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/colores.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';

/// Hoja inferior para elegir un ejercicio. Devuelve su id o null.
Future<String?> mostrarSelectorEjercicio(BuildContext context, {String titulo = 'Elige un ejercicio'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => _ListaSelector(titulo: titulo, scroll: scroll),
    ),
  );
}

class _ListaSelector extends ConsumerWidget {
  final String titulo;
  final ScrollController scroll;
  const _ListaSelector({required this.titulo, required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final ejercicios = ref.watch(especificacionProvider).ejercicios;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(titulo, style: context.textos.titleLarge),
        const SizedBox(height: 4),
        Text('El análisis se adapta a cada movimiento.', style: context.textos.bodySmall),
        const SizedBox(height: 16),
        for (final e in ejercicios)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tarjeta(
              padding: const EdgeInsets.all(10),
              onTap: () => Navigator.of(context).pop(e.id),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(width: 60, height: 60, child: IlustracionEjercicio(ejercicioId: e.id)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nombre, style: context.textos.titleSmall),
                        const SizedBox(height: 3),
                        Text(
                          '${Presentacion.categoria(e.categoria)} · ${Presentacion.posicion(e.posicion)} · '
                          '${Presentacion.vista(e.vistaRecomendada).toLowerCase()}',
                          style: context.textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.textoTerciario),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
