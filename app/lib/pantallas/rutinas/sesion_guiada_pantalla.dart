import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../estado/proveedores.dart';
import '../../modelos/rutina.dart';
import '../../modelos/sesion.dart';
import '../../motor/especificacion.dart';
import '../../rutas.dart';
import '../tiempo_real/camara_pose.dart';
import '../tiempo_real/ciclo_camara.dart';
import '../tiempo_real/componentes_camara.dart';
import '../tiempo_real/controlador_tiempo_real.dart';

/// Ejecuta una rutina serie por serie con la cámara: cuenta las repeticiones,
/// termina cada serie al llegar al objetivo, guía los descansos y guarda cada
/// serie como una sesión agrupada por la ejecución de la rutina.
class SesionGuiadaPantalla extends ConsumerStatefulWidget {
  final String rutinaId;

  const SesionGuiadaPantalla({super.key, required this.rutinaId});

  @override
  ConsumerState<SesionGuiadaPantalla> createState() => _SesionGuiadaPantallaState();
}

class _SesionGuiadaPantallaState extends ConsumerState<SesionGuiadaPantalla>
    with WidgetsBindingObserver, CicloCamara<SesionGuiadaPantalla> {
  late final Especificacion _spec = ref.read(especificacionPersonalizadaProvider);
  PlanSesionGuiada? _plan;
  CamaraPose? _camara;
  ControladorTiempoReal? _ctrl;

  Timer? _temporizadorDescanso;
  int _descanso = 0;
  int _descansoTotal = 1;
  Sesion? _ultimaSesion;
  bool _guardando = false;
  bool _terminado = false;

  @override
  CamaraPose? get camaraDelCiclo => _camara;

  @override
  bool get reanudarCamara => !_terminado;

  @override
  void initState() {
    super.initState();
    final rutina = buscarRutina(ref.read(todasLasRutinasProvider), widget.rutinaId);
    // Solo los ejercicios que existen en la especificación actual.
    final items = [...?rutina?.items.where((i) => _spec.buscar(i.ejercicioId) != null)];
    if (rutina == null || items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }
    final plan = PlanSesionGuiada(rutina.copyWith(items: items));
    final paso = plan.actual;
    final ajustes = ref.read(ajustesProvider);
    final voz = ref.read(vozProvider)..cambiarVelocidad(ajustes.velocidadVoz);
    final camara = CamaraPose(preferirFrontal: ajustes.camaraFrontal);
    final ctrl = ControladorTiempoReal(
      camara: camara,
      spec: _spec,
      ejercicio: _spec.buscar(paso.item.ejercicioId)!,
      objetivo: paso.item.repeticiones,
      autoFinalizar: true,
      voz: voz,
      vozActiva: ajustes.voz,
      vibracion: ajustes.vibracion,
      segundosCuentaRegresiva: ajustes.cuentaRegresiva,
    )..addListener(_alCambiarControlador);
    _plan = plan;
    _camara = camara;
    _ctrl = ctrl;
    camara.iniciar();
  }

  @override
  void dispose() {
    _temporizadorDescanso?.cancel();
    _ctrl?.removeListener(_alCambiarControlador);
    _ctrl?.dispose();
    _camara?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- lógica
  void _alCambiarControlador() {
    final plan = _plan!, c = _ctrl!;
    if (_terminado || _guardando) return;
    if (c.etapa == EtapaSesion.activa && plan.estado == EstadoGuiado.preparando) {
      plan.comenzarSerie();
    } else if (c.etapa == EtapaSesion.serieCompleta && plan.estado == EstadoGuiado.serie) {
      _serieTerminada();
    }
  }

  ContextoRutina _contexto() {
    final plan = _plan!;
    return ContextoRutina(
      rutinaId: plan.rutina.id,
      rutinaNombre: plan.rutina.nombre,
      ejecucionId: plan.ejecucionId,
      serie: plan.indice + 1,
      totalSeries: plan.pasos.length,
    );
  }

  /// Guarda la serie si tuvo al menos una repetición. Devuelve la sesión.
  Future<Sesion?> _registrar(ResultadoSerie? r) async {
    if (r == null || r.resultado.numeroRepeticiones == 0) return null;
    return ref
        .read(historialProvider.notifier)
        .registrar(r.resultado, OrigenSesion.tiempoReal, esqueleto: r.esqueleto, rutina: _contexto());
  }

  Future<void> _serieTerminada() async {
    final plan = _plan!;
    _guardando = true;
    final sesion = await _registrar(_ctrl!.tomarResultado());
    if (!mounted) return;
    _guardando = false;
    _ultimaSesion = sesion;
    final paso = plan.actual;
    plan.completarSerie(sesionId: sesion?.id);
    if (plan.estado == EstadoGuiado.terminado) {
      await _terminar();
    } else {
      _iniciarDescanso(paso.item.descansoS);
    }
  }

  void _iniciarDescanso(int segundos) {
    _descanso = segundos;
    _descansoTotal = segundos <= 0 ? 1 : segundos;
    _hablar('Descanso');
    _temporizadorDescanso?.cancel();
    _temporizadorDescanso = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _descanso--);
      if (_descanso == 5) _hablar('Prepárate');
      if (_descanso <= 0) _siguienteSerie();
    });
    setState(() {});
  }

  void _sumarDescanso() {
    setState(() {
      _descanso += 15;
      if (_descanso > _descansoTotal) _descansoTotal = _descanso;
    });
  }

  void _siguienteSerie() {
    _temporizadorDescanso?.cancel();
    final plan = _plan!;
    plan.avanzar();
    if (plan.estado == EstadoGuiado.terminado) {
      _terminar();
      return;
    }
    final paso = plan.actual;
    final ejercicio = _spec.buscar(paso.item.ejercicioId)!;
    _ctrl!.prepararSerie(ejercicio: ejercicio, objetivo: paso.item.repeticiones);
    _hablar(paso.esPrimeraSerie ? ejercicio.nombre : 'Serie ${paso.serie}');
    if (paso.esPrimeraSerie) HapticFeedback.selectionClick();
    setState(() {});
  }

  void _hablar(String texto) {
    final c = _ctrl;
    if (c != null && c.vozActiva) ref.read(vozProvider).decir(texto, prioritario: true);
  }

  Future<void> _terminar() async {
    if (_terminado) return;
    _terminado = true;
    _temporizadorDescanso?.cancel();
    await _ctrl?.finalizar();
    if (!mounted) return;
    final plan = _plan!;
    if (plan.sesionesCompletadas.isEmpty) {
      context.pop();
    } else {
      context.pushReplacement(Rutas.ejecucion(plan.ejecucionId));
    }
  }

  Future<void> _cerrar() async {
    final plan = _plan;
    final c = _ctrl;
    if (_guardando) return;
    if (plan == null || c == null || _terminado) {
      if (mounted) context.pop();
      return;
    }
    final hechas = plan.sesionesCompletadas.length;
    final enCurso = c.etapa == EtapaSesion.activa && c.hayRepeticiones;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Terminar la rutina?'),
        content: Text(
          [
            'Completaste ${Formato.plural(hechas, 'serie', 'series')} de ${plan.pasos.length}.',
            if (enCurso) 'La serie en curso también se guardará.',
            if (hechas > 0 || enCurso) 'Verás el resumen de lo que hiciste.',
          ].join(' '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terminar')),
        ],
      ),
    );
    if (salir != true || !mounted) return;
    _guardando = true;
    _temporizadorDescanso?.cancel();
    if (enCurso) {
      final sesion = await _registrar(c.tomarResultado());
      if (sesion != null) plan.sesionesCompletadas.add(sesion.id);
    }
    plan.terminar();
    await _terminar();
  }

  // ------------------------------------------------------------ interfaz
  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cerrar();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: c == null
              ? const Center(child: CircularProgressIndicator(color: AppColores.blanco))
              : ListenableBuilder(listenable: c, builder: (context, _) => _contenido(context, c, _plan!)),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, ControladorTiempoReal c, PlanSesionGuiada plan) {
    final ajustes = ref.watch(ajustesProvider);
    final camara = c.camara;
    final paso = plan.actual;
    final enDescanso = plan.estado == EstadoGuiado.descanso;
    return Stack(
      fit: StackFit.expand,
      children: [
        VistaCamaraPose(
          camara: camara,
          destacados: puntosDeGrupos(c.ejercicio),
          zonasConAlerta: c.zonasConAlerta,
          mostrarEsqueleto: ajustes.mostrarEsqueleto && !enDescanso,
          visibilidadMinima: _spec.globales.visibilidadMinima,
        ),
        const DegradadosCamara(),
        if (enDescanso) ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
        SafeArea(
          child: Column(
            children: [
              BarraCamara(
                titulo: plan.rutina.nombre,
                subtitulo: enDescanso
                    ? 'Descanso'
                    : '${c.ejercicio.nombre} · serie ${paso.serie} de ${paso.item.series}',
                cronometro: c.etapa == EtapaSesion.activa ? c.reloj.elapsed : null,
                onCerrar: _cerrar,
                acciones: [
                  BotonCircular(
                    icono: c.vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    tooltip: c.vozActiva ? 'Silenciar voz' : 'Activar voz',
                    onPressed: c.alternarVoz,
                  ),
                  BotonCircular(
                    icono: Icons.cameraswitch_rounded,
                    tooltip: 'Cambiar cámara',
                    onPressed: camara.puedeCambiarCamara && camara.lista ? camara.cambiarCamara : null,
                  ),
                ],
              ),
              _AvanceRutina(plan: plan),
              Expanded(
                child: enDescanso
                    ? _PanelDescanso(
                        segundos: _descanso,
                        total: _descansoTotal,
                        plan: plan,
                        ultima: _ultimaSesion,
                        spec: _spec,
                        onSumar: _sumarDescanso,
                        onSaltar: _siguienteSerie,
                      )
                    : _terminado || c.etapa == EtapaSesion.finalizando
                    ? const MensajeCamara(cargando: true, titulo: 'Guardando tu rutina…')
                    : EstadoCamaraVista(
                        camara: camara,
                        hijo: switch (c.etapa) {
                          EtapaSesion.cuentaRegresiva => CuentaRegresivaGrande(cuenta: c.cuenta),
                          EtapaSesion.activa => HudEntrenamiento(
                            ctrl: c,
                            onBoton: c.terminarSerie,
                            textoBoton: 'Terminar serie',
                            iconoBoton: Icons.skip_next_rounded,
                          ),
                          EtapaSesion.serieCompleta => const MensajeCamara(
                            cargando: true,
                            titulo: '¡Serie completada!',
                          ),
                          _ => PanelEncuadre(
                            ejercicio: c.ejercicio,
                            faltantes: c.faltantes,
                            hayPersona: camara.puntos != null,
                            onComenzar: c.comenzarAhora,
                            encabezado:
                                'SERIE ${plan.indice + 1} DE ${plan.pasos.length} · '
                                '${Formato.plural(paso.item.repeticiones, 'REPETICIÓN', 'REPETICIONES')}',
                          ),
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barra fina con el avance de la rutina (una marca por serie).
class _AvanceRutina extends StatelessWidget {
  final PlanSesionGuiada plan;
  const _AvanceRutina({required this.plan});

  @override
  Widget build(BuildContext context) {
    final acento = PaletaApp.oscuro.acento;
    final hechas =
        plan.indice + (plan.estado == EstadoGuiado.descanso || plan.estado == EstadoGuiado.terminado ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < plan.pasos.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                decoration: BoxDecoration(
                  color: i < hechas
                      ? acento
                      : i == plan.indice
                      ? AppColores.blanco.withValues(alpha: 0.7)
                      : AppColores.blanco.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelDescanso extends StatelessWidget {
  final int segundos;
  final int total;
  final PlanSesionGuiada plan;
  final Sesion? ultima;
  final Especificacion spec;
  final VoidCallback onSumar;
  final VoidCallback onSaltar;

  const _PanelDescanso({
    required this.segundos,
    required this.total,
    required this.plan,
    required this.ultima,
    required this.spec,
    required this.onSumar,
    required this.onSaltar,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaApp.oscuro;
    final siguiente = plan.siguiente;
    final ejercicio = siguiente == null ? null : spec.buscar(siguiente.item.ejercicioId);
    final blanco70 = AppColores.blanco.withValues(alpha: 0.7);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          if (ultima != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: p.exito.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: p.exito, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Serie guardada · ${Formato.plural(ultima!.resultado.numeroRepeticiones, 'rep.', 'reps.')} · '
                    '${ultima!.puntaje} pts',
                    style: context.textos.labelLarge?.copyWith(color: AppColores.blanco),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Text('DESCANSO', style: context.textos.labelLarge?.copyWith(color: blanco70, letterSpacing: 2)),
          const SizedBox(height: 14),
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (segundos / total).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      color: p.acento,
                      backgroundColor: AppColores.blanco.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Text(
                  Formato.cronometro(Duration(seconds: segundos < 0 ? 0 : segundos)),
                  style: AppTipo.numero(44, AppColores.blanco),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (siguiente != null && ejercicio != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColores.blanco.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColores.blanco.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: IlustracionEjercicio(ejercicioId: ejercicio.id, animada: true),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('A CONTINUACIÓN', style: context.textos.labelSmall?.copyWith(color: p.acento)),
                            const SizedBox(height: 2),
                            Text(
                              ejercicio.nombre,
                              style: context.textos.titleMedium?.copyWith(color: AppColores.blanco),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Serie ${siguiente.serie} de ${siguiente.item.series} · '
                              '${Formato.plural(siguiente.item.repeticiones, 'repetición', 'repeticiones')}',
                              style: context.textos.bodySmall?.copyWith(color: blanco70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (plan.siguienteCambiaEjercicio) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.videocam_outlined, color: blanco70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ejercicio.camara, style: context.textos.bodySmall?.copyWith(color: blanco70)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSumar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.blanco,
                    side: BorderSide(color: AppColores.blanco.withValues(alpha: 0.4)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('15 s'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onSaltar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColores.blanco,
                    foregroundColor: AppColores.marino,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Saltar descanso'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
