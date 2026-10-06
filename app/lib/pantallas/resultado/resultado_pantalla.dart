import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/anillo_puntaje.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/hoja_sensaciones.dart';
import '../../core/widgets/insignia_estado.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/resultado_analisis.dart';
import '../../modelos/sesion.dart';
import '../../motor/especificacion.dart';
import '../../rutas.dart';
import 'componentes_resultado.dart';

class ResultadoPantalla extends ConsumerWidget {
  final String sesionId;
  final Sesion? sesionInicial;
  final bool esNueva;

  const ResultadoPantalla({super.key, required this.sesionId, this.sesionInicial, this.esNueva = false});

  /// Línea objetivo del gráfico: la verificación de pico sobre la señal principal.
  double? _objetivo(EjercicioSpec? e) {
    if (e == null) return null;
    for (final v in e.verificaciones) {
      if ((v.tipo == 'pico_max' || v.tipo == 'pico_min') && v.metrica == e.senal.metrica) return v.umbral;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialProvider).value ?? const <Sesion>[];
    Sesion? sesion = sesionInicial;
    for (final s in historial) {
      if (s.id == sesionId) sesion = s;
    }
    if (sesion == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No encontramos esta sesión')),
      );
    }
    final s = sesion;
    final r = s.resultado;
    final spec = ref.watch(especificacionProvider).buscar(s.ejercicio);
    final nombre = spec?.nombre ?? r.nombreEjercicio ?? s.ejercicio.replaceAll('_', ' ');
    final p = context.paleta;

    // Sesión anterior del mismo ejercicio para comparar.
    Sesion? anterior;
    for (final h in historial) {
      if (h.id != s.id && h.ejercicio == s.ejercicio && h.fecha.isBefore(s.fecha)) {
        if (anterior == null || h.fecha.isAfter(anterior.fecha)) anterior = h;
      }
    }

    final reps = r.numeroRepeticiones;
    final incompletas = (r.metricas['repeticiones_incompletas'] ?? 0).round();
    final unidad = spec?.senal.unidad ?? '°';
    final correcciones = r.hallazgos.where((h) => h.severidad != Severidad.info).toList();
    final sugerencias = r.hallazgos.where((h) => h.severidad == Severidad.info).toList();

    void salir() => esNueva ? context.go(Rutas.inicio) : context.pop();

    Future<void> registrarSensaciones() async {
      final nuevas = await mostrarHojaSensaciones(context, inicial: s.sensaciones);
      if (nuevas != null) await ref.read(historialProvider.notifier).guardarSensaciones([s.id], nuevas);
    }

