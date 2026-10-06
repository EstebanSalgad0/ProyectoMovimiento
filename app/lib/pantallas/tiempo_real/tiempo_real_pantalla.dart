import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/resultado_analisis.dart';
import '../../modelos/sesion.dart';
import '../../motor/analizador.dart' show nombresGrupo;
import '../../motor/especificacion.dart';
import '../../motor/puntos.dart';
import '../../rutas.dart';
import '../ejercicios/selector_ejercicio.dart';
import 'controlador_tiempo_real.dart';
import 'pintor_esqueleto.dart';

/// Entrenamiento en tiempo real: la detección de pose y el análisis ocurren en
/// el teléfono (ML Kit + motor local), sin necesidad de servidor.
class TiempoRealPantalla extends ConsumerStatefulWidget {
  final String? ejercicioId;

  const TiempoRealPantalla({super.key, this.ejercicioId});

  @override
  ConsumerState<TiempoRealPantalla> createState() => _TiempoRealPantallaState();
}

class _TiempoRealPantallaState extends ConsumerState<TiempoRealPantalla> with WidgetsBindingObserver {
  ControladorTiempoReal? _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WakelockPlus.enable().catchError((_) {});
    final spec = ref.read(especificacionProvider);
    final ejercicio = spec.buscar(widget.ejercicioId ?? '');
    if (ejercicio != null) {
      _crearControlador(ejercicio);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _elegirEjercicio());
    }
  }

  void _crearControlador(EjercicioSpec ejercicio) {
    final ajustes = ref.read(ajustesProvider);
    final ctrl = ControladorTiempoReal(
      spec: ref.read(especificacionProvider),
      ejercicio: ejercicio,
      voz: ref.read(vozProvider),
      vozActiva: ajustes.voz,
      preferirFrontal: ajustes.camaraFrontal,
    );
    setState(() => _ctrl = ctrl);
    ctrl.iniciar();
  }

  Future<void> _elegirEjercicio() async {
    final id = await mostrarSelectorEjercicio(context);
    if (!mounted) return;
    final e = id == null ? null : ref.read(especificacionProvider).buscar(id);
    if (e == null) {
      context.pop();
    } else {
      _crearControlador(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _ctrl;
    if (c == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      c.pausar();
    } else if (state == AppLifecycleState.resumed) {
      c.reanudar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable().catchError((_) {});
    _ctrl?.dispose();
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
    final resultado = await c.finalizar();
    if (!mounted) return;
    if (resultado == null) {
      context.pop();
      return;
    }
    final sesion = await ref.read(historialProvider.notifier).registrar(resultado, OrigenSesion.tiempoReal);
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

class _Contenido extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  final VoidCallback onCerrar;
  final VoidCallback onFinalizar;

  const _Contenido({required this.ctrl, required this.onCerrar, required this.onFinalizar});

  @override
  Widget build(BuildContext context) {
    final etapa = ctrl.etapa;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ctrl.camara != null) _VistaCamara(ctrl: ctrl),
        // Degradados para que los textos se lean sobre cualquier fondo
        const Positioned(top: 0, left: 0, right: 0, height: 170, child: _Degradado(arriba: true)),
        const Positioned(bottom: 0, left: 0, right: 0, height: 300, child: _Degradado(arriba: false)),
        SafeArea(
          child: Column(
            children: [
              _BarraSuperior(ctrl: ctrl, onCerrar: onCerrar),
              Expanded(
                child: switch (etapa) {
                  EtapaSesion.iniciando => const _Mensaje(cargando: true, titulo: 'Preparando la cámara…'),
                  EtapaSesion.finalizando => const _Mensaje(cargando: true, titulo: 'Generando tu resultado…'),
                  EtapaSesion.sinPermiso => _ErrorCamara(
                    titulo: 'Necesitamos acceso a la cámara',
                    texto:
                        'Permite el uso de la cámara en la configuración del teléfono para analizar tu '
                        'movimiento. Las imágenes se procesan en el teléfono y no se guardan.',
                    onReintentar: ctrl.iniciar,
                  ),
                  EtapaSesion.sinCamara => const _ErrorCamara(
                    titulo: 'No encontramos una cámara',
                    texto:
                        'Este dispositivo no tiene una cámara disponible. Puedes analizar un video desde la galería.',
                  ),
                  EtapaSesion.error => _ErrorCamara(
                    titulo: 'No se pudo abrir la cámara',
                    texto: ctrl.mensajeError ?? 'Ocurrió un error inesperado.',
                    onReintentar: ctrl.iniciar,
                  ),
                  EtapaSesion.encuadre => _Encuadre(ctrl: ctrl),
                  EtapaSesion.cuentaRegresiva => _CuentaRegresiva(cuenta: ctrl.cuenta),
                  EtapaSesion.activa => _Hud(ctrl: ctrl, onFinalizar: onFinalizar),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VistaCamara extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  const _VistaCamara({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final camara = ctrl.camara!;
    if (!camara.value.isInitialized || camara.value.previewSize == null) return const SizedBox.shrink();
    final p = context.paleta;
    final puntos = ctrl.puntos;
    final tamano = ctrl.tamanoImagen;
    final destacados = {for (final g in ctrl.ejercicio.puntosRequeridos) ...gruposPuntos[g] ?? const <int>[]};
    // En vertical la vista previa tiene la relación de aspecto invertida.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: camara.value.previewSize!.height,
          height: camara.value.previewSize!.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(camara),
              if (puntos != null && tamano != null)
                CustomPaint(
                  painter: PintorEsqueleto(
                    puntos: puntos,
                    tamanoImagen: tamano,
                    rotacion: ctrl.rotacion,
                    lente: ctrl.lente,
                    destacados: destacados,
                    zonasConAlerta: ctrl.zonasConAlerta,
                    color: PaletaApp.oscuro.acento,
                    colorAlerta: p.peligro,
                    visibilidadMinima: ctrl.spec.globales.visibilidadMinima,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Degradado extends StatelessWidget {
  final bool arriba;
  const _Degradado({required this.arriba});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: arriba ? Alignment.topCenter : Alignment.bottomCenter,
            end: arriba ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.65), Colors.black.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _BotonCircular extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  const _BotonCircular({required this.icono, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: AppColores.blanco,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.2),
      ),
      icon: Icon(icono),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  final VoidCallback onCerrar;
  const _BarraSuperior({required this.ctrl, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final activa = ctrl.etapa == EtapaSesion.activa;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          _BotonCircular(icono: Icons.close_rounded, tooltip: 'Cerrar', onPressed: onCerrar),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctrl.ejercicio.nombre,
                  style: context.textos.titleMedium?.copyWith(color: AppColores.blanco),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activa)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFF87171), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formato.cronometro(ctrl.reloj.elapsed),
                        style: AppTipo.numero(13, AppColores.blanco.withValues(alpha: 0.9), peso: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _BotonCircular(
            icono: ctrl.vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            tooltip: ctrl.vozActiva ? 'Silenciar voz' : 'Activar voz',
            onPressed: ctrl.alternarVoz,
          ),
          const SizedBox(width: 6),
          _BotonCircular(
            icono: Icons.cameraswitch_rounded,
            tooltip: 'Cambiar cámara',
            onPressed: ctrl.puedeCambiarCamara && ctrl.camara != null ? ctrl.cambiarCamara : null,
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final bool cargando;
  final String titulo;
  const _Mensaje({required this.titulo, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cargando) const CircularProgressIndicator(color: AppColores.blanco),
          const SizedBox(height: 18),
          Text(titulo, style: context.textos.titleMedium?.copyWith(color: AppColores.blanco)),
        ],
      ),
    );
  }
}

class _ErrorCamara extends StatelessWidget {
  final String titulo;
  final String texto;
  final VoidCallback? onReintentar;
  const _ErrorCamara({required this.titulo, required this.texto, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Tarjeta(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoCaja(icono: Icons.no_photography_outlined, color: p.peligro, fondo: p.peligroSuave, tamano: 64),
              const SizedBox(height: 16),
              Text(titulo, style: context.textos.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                texto,
                style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (onReintentar != null) ...[
                BotonPrincipal(texto: 'Reintentar', icono: Icons.refresh_rounded, onPressed: onReintentar),
                const SizedBox(height: 10),
              ],
              BotonPrincipal(
                texto: 'Analizar un video',
                variante: VarianteBoton.secundario,
                icono: Icons.video_library_outlined,
                onPressed: () => context.pushReplacement(Rutas.preparacion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encuadre extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  const _Encuadre({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final faltan = ctrl.faltantes;
    final listo = faltan.isEmpty && ctrl.puntos != null;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 20, 36, 20),
            child: CustomPaint(
              painter: _PintorMarco(color: listo ? PaletaApp.oscuro.exito : AppColores.blanco.withValues(alpha: 0.75)),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Tarjeta(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      listo ? Icons.check_circle_rounded : Icons.center_focus_strong_rounded,
                      color: listo ? p.exito : p.primario,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        listo ? '¡Perfecto! No te muevas…' : 'Ubícate para que se vea todo tu cuerpo',
                        style: context.textos.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(ctrl.ejercicio.camara, style: context.textos.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in ctrl.ejercicio.puntosRequeridos)
                      ChipDato(
                        texto: _capitalizar(nombresGrupo[g]?.split(' ').last ?? g),
                        icono: faltan.contains(g) || ctrl.puntos == null ? Icons.close_rounded : Icons.check_rounded,
                        color: faltan.contains(g) || ctrl.puntos == null ? p.peligro : p.exito,
                        fondo: faltan.contains(g) || ctrl.puntos == null ? p.peligroSuave : p.exitoSuave,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                BotonPrincipal(
                  texto: 'Comenzar ahora',
                  icono: Icons.play_arrow_rounded,
                  variante: VarianteBoton.suave,
                  onPressed: ctrl.comenzarAhora,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PintorMarco extends CustomPainter {
  final Color color;
  _PintorMarco({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const largo = 36.0;
    const r = 22.0;
    final w = size.width, h = size.height;
    // Cuatro esquinas redondeadas tipo visor
    for (final (x, y, sx, sy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      final path = Path()
        ..moveTo(x, y + sy * (r + largo))
        ..lineTo(x, y + sy * r)
        ..arcToPoint(Offset(x + sx * r, y), radius: const Radius.circular(r), clockwise: sx * sy > 0)
        ..lineTo(x + sx * (r + largo), y);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMarco old) => old.color != color;
}

class _CuentaRegresiva extends StatelessWidget {
  final int cuenta;
  const _CuentaRegresiva({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(cuenta),
        tween: Tween(begin: 1.6, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, escala, _) => Transform.scale(
          scale: escala,
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(color: AppColores.blanco.withValues(alpha: 0.7), width: 3),
            ),
            child: Text('${math.max(cuenta, 1)}', style: AppTipo.numero(84, AppColores.blanco)),
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  final VoidCallback onFinalizar;
  const _Hud({required this.ctrl, required this.onFinalizar});

  @override
  Widget build(BuildContext context) {
    final aviso = ctrl.aviso;
    final mostrarAviso = aviso != null && DateTime.now().difference(aviso.hora) < const Duration(seconds: 4);
    final faltan = ctrl.faltantes;
    return Column(
      children: [
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: faltan.isNotEmpty && ctrl.estado?.valido == false
              ? _Banner(
                  key: const ValueKey('faltan'),
                  titulo: 'No se ven ${nombresGrupo[faltan.first] ?? faltan.first}',
                  detalle: 'Aléjate un poco o ajusta el teléfono.',
                  severidad: Severidad.info,
                )
              : mostrarAviso
              ? _Banner(
                  key: ValueKey(aviso.hora),
                  titulo: aviso.titulo,
                  detalle: aviso.detalle,
                  severidad: aviso.severidad,
                )
              : const SizedBox.shrink(),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ContadorRepeticiones(actual: ctrl.repeticiones, objetivo: ctrl.ejercicio.objetivoRepeticiones),
              const SizedBox(width: 14),
              Expanded(child: _MedidorMovimiento(ctrl: ctrl)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: onFinalizar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColores.blanco,
              foregroundColor: AppColores.marino,
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Finalizar y ver resultado'),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final Severidad? severidad;
  const _Banner({super.key, required this.titulo, this.detalle, this.severidad});

  @override
  Widget build(BuildContext context) {
    final p = PaletaApp.oscuro;
    final (color, _) = severidad == null ? (p.exito, p.exitoSuave) : Presentacion.coloresSeveridad(p, severidad!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(severidad == null ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.textos.titleSmall?.copyWith(color: AppColores.blanco)),
                  if (detalle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detalle!,
                      style: context.textos.bodySmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContadorRepeticiones extends StatelessWidget {
  final int actual;
  final int objetivo;
  const _ContadorRepeticiones({required this.actual, required this.objetivo});

  @override
  Widget build(BuildContext context) {
    final color = PaletaApp.oscuro.acento;
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: objetivo == 0 ? 0 : (actual / objetivo).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppColores.blanco.withValues(alpha: 0.2),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Text('$actual', key: ValueKey(actual), style: AppTipo.numero(44, AppColores.blanco)),
              ),
              Text(
                'de $objetivo',
                style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedidorMovimiento extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  const _MedidorMovimiento({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final p = PaletaApp.oscuro;
    final valor = ctrl.estado?.valorSenal;
    final progreso = ctrl.progresoMovimiento;
    final senal = ctrl.ejercicio.senal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.primario.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(ctrl.textoFase, style: context.textos.labelSmall?.copyWith(color: AppColores.blanco)),
              ),
              const Spacer(),
              Text(
                valor == null ? '—' : '${valor.round()}${senal.unidad}',
                style: AppTipo.numero(22, AppColores.blanco),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              color: progreso >= 1 ? p.exito : p.primario,
              backgroundColor: AppColores.blanco.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            senal.nombre,
            style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}
