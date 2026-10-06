import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/utils/formato.dart';
import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../../motor/especificacion.dart';
import '../../rutas.dart';
import '../ejercicios/selector_ejercicio.dart';
import 'camara_pose.dart';
import 'ciclo_camara.dart';
import 'componentes_camara.dart';
import 'controlador_tiempo_real.dart';

/// Entrenamiento libre en tiempo real: la detección de pose y el análisis
/// ocurren en el teléfono (ML Kit + motor local), sin necesidad de servidor.
class TiempoRealPantalla extends ConsumerStatefulWidget {
  final String? ejercicioId;

  const TiempoRealPantalla({super.key, this.ejercicioId});

  @override
  ConsumerState<TiempoRealPantalla> createState() => _TiempoRealPantallaState();
}

class _TiempoRealPantallaState extends ConsumerState<TiempoRealPantalla>
    with WidgetsBindingObserver, CicloCamara<TiempoRealPantalla> {
  CamaraPose? _camara;
  ControladorTiempoReal? _ctrl;
  bool _terminado = false;

  @override
  CamaraPose? get camaraDelCiclo => _camara;

  @override
  bool get reanudarCamara => !_terminado;

  @override
  void initState() {
    super.initState();
    final ejercicio = ref.read(especificacionPersonalizadaProvider).buscar(widget.ejercicioId ?? '');
    if (ejercicio != null) {
      _crear(ejercicio);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _elegirEjercicio());
    }
  }

  void _crear(EjercicioSpec ejercicio) {
    final ajustes = ref.read(ajustesProvider);
    final voz = ref.read(vozProvider)..cambiarVelocidad(ajustes.velocidadVoz);
    final camara = CamaraPose(preferirFrontal: ajustes.camaraFrontal);
    final ctrl = ControladorTiempoReal(
      camara: camara,
      spec: ref.read(especificacionPersonalizadaProvider),
      ejercicio: ejercicio,
      voz: voz,
      vozActiva: ajustes.voz,
      vibracion: ajustes.vibracion,
      segundosCuentaRegresiva: ajustes.cuentaRegresiva,
    );
    setState(() {
      _camara = camara;
      _ctrl = ctrl;
    });
    camara.iniciar();
  }

  Future<void> _elegirEjercicio() async {
    final id = await mostrarSelectorEjercicio(context);
    if (!mounted) return;
    final e = id == null ? null : ref.read(especificacionPersonalizadaProvider).buscar(id);
    if (e == null) {
      context.pop();
    } else {
      _crear(e);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _camara?.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final c = _ctrl;
    if (c == null) return;
    if (c.etapa == EtapaSesion.activa && !c.hayRepeticiones) {
      final salir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aún no hay repeticiones'),
          content: const Text('No se registró ninguna repetición completa. ¿Quieres salir sin guardar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir entrenando')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
          ],
        ),
      );
      if (salir == true && mounted) context.pop();
      return;
    }
    _terminado = true;
    final r = await c.finalizar();
    if (!mounted) return;
    if (r == null) {
      context.pop();
      return;
    }
    final sesion = await ref
        .read(historialProvider.notifier)
        .registrar(r.resultado, OrigenSesion.tiempoReal, esqueleto: r.esqueleto);
    if (mounted) context.pushReplacement(Rutas.sesion(sesion.id, nueva: true), extra: sesion);
  }

  Future<void> _cerrar() async {
    final c = _ctrl;
    if (c != null && c.etapa == EtapaSesion.activa && c.hayRepeticiones) {
      final opcion = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Terminar la sesión?'),
          content: Text('Llevas ${Formato.plural(c.repeticiones, 'repetición', 'repeticiones')}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'descartar'), child: const Text('Descartar')),
            FilledButton(onPressed: () => Navigator.pop(context, 'guardar'), child: const Text('Ver resultado')),
          ],
        ),
      );
      if (opcion == 'guardar') return _finalizar();
      if (opcion != 'descartar') return;
    }
    if (mounted) context.pop();
  }

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
              : ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => _Contenido(ctrl: c, onCerrar: _cerrar, onFinalizar: _finalizar),
                ),
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  final ControladorTiempoReal ctrl;
  final VoidCallback onCerrar;
  final VoidCallback onFinalizar;

  const _Contenido({required this.ctrl, required this.onCerrar, required this.onFinalizar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ajustes = ref.watch(ajustesProvider);
    final camara = ctrl.camara;
    final etapa = ctrl.etapa;
    return Stack(
      fit: StackFit.expand,
      children: [
        VistaCamaraPose(
          camara: camara,
          destacados: puntosDeGrupos(ctrl.ejercicio),
          zonasConAlerta: ctrl.zonasConAlerta,
          mostrarEsqueleto: ajustes.mostrarEsqueleto,
          visibilidadMinima: ctrl.spec.globales.visibilidadMinima,
        ),
        const DegradadosCamara(),
        SafeArea(
          child: Column(
            children: [
              BarraCamara(
                titulo: ctrl.ejercicio.nombre,
                subtitulo: etapa == EtapaSesion.activa ? null : 'Entrenamiento libre',
                cronometro: etapa == EtapaSesion.activa ? ctrl.reloj.elapsed : null,
                onCerrar: onCerrar,
                acciones: [
                  BotonCircular(
                    icono: ctrl.vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    tooltip: ctrl.vozActiva ? 'Silenciar voz' : 'Activar voz',
                    onPressed: ctrl.alternarVoz,
                  ),
                  BotonCircular(
                    icono: Icons.cameraswitch_rounded,
                    tooltip: 'Cambiar cámara',
                    onPressed: camara.puedeCambiarCamara && camara.lista ? camara.cambiarCamara : null,
                  ),
                ],
              ),
              Expanded(
                child: switch (etapa) {
                  EtapaSesion.finalizando ||
                  EtapaSesion.serieCompleta => const MensajeCamara(cargando: true, titulo: 'Generando tu resultado…'),
                  _ => EstadoCamaraVista(
                    camara: camara,
                    hijo: switch (etapa) {
                      EtapaSesion.cuentaRegresiva => CuentaRegresivaGrande(cuenta: ctrl.cuenta),
                      EtapaSesion.activa => HudEntrenamiento(ctrl: ctrl, onBoton: onFinalizar),
                      _ => PanelEncuadre(
                        ejercicio: ctrl.ejercicio,
                        faltantes: ctrl.faltantes,
                        hayPersona: camara.puntos != null,
                        onComenzar: ctrl.comenzarAhora,
                      ),
                    },
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