    Future<void> eliminar() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar esta sesión?'),
          content: const Text('Se borrará del historial junto con su grabación.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(historialProvider.notifier).eliminar(s);
      if (context.mounted) salir();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(esNueva ? Icons.close_rounded : Icons.arrow_back_rounded),
          tooltip: esNueva ? 'Cerrar' : 'Volver',
          onPressed: salir,
        ),
        title: Text(esNueva ? 'Tu resultado' : 'Detalle de sesión'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) {
              if (v == 'eliminar') eliminar();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'eliminar',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Eliminar sesión'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          // Resumen principal
          Tarjeta(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    AnilloPuntaje(puntaje: s.puntaje, tamano: 124, grosor: 11, animar: esNueva),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InsigniaEstado(estado: s.estado),
                          const SizedBox(height: 8),
                          Text(nombre, style: context.textos.titleLarge),
                          const SizedBox(height: 6),
                          Text(
                            Presentacion.mensajePuntaje(s.puntaje, reps),
                            style: context.textos.bodySmall?.copyWith(color: p.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChipDato(
                      texto: s.origen.etiqueta,
                      icono: s.origen == OrigenSesion.tiempoReal ? Icons.bolt_rounded : Icons.movie_rounded,
                    ),
                    ChipDato(texto: Formato.fechaRelativa(s.fecha), icono: Icons.schedule_rounded),
                    if (anterior != null) _ChipComparacion(diferencia: s.puntaje - anterior.puntaje),
                    if (s.rutina != null)
                      GestureDetector(
                        onTap: () => context.push(Rutas.ejecucion(s.rutina!.ejecucionId)),
                        child: ChipDato(
                          texto: '${s.rutina!.rutinaNombre} · serie ${s.rutina!.serie}/${s.rutina!.totalSeries}',
                          icono: Icons.playlist_play_rounded,
                          color: p.acento,
                          fondo: p.acentoSuave,
                        ),
                      ),
                  ],
                ),
                if (s.tieneEsqueleto || s.videoRuta != null) ...[
                  const SizedBox(height: 16),
                  BotonPrincipal(
                    texto: s.videoRuta != null ? 'Ver video con esqueleto' : 'Revisar movimiento',
                    icono: Icons.slow_motion_video_rounded,
                    variante: VarianteBoton.suave,
                    onPressed: () => context.push(Rutas.revision(s.id)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TarjetaSensaciones(sensaciones: s.sensaciones, onEditar: registrarSensaciones),
          const SizedBox(height: 14),

          // Indicadores
          if (r.esV2) ...[
            Row(
              children: [
                Expanded(
                  child: TileEstadistica(
                    icono: Icons.repeat_rounded,
                    valor: '$reps',
                    etiqueta: incompletas > 0 ? '+$incompletas incompletas' : 'Repeticiones',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TileEstadistica(
                    icono: Icons.straighten_rounded,
                    valor: r.metricas['rango_promedio'] == null
                        ? '—'
                        : '${Formato.numero(r.metricas['rango_promedio']!, 0)}$unidad',
                    etiqueta: 'Rango prom.',
                    color: p.acento,
                    fondo: p.acentoSuave,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TileEstadistica(
                    icono: Icons.timer_outlined,
                    valor: r.metricas['duracion_rep_promedio_s'] == null
                        ? '—'
                        : Formato.segundos(r.metricas['duracion_rep_promedio_s']!),
                    etiqueta: 'Por rep.',
                    color: p.info,
                    fondo: p.infoSuave,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Gráfico
          if (r.serie != null && r.serie!.tieneDatos) ...[
            EncabezadoSeccion(titulo: '${r.serie!.nombre} durante la sesión'),
            Tarjeta(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: GraficoSenal(serie: r.serie!, repeticiones: r.repeticiones, objetivo: _objetivo(spec)),
            ),
            const SizedBox(height: 24),
          ],

          // Repeticiones
          if (r.repeticiones.isNotEmpty) ...[
            EncabezadoSeccion(titulo: 'Por repetición', accion: 'Toca para ver detalle', onAccion: null),
            SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: r.repeticiones.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => ChipRepeticion(
                  rep: r.repeticiones[i],
                  onTap: () => mostrarDetalleRepeticion(context, r.repeticiones[i], spec),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Correcciones
          if (correcciones.isNotEmpty) ...[
            const EncabezadoSeccion(titulo: 'Para mejorar'),
            for (final h in correcciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaHallazgo(hallazgo: h),
              ),
            const SizedBox(height: 14),
          ],

          // Aciertos
          if (r.aciertos.isNotEmpty) ...[
            const EncabezadoSeccion(titulo: 'Lo que hiciste bien'),
            Tarjeta(
              child: Column(
                children: [
                  for (var i = 0; i < r.aciertos.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == r.aciertos.length - 1 ? 0 : 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, color: p.exito, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(r.aciertos[i].mensaje, style: context.textos.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Sugerencias y calidad del registro
          if (sugerencias.isNotEmpty) ...[
            const EncabezadoSeccion(titulo: 'Sugerencias'),
            for (final h in sugerencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaHallazgo(hallazgo: h),
              ),
            const SizedBox(height: 14),
          ],
          if (r.calidad != null) ...[
            const EncabezadoSeccion(titulo: 'Calidad del registro'),
            _TarjetaCalidad(calidad: r.calidad!, duracionS: r.duracionS),
            const SizedBox(height: 24),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: p.textoTerciario),
              const SizedBox(width: 8),
              Expanded(child: Text(AppConfig.avisoMedico, style: context.textos.bodySmall)),
            ],
          ),
          const SizedBox(height: 22),
          if (spec != null)
            BotonPrincipal(
              texto: 'Repetir ejercicio',
              icono: Icons.replay_rounded,
              onPressed: () => s.origen == OrigenSesion.tiempoReal
                  ? context.pushReplacement(Rutas.tiempoRealDe(spec.id))
                  : context.pushReplacement(Rutas.preparacionDe(spec.id)),
            ),
          const SizedBox(height: 10),
          BotonPrincipal(
            texto: esNueva ? 'Volver al inicio' : 'Volver',
            variante: VarianteBoton.secundario,
            onPressed: salir,
          ),
        ],
      ),
    );
  }
}

class _ChipComparacion extends StatelessWidget {
  final int diferencia;
  const _ChipComparacion({required this.diferencia});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final sube = diferencia > 0;
    final igual = diferencia == 0;
    final color = igual ? p.textoSecundario : (sube ? p.exito : p.peligro);
    final fondo = igual ? p.superficieAlta : (sube ? p.exitoSuave : p.peligroSuave);
    return ChipDato(
      texto: igual ? 'Igual que la anterior' : '${sube ? '+' : ''}$diferencia vs. anterior',
      icono: igual ? Icons.drag_handle_rounded : (sube ? Icons.trending_up_rounded : Icons.trending_down_rounded),
      color: color,
      fondo: fondo,
    );
  }
}

class _TarjetaCalidad extends StatelessWidget {
  final CalidadRegistro calidad;
  final double? duracionS;
  const _TarjetaCalidad({required this.calidad, this.duracionS});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final pct = calidad.porcentajeValidos / 100;
    final color = pct >= 0.8 ? p.exito : (pct >= 0.5 ? p.advertencia : p.peligro);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cuerpo visible', style: context.textos.titleSmall),
              const Spacer(),
              Text('${calidad.porcentajeValidos.round()} %', style: context.textos.titleSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), minHeight: 8, color: color),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DatoCalidad(
                  icono: Presentacion.iconoVista(calidad.vista),
                  etiqueta: 'Vista',
                  valor: Presentacion.vista(calidad.vista),
                ),
              ),
              Expanded(
                child: _DatoCalidad(
                  icono: Icons.timer_outlined,
                  etiqueta: 'Duración',
                  valor: duracionS == null ? '—' : Formato.segundos(duracionS!),
                ),
              ),
              Expanded(
                child: _DatoCalidad(
                  icono: Icons.photo_library_outlined,
                  etiqueta: 'Cuadros',
                  valor: '${calidad.fotogramas}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatoCalidad extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  const _DatoCalidad({required this.icono, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Row(
      children: [
        Icon(icono, size: 18, color: p.textoTerciario),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: context.textos.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(etiqueta, style: context.textos.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
