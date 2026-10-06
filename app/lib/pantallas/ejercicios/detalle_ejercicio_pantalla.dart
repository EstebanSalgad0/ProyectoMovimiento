import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/resultado_analisis.dart';
import '../../rutas.dart';

class DetalleEjercicioPantalla extends ConsumerWidget {
  final String ejercicioId;

  const DetalleEjercicioPantalla({super.key, required this.ejercicioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final e = ref.watch(especificacionProvider).buscar(ejercicioId);
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ejercicio no encontrado')),
      );
    }
    final soloVista = e.verificaciones.where((v) => v.vistas != null).isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 330,
            backgroundColor: p.fondo,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: p.superficie.withValues(alpha: 0.9)),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver',
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'ilustracion-${e.id}',
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: IlustracionEjercicio(ejercicioId: e.id, animada: true),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 20, Medidas.margen, 24),
            sliver: SliverList.list(
              children: [
                Text(e.nombre, style: context.textos.headlineMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChipDato(
                      texto: Presentacion.categoria(e.categoria),
                      icono: Presentacion.iconoCategoria(e.categoria),
                      color: p.primario,
                      fondo: p.primarioSuave,
                    ),
                    ChipDato(texto: Presentacion.posicion(e.posicion), icono: Icons.event_seat_outlined),
                    ChipDato(texto: Presentacion.dificultad(e.dificultad), icono: Icons.signal_cellular_alt_rounded),
                    ChipDato(texto: '${e.objetivoRepeticiones} reps.', icono: Icons.repeat_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                Text(e.descripcion, style: context.textos.bodyLarge?.copyWith(color: p.textoSecundario)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final m in e.musculos) ChipDato(texto: m, fondo: p.acentoSuave, color: p.acento)],
                ),
                const SizedBox(height: 28),

                const EncabezadoSeccion(titulo: 'Cómo hacerlo'),
                Tarjeta(
                  child: Column(
                    children: [
                      for (var i = 0; i < e.pasos.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == e.pasos.length - 1 ? 0 : 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: p.primarioSuave, shape: BoxShape.circle),
                                child: Text('${i + 1}', style: context.textos.labelMedium?.copyWith(color: p.primario)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(e.pasos[i], style: context.textos.bodyMedium),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const EncabezadoSeccion(titulo: 'Ubicación de la cámara'),
                Tarjeta(
                  color: p.infoSuave,
                  colorBorde: p.infoSuave,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconoCaja(
                        icono: Presentacion.iconoVista(e.vistaRecomendada),
                        color: p.info,
                        fondo: p.superficie,
                        tamano: 42,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recomendado: ${Presentacion.vista(e.vistaRecomendada).toLowerCase()}',
                              style: context.textos.titleSmall?.copyWith(color: p.info),
                            ),
                            const SizedBox(height: 4),
                            Text(e.camara, style: context.textos.bodySmall?.copyWith(color: p.texto)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const EncabezadoSeccion(titulo: 'Qué detecta la IA'),
                Tarjeta(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final v in e.verificaciones)
                        ListTile(
                          leading: Icon(Presentacion.iconoZona(v.zona, v.codigo)),
                          title: Text(v.titulo),
                          subtitle: v.vistas == null
                              ? null
                              : Text('Solo ${Presentacion.vista(v.vistas!.first).toLowerCase()}'),
                          trailing: _PuntoSeveridad(severidad: Severidad.desde(v.severidad)),
                        ),
                    ],
                  ),
                ),
                if (soloVista) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Algunas revisiones dependen del ángulo de la cámara; el análisis te avisará si conviene grabar de otra forma.',
                    style: context.textos.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Medidas.margen, 12, Medidas.margen, 8),
          decoration: BoxDecoration(
            color: p.superficie,
            border: Border(top: BorderSide(color: p.borde)),
          ),
          child: Row(
            children: [
              Expanded(
                child: BotonPrincipal(
                  texto: 'Video',
                  icono: Icons.video_library_outlined,
                  variante: VarianteBoton.secundario,
                  onPressed: () => context.push(Rutas.preparacionDe(e.id)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BotonPrincipal(
                  texto: 'Tiempo real',
                  icono: Icons.videocam_rounded,
                  onPressed: () => context.push(Rutas.tiempoRealDe(e.id)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuntoSeveridad extends StatelessWidget {
  final Severidad severidad;
  const _PuntoSeveridad({required this.severidad});

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = Presentacion.coloresSeveridad(context.paleta, severidad);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(40)),
      child: Text(severidad.etiqueta, style: context.textos.labelSmall?.copyWith(color: color)),
    );
  }
}
