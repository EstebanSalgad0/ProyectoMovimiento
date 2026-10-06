import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/item_sesion.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/evaluacion.dart';
import '../../modelos/logros.dart';
import '../../modelos/recomendaciones.dart';
import '../../modelos/rutina.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';
import '../ejercicios/selector_ejercicio.dart';
import '../rutinas/lista_rutinas.dart';

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
    final evaluaciones = ref.watch(evaluacionesProvider).value ?? const <EvaluacionFuncional>[];
    final resumen = Resumen.desde(sesiones);
    final spec = ref.watch(especificacionProvider);
    final fechas = [...sesiones.map((s) => s.fecha), ...evaluaciones.map((e) => e.fecha)];
    final recomendaciones = generarRecomendaciones(
      usuario: usuario,
      sesiones: sesiones,
      evaluaciones: evaluaciones,
      nombreEjercicio: (id) => spec.buscar(id)?.nombre ?? id,
    );
    final sugerida = buscarRutina(
      ref.watch(todasLasRutinasProvider),
      idRutinaSugerida(usuario?.objetivo, usuario?.edad),
    );

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
                  if (usuario != null)
                    Semantics(
                      button: true,
                      label: 'Ir a mi cuenta',
                      child: InkWell(
                        onTap: () => context.go(Rutas.cuenta),
                        customBorder: const CircleBorder(),
                        child: AvatarUsuario(usuario: usuario, tamano: 48),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (usuario != null && !usuario.perfilCompleto) ...[
                _AvisoPerfil(avance: usuario.avancePerfil),
                const SizedBox(height: 14),
              ],

              _MetaSemanal(fechas: fechas, meta: usuario?.metaSemanal ?? 3, racha: resumen.racha),
              const SizedBox(height: 14),

              // Accesos rápidos
              Row(
                children: [
                  Expanded(
                    child: _Acceso(
                      icono: Icons.videocam_rounded,
                      titulo: 'Entrenar en vivo',
                      detalle: 'Correcciones al instante',
                      color: p.primario,
                      fondo: p.primarioSuave,
                      onTap: () => _entrenar(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Acceso(
                      icono: Icons.playlist_play_rounded,
                      titulo: 'Rutinas',
                      detalle: 'Series y descansos guiados',
                      color: p.acento,
                      fondo: p.acentoSuave,
                      onTap: () => context.go(Rutas.entrenarEn('rutinas')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Acceso(
                      icono: Icons.video_library_rounded,
                      titulo: 'Analizar video',
                      detalle: 'Desde la galería o grabando',
                      color: p.info,
                      fondo: p.infoSuave,
                      onTap: () => context.push(Rutas.preparacion),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Acceso(
                      icono: Icons.monitor_heart_outlined,
                      titulo: 'Evaluarme',
                      detalle: 'Prueba 30 s y goniómetro',
                      color: p.advertencia,
                      fondo: p.advertenciaSuave,
                      onTap: () => context.go(Rutas.entrenarEn('evaluaciones')),
                    ),
                  ),
                ],
              ),

              if (recomendaciones.isNotEmpty) ...[
                const SizedBox(height: 26),
                const EncabezadoSeccion(titulo: 'Para ti'),
                for (final r in recomendaciones) ...[
                  _TarjetaRecomendacion(recomendacion: r),
                  const SizedBox(height: 10),
                ],
              ],

              if (sugerida != null) ...[
                const SizedBox(height: 16),
                EncabezadoSeccion(
                  titulo: 'Rutina sugerida',
                  accion: 'Ver rutinas',
                  onAccion: () => context.go(Rutas.entrenarEn('rutinas')),
                ),
                TarjetaRutina(rutina: sugerida),
              ],
              const SizedBox(height: 26),

              // Indicadores
              Row(
                children: [
                  Expanded(
                    child: TileEstadistica(
                      icono: Icons.calendar_today_rounded,
                      valor: '${resumen.sesionesSemana}',
                      etiqueta: 'Últimos 7 días',
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
                      icono: Icons.repeat_rounded,
                      valor: '${resumen.repeticiones}',
                      etiqueta: 'Repeticiones',
                      color: p.info,
                      fondo: p.infoSuave,
                    ),
                  ),
                ],
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

class _AvisoPerfil extends StatelessWidget {
  final double avance;
  const _AvisoPerfil({required this.avance});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Tarjeta(
      onTap: () => context.push(Rutas.perfil),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: p.primarioSuave,
      colorBorde: p.primarioSuave,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(value: avance, strokeWidth: 4, backgroundColor: p.superficie),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Completa tu perfil', style: context.textos.titleSmall?.copyWith(color: p.primario)),
                Text('Tu edad, sexo y objetivo ajustan rutinas y referencias.', style: context.textos.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.primario),
        ],
      ),
    );
  }
}

/// Anillo con los días entrenados esta semana frente a la meta, y los días
/// de lunes a domingo.
class _MetaSemanal extends StatelessWidget {
  final List<DateTime> fechas;
  final int meta;
  final int racha;

  const _MetaSemanal({required this.fechas, required this.meta, required this.racha});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final hoy = DateTime.now();
    final lunes = inicioSemana(hoy);
    final activos = diasActivosSemana(fechas, hoy: hoy);
    final dias = {for (final f in fechas) soloDia(f)};
    final cumplida = activos >= meta;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: p.gradiente, borderRadius: BorderRadius.circular(Medidas.radioXL)),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (activos / meta).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          color: AppColores.blanco,
                          backgroundColor: AppColores.blanco.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    cumplida
                        ? const Icon(Icons.emoji_events_rounded, color: AppColores.blanco, size: 36)
                        : Text('$activos/$meta', style: AppTipo.numero(22, AppColores.blanco)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'META SEMANAL',
                      style: context.textos.labelSmall?.copyWith(
                        color: AppColores.blanco.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cumplida ? '¡Meta cumplida!' : '${Formato.plural(activos, 'día', 'días')} de $meta',
                      style: context.textos.titleLarge?.copyWith(color: AppColores.blanco),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFC56B)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            racha == 0 ? 'Empieza tu racha hoy' : 'Racha de ${Formato.plural(racha, 'día', 'días')}',
                            style: context.textos.bodySmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.9)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(
                  builder: (context) {
                    final d = lunes.add(Duration(days: i));
                    final activo = dias.contains(d);
                    final esHoy = d == soloDia(hoy);
                    return Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activo ? AppColores.blanco : AppColores.blanco.withValues(alpha: 0.12),
                            border: esHoy ? Border.all(color: AppColores.blanco, width: 2) : null,
                          ),
                          child: activo ? Icon(Icons.check_rounded, size: 18, color: p.gradienteHero.first) : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formato.inicialDia(d),
                          style: context.textos.labelSmall?.copyWith(
                            color: AppColores.blanco.withValues(alpha: esHoy ? 1 : 0.75),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final Color fondo;
  final VoidCallback onTap;

  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.fondo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoCaja(icono: icono, color: color, fondo: fondo, tamano: 40),
          const SizedBox(height: 12),
          Text(titulo, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(detalle, style: context.textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TarjetaRecomendacion extends StatelessWidget {
  final Recomendacion recomendacion;
  const _TarjetaRecomendacion({required this.recomendacion});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final r = recomendacion;
    final (icono, color, fondo) = switch (r.tipo) {
      TipoRecomendacion.dolorIntenso => (Icons.health_and_safety_rounded, p.peligro, p.peligroSuave),
      TipoRecomendacion.dolorModerado => (Icons.healing_rounded, p.advertencia, p.advertenciaSuave),
      TipoRecomendacion.correccion => (Icons.tips_and_updates_rounded, p.primario, p.primarioSuave),
      TipoRecomendacion.evaluacion => (Icons.monitor_heart_outlined, p.acento, p.acentoSuave),
      TipoRecomendacion.meta => (Icons.flag_rounded, p.info, p.infoSuave),
      TipoRecomendacion.metaCumplida => (Icons.celebration_rounded, p.exito, p.exitoSuave),
    };
    final VoidCallback? accion = switch (r.tipo) {
      TipoRecomendacion.correccion when r.ejercicioId != null => () => context.push(Rutas.ejercicio(r.ejercicioId!)),
      TipoRecomendacion.evaluacion => () => context.go(Rutas.entrenarEn('evaluaciones')),
      TipoRecomendacion.meta => () => context.go(Rutas.entrenarEn('rutinas')),
      _ => null,
    };
    return Tarjeta(
      onTap: accion,
      padding: const EdgeInsets.all(14),
      colorBorde: r.tipo == TipoRecomendacion.dolorIntenso ? p.peligro.withValues(alpha: 0.5) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoCaja(icono: icono, color: color, fondo: fondo, tamano: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.titulo, style: context.textos.titleSmall),
                const SizedBox(height: 2),
                Text(r.detalle, style: context.textos.bodySmall),
              ],
            ),
          ),
          if (accion != null) ...[const SizedBox(width: 6), Icon(Icons.chevron_right_rounded, color: p.textoTerciario)],
        ],
      ),
    );
  }
}
