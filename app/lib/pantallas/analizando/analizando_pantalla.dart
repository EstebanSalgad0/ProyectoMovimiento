import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../../rutas.dart';
import '../../motor/especificacion.dart';
import '../../servicios/servicio_ia.dart';

class SolicitudAnalisis {
  final File video;
  final String ejercicio;
  const SolicitudAnalisis({required this.video, required this.ejercicio});
}

enum _Etapa { subiendo, procesando, error }

/// Sube el video, espera el análisis del servidor y abre el resultado.
class AnalizandoPantalla extends ConsumerStatefulWidget {
  final SolicitudAnalisis solicitud;

  const AnalizandoPantalla({super.key, required this.solicitud});

  @override
  ConsumerState<AnalizandoPantalla> createState() => _AnalizandoPantallaState();
}

class _AnalizandoPantallaState extends ConsumerState<AnalizandoPantalla> {
  _Etapa _etapa = _Etapa.subiendo;
  double _progreso = 0;
  ErrorAnalisis? _error;
  CancelToken? _cancelar;
  final _reloj = Stopwatch();
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _analizar();
  }

  @override
  void dispose() {
    _tic?.cancel();
    _cancelar?.cancel();
    super.dispose();
  }

  Future<void> _analizar() async {
    final cancelar = CancelToken();
    _cancelar = cancelar;
    setState(() {
      _etapa = _Etapa.subiendo;
      _progreso = 0;
      _error = null;
    });
    _reloj
      ..reset()
      ..start();
    try {
      final resultado = await ref
          .read(servicioIAProvider)
          .analizarVideo(
            video: widget.solicitud.video,
            ejercicio: widget.solicitud.ejercicio,
            ajustes: _ajustesDelEjercicio(),
            cancelar: cancelar,
            onProgreso: (v) {
              if (!mounted) return;
              setState(() {
                _progreso = v;
                if (v >= 0.999) _etapa = _Etapa.procesando;
              });
            },
          );
      final sesion = await ref
          .read(historialProvider.notifier)
          .registrar(
            resultado,
            OrigenSesion.video,
            videoNombre: widget.solicitud.video.uri.pathSegments.last,
            video: ref.read(ajustesProvider).guardarVideos ? widget.solicitud.video : null,
          );
      if (mounted) context.pushReplacement(Rutas.sesion(sesion.id, nueva: true), extra: sesion);
    } on ErrorAnalisis catch (e) {
      if (e.tipo == TipoErrorAnalisis.cancelado || !mounted) return;
      setState(() {
        _etapa = _Etapa.error;
        _error = e;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _etapa = _Etapa.error;
        _error = ErrorAnalisis(TipoErrorAnalisis.desconocido, '$e');
      });
    } finally {
      _reloj.stop();
    }
  }

  void _cancelarYVolver() {
    _cancelar?.cancel();
    context.pop();
  }

  /// Objetivos personales del ejercicio, para que el servidor los aplique.
  Map<String, dynamic>? _ajustesDelEjercicio() {
    final propios = ref.read(objetivosProvider)[widget.solicitud.ejercicio];
    if (propios == null || propios.isEmpty) return null;
    return ajustesAJson({widget.solicitud.ejercicio: propios});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final e = ref.watch(especificacionProvider).buscar(widget.solicitud.ejercicio);
    final error = _error;

    return PopScope(
      canPop: _etapa == _Etapa.error,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelarYVolver();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_etapa == _Etapa.error ? 'Análisis' : 'Analizando'),
          actions: [
            IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cancelar', onPressed: _cancelarYVolver),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 8, Medidas.margen, 16),
            child: error != null
                ? _VistaError(error: error, onReintentar: _analizar, onServidor: () => context.go(Rutas.cuenta))
                : Column(
                    children: [
                      const Spacer(),
                      _Pulso(ejercicioId: widget.solicitud.ejercicio),
                      const SizedBox(height: 28),
                      Text(
                        _etapa == _Etapa.subiendo ? 'Subiendo tu video' : 'Analizando tu técnica',
                        style: context.textos.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e?.nombre ?? widget.solicitud.ejercicio,
                        style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
                      ),
                      const Spacer(),
                      Tarjeta(
                        child: Column(
                          children: [
                            _Paso(
                              titulo: 'Subir video',
                              detalle: _etapa == _Etapa.subiendo ? '${(_progreso * 100).round()} %' : 'Listo',
                              estado: _etapa == _Etapa.subiendo ? _EstadoPaso.activo : _EstadoPaso.hecho,
                              progreso: _etapa == _Etapa.subiendo ? _progreso : null,
                            ),
                            _Paso(
                              titulo: 'Detectar 33 puntos del cuerpo y evaluar cada repetición',
                              detalle: _etapa == _Etapa.procesando ? Formato.cronometro(_reloj.elapsed) : null,
                              estado: _etapa == _Etapa.procesando ? _EstadoPaso.activo : _EstadoPaso.pendiente,
                            ),
                            const _Paso(titulo: 'Preparar tu reporte', estado: _EstadoPaso.pendiente, ultimo: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      BotonPrincipal(
                        texto: 'Cancelar',
                        variante: VarianteBoton.secundario,
                        onPressed: _cancelarYVolver,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Pulso extends StatefulWidget {
  final String ejercicioId;
  const _Pulso({required this.ejercicioId});

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => CustomPaint(
          painter: _PintorPulso(t: _ctrl.value, color: p.primario),
          child: child,
        ),
        child: Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(gradient: p.gradiente, shape: BoxShape.circle),
            padding: const EdgeInsets.all(20),
            child: IlustracionEjercicio(
              ejercicioId: widget.ejercicioId,
              animada: true,
              conFondo: false,
              color: AppColores.blanco,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorPulso extends CustomPainter {
  final double t;
  final Color color;
  _PintorPulso({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final fase = (t + i / 3) % 1.0;
      final radio = 66 + fase * (size.shortestSide / 2 - 66);
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..color = color.withValues(alpha: 0.22 * (1 - fase))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // Arco giratorio
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: 76),
      t * 2 * math.pi,
      math.pi / 2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorPulso old) => old.t != t || old.color != color;
}

enum _EstadoPaso { pendiente, activo, hecho }

class _Paso extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final _EstadoPaso estado;
  final double? progreso;
  final bool ultimo;

  const _Paso({required this.titulo, required this.estado, this.detalle, this.progreso, this.ultimo = false});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final Widget icono = switch (estado) {
      _EstadoPaso.hecho => Icon(Icons.check_circle_rounded, color: p.exito, size: 24),
      _EstadoPaso.activo => SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.6, value: progreso),
      ),
      _EstadoPaso.pendiente => Icon(Icons.radio_button_unchecked_rounded, color: p.borde, size: 24),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
      child: Row(
        children: [
          SizedBox(width: 26, child: Center(child: icono)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: context.textos.bodyMedium?.copyWith(
                color: estado == _EstadoPaso.pendiente ? p.textoTerciario : p.texto,
                fontWeight: estado == _EstadoPaso.activo ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (detalle != null) Text(detalle!, style: context.textos.labelMedium?.copyWith(color: p.textoSecundario)),
        ],
      ),
    );
  }
}

class _VistaError extends StatelessWidget {
  final ErrorAnalisis error;
  final VoidCallback onReintentar;
  final VoidCallback onServidor;

  const _VistaError({required this.error, required this.onReintentar, required this.onServidor});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final sinConexion = error.tipo == TipoErrorAnalisis.sinConexion;
    return Column(
      children: [
        const Spacer(),
        IconoCaja(
          icono: sinConexion ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
          color: p.peligro,
          fondo: p.peligroSuave,
          tamano: 84,
        ),
        const SizedBox(height: 22),
        Text(
          sinConexion ? 'Sin conexión con el servidor' : 'No pudimos analizar el video',
          style: context.textos.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          error.mensaje,
          style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
          textAlign: TextAlign.center,
        ),
        if (sinConexion) ...[
          const SizedBox(height: 16),
          Tarjeta(
            color: p.infoSuave,
            colorBorde: p.infoSuave,
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: p.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El modo tiempo real funciona sin servidor: el análisis se hace en tu teléfono.',
                    style: context.textos.bodySmall?.copyWith(color: p.texto),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        BotonPrincipal(texto: 'Reintentar', icono: Icons.refresh_rounded, onPressed: onReintentar),
        const SizedBox(height: 10),
        if (sinConexion)
          BotonPrincipal(
            texto: 'Configurar servidor',
            icono: Icons.dns_outlined,
            variante: VarianteBoton.secundario,
            onPressed: onServidor,
          )
        else
          BotonPrincipal(texto: 'Volver', variante: VarianteBoton.secundario, onPressed: () => context.pop()),
      ],
    );
  }
}
