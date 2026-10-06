import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/item_sesion.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';
import '../ejercicios/selector_ejercicio.dart';

class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key});

  Future<void> _entrenar(BuildContext context) async {
    final id = await mostrarSelectorEjercicio(context, titulo: '¿Qué vas a entrenar?');
    if (id != null && context.mounted) context.push(Rutas.tiempoRealDe(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final usuario = ref.watch(authProvider);
    final historial = ref.watch(historialProvider);
    final sesiones = historial.value ?? const <Sesion>[];
    final resumen = Resumen.desde(sesiones);
    final ejercicios = ref.watch(especificacionProvider).ejercicios;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(historialProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 12, Medidas.margen, 32),
            children: [
              // Saludo
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Formato.saludo(), style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario)),
                        const SizedBox(height: 2),
                        Text(usuario?.primerNombre ?? 'Hola', style: context.textos.headlineSmall),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Ir a mi cuenta',
                    child: InkWell(
                      onTap: () => context.go(Rutas.cuenta),
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: p.primarioSuave,
                        child: Text(
                          usuario?.iniciales ?? '?',
                          style: context.textos.titleSmall?.copyWith(color: p.primario),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta principal
              _TarjetaEntrenar(onTiempoReal: () => _entrenar(context), onVideo: () => context.push(Rutas.preparacion)),
              const SizedBox(height: 16),

              // Indicadores
              Row(
                children: [
                  Expanded(
                    child: TileEstadistica(
                      icono: Icons.calendar_today_rounded,
                      valor: '${resumen.sesionesSemana}',
                      etiqueta: 'Esta semana',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TileEstadistica(
                      icono: Icons.speed_rounded,
                      valor: resumen.promedio == null ? '—' : Formato.numero(resumen.promedio!, 0),
                      etiqueta: 'Promedio',
                      color: p.acento,
                      fondo: p.acentoSuave,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TileEstadistica(
                      icono: Icons.local_fire_department_rounded,
                      valor: '${resumen.racha}',
                      etiqueta: resumen.racha == 1 ? 'Día de racha' : 'Días de racha',
                      color: p.advertencia,
                      fondo: p.advertenciaSuave,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TuSemana(porDia: resumen.sesionesPorDia),
              const SizedBox(height: 26),

              EncabezadoSeccion(
                titulo: 'Ejercicios',
                accion: 'Ver todos',
                onAccion: () => context.go(Rutas.ejercicios),
              ),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: ejercicios.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final e = ejercicios[i];
                    return SizedBox(
                      width: 140,
                      child: Tarjeta(
                        padding: EdgeInsets.zero,
                        onTap: () => context.push(Rutas.ejercicio(e.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(Medidas.radioL)),
                                child: IlustracionEjercicio(ejercicioId: e.id),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.nombre,
                                    style: context.textos.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(Presentacion.categoria(e.categoria), style: context.textos.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),

              EncabezadoSeccion(
                titulo: 'Actividad reciente',
                accion: sesiones.isEmpty ? null : 'Ver todo',
                onAccion: () => context.go(Rutas.progreso),
              ),
              if (historial.isLoading && sesiones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sesiones.isEmpty)
                EstadoVacio(
                  icono: Icons.directions_run_rounded,
                  titulo: 'Aún no tienes sesiones',
                  mensaje: 'Haz tu primer análisis en tiempo real o sube un video para ver tus resultados aquí.',
                  accion: FilledButton.icon(
                    onPressed: () => _entrenar(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Comenzar'),
                  ),
                )
              else
                for (final s in sesiones.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ItemSesion(
                      sesion: s,
                      onTap: () => context.push(Rutas.sesion(s.id), extra: s),
                    ),
                  ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: p.textoTerciario),
                  const SizedBox(width: 8),
                  Expanded(child: Text(AppConfig.avisoMedico, style: context.textos.bodySmall)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaEntrenar extends StatelessWidget {
  final VoidCallback onTiempoReal;
  final VoidCallback onVideo;

  const _TarjetaEntrenar({required this.onTiempoReal, required this.onVideo});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      decoration: BoxDecoration(gradient: p.gradiente, borderRadius: BorderRadius.circular(Medidas.radioXL)),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColores.blanco.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColores.blanco),
                          const SizedBox(width: 4),
                          Text(
                            'IA en tu teléfono',
                            style: context.textos.labelSmall?.copyWith(color: AppColores.blanco),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Entrena con correcciones al instante',
                      style: context.textos.titleLarge?.copyWith(color: AppColores.blanco),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuenta tus repeticiones y evalúa tu técnica con la cámara.',
                      style: context.textos.bodySmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 86,
                height: 120,
                child: IlustracionEjercicio(
                  ejercicioId: 'sentadilla',
                  animada: true,
                  conFondo: false,
                  color: AppColores.blanco,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: onTiempoReal,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColores.blanco,
                    foregroundColor: AppColores.marino,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Comenzar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onVideo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.blanco,
                    side: BorderSide(color: AppColores.blanco.withValues(alpha: 0.5)),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.video_library_outlined, size: 19),
                  label: const Text('Video'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TuSemana extends StatelessWidget {
  final List<int> porDia;
  const _TuSemana({required this.porDia});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final hoy = DateTime.now();
    final maximo = porDia.fold<int>(1, (m, v) => v > m ? v : m);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tu semana', style: context.textos.titleSmall),
              const Spacer(),
              Text(
                Formato.plural(porDia.reduce((a, b) => a + b), 'sesión', 'sesiones'),
                style: context.textos.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (porDia[i] > 0)
                          Text('${porDia[i]}', style: context.textos.labelSmall?.copyWith(color: p.textoSecundario)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          width: 22,
                          height: 8 + 44 * (porDia[i] / maximo),
                          decoration: BoxDecoration(
                            color: porDia[i] > 0
                                ? (i == 6 ? p.primario : p.primario.withValues(alpha: 0.45))
                                : p.superficieAlta,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Formato.inicialDia(hoy.subtract(Duration(days: 6 - i))),
                          style: context.textos.labelSmall?.copyWith(color: i == 6 ? p.primario : p.textoTerciario),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
