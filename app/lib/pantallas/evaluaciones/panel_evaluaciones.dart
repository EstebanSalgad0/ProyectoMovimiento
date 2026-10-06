import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/evaluacion.dart';
import '../../rutas.dart';

/// Pruebas funcionales disponibles y su historial (sección de Entrenar).
class PanelEvaluaciones extends ConsumerWidget {
  const PanelEvaluaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final todas = [...?ref.watch(evaluacionesProvider).value]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final sts = todas.where((e) => e.tipo == TipoEvaluacion.sentarsePararse30s).firstOrNull;
    final ultimaPorArticulacion = <Articulacion, EvaluacionFuncional>{};
    for (final e in todas.where((e) => e.tipo == TipoEvaluacion.rangoArticular && e.articulacion != null)) {
      ultimaPorArticulacion.putIfAbsent(e.articulacion!, () => e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 32),
      children: [
        Tarjeta(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconoCaja(icono: Icons.event_seat_rounded, color: p.acento, fondo: p.acentoSuave),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sentarse y pararse 30 s', style: context.textos.titleSmall),
                        const SizedBox(height: 2),
                        Text('Fuerza de piernas y riesgo de caídas', style: context.textos.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (sts != null)
                Row(
                  children: [
                    Text('${sts.repeticiones ?? 0}', style: AppTipo.numero(30, p.texto)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(sts.clasificacion ?? ClasificacionSts30.sinReferencia).etiqueta}\n'
                        '${Formato.fechaRelativa(sts.fecha)}',
                        style: context.textos.bodySmall,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Cuenta cuántas veces te pones de pie en 30 segundos y compara con tu grupo de edad.',
                  style: context.textos.bodySmall,
                ),
              const SizedBox(height: 14),
              BotonPrincipal(
                texto: sts == null ? 'Hacer la prueba' : 'Repetir la prueba',
                icono: Icons.timer_outlined,
                variante: VarianteBoton.suave,
                onPressed: () => context.push(Rutas.pruebaSts),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Tarjeta(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconoCaja(icono: Icons.architecture_rounded, color: p.primario, fondo: p.primarioSuave),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Goniómetro', style: context.textos.titleSmall),
                        const SizedBox(height: 2),
                        Text('Mide el rango de movimiento de una articulación', style: context.textos.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final a in Articulacion.values) ...[
                    if (a != Articulacion.values.first) const SizedBox(width: 8),
                    Expanded(
                      child: _Articulacion(articulacion: a, ultima: ultimaPorArticulacion[a]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EncabezadoSeccion(titulo: 'Historial', accion: todas.isEmpty ? null : '${todas.length}', onAccion: null),
        if (todas.isEmpty)
          Text('Tus pruebas aparecerán aquí para que puedas comparar con el tiempo.', style: context.textos.bodySmall)
        else
          for (final e in todas) ...[ItemEvaluacion(evaluacion: e), const SizedBox(height: 8)],
      ],
    );
  }
}

class _Articulacion extends StatelessWidget {
  final Articulacion articulacion;
  final EvaluacionFuncional? ultima;
  const _Articulacion({required this.articulacion, this.ultima});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Material(
      color: p.superficieAlta,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Rutas.goniometroDe(articulacion)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  ultima?.maximo == null ? '—' : '${ultima!.maximo!.round()}°',
                  style: AppTipo.numero(20, ultima == null ? p.textoTerciario : p.texto),
                ),
              ),
              const SizedBox(height: 2),
              Text(articulacion.etiqueta, style: context.textos.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila del historial de evaluaciones; se elimina deslizando.
class ItemEvaluacion extends ConsumerWidget {
  final EvaluacionFuncional evaluacion;
  const ItemEvaluacion({super.key, required this.evaluacion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final e = evaluacion;
    final esSts = e.tipo == TipoEvaluacion.sentarsePararse30s;
    final titulo = esSts
        ? 'Sentarse y pararse 30 s'
        : '${e.articulacion?.etiqueta ?? 'Articulación'} ${e.lado?.etiqueta.toLowerCase() ?? ''}'.trim();
    final valor = esSts ? '${e.repeticiones ?? 0}' : '${(e.maximo ?? 0).round()}°';
    final detalle = esSts
        ? (e.clasificacion ?? ClasificacionSts30.sinReferencia).etiqueta
        : '${((e.fraccionReferencia ?? 0) * 100).round()} % de la referencia';
    return Dismissible(
      key: ValueKey('eval-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: p.peligroSuave, borderRadius: BorderRadius.circular(Medidas.radioL)),
        child: Icon(Icons.delete_outline_rounded, color: p.peligro),
      ),
      onDismissed: (_) {
        ref.read(evaluacionesProvider.notifier).eliminar(e);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Evaluación eliminada'),
              action: SnackBarAction(
                label: 'Deshacer',
                onPressed: () => ref.read(evaluacionesProvider.notifier).agregar(e),
              ),
            ),
          );
      },
      child: Tarjeta(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        onTap: esSts && e.sesionId != null ? () => context.push(Rutas.sesion(e.sesionId!)) : null,
        child: Row(
          children: [
            IconoCaja(
              icono: esSts ? Icons.event_seat_rounded : Icons.architecture_rounded,
              color: esSts ? p.acento : p.primario,
              fondo: esSts ? p.acentoSuave : p.primarioSuave,
              tamano: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${Formato.fechaRelativa(e.fecha)} · $detalle',
                    style: context.textos.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(valor, style: AppTipo.numero(20, p.texto)),
          ],
        ),
      ),
    );
  }
}
