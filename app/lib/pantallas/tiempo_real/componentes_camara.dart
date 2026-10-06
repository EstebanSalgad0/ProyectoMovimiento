import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../modelos/resultado_analisis.dart';
import '../../motor/analizador.dart' show nombresGrupo;
import '../../motor/especificacion.dart';
import '../../motor/puntos.dart';
import '../../rutas.dart';
import 'camara_pose.dart';
import 'controlador_tiempo_real.dart';
import 'pintor_esqueleto.dart';

/// Vista previa de la cámara a pantalla completa con el esqueleto encima.
class VistaCamaraPose extends StatelessWidget {
  final CamaraPose camara;
  final Set<int> destacados;
  final Set<String> zonasConAlerta;
  final bool mostrarEsqueleto;
  final double visibilidadMinima;

  /// Dibujo adicional en las coordenadas de la vista previa (p. ej. el ángulo
  /// del goniómetro).
  final CustomPainter? pintorExtra;

  const VistaCamaraPose({
    super.key,
    required this.camara,
    this.destacados = const {},
    this.zonasConAlerta = const {},
    this.mostrarEsqueleto = true,
    this.visibilidadMinima = 0.5,
    this.pintorExtra,
  });

  @override
  Widget build(BuildContext context) {
    final c = camara.camara;
    if (c == null || !c.value.isInitialized || c.value.previewSize == null) return const SizedBox.shrink();
    final puntos = camara.puntos;
    final tamano = camara.tamanoImagen;
    // En vertical la vista previa tiene la relación de aspecto invertida.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.previewSize!.height,
          height: c.value.previewSize!.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(c),
              if (mostrarEsqueleto && puntos != null && tamano != null)
                CustomPaint(
                  painter: PintorEsqueleto(
                    puntos: puntos,
                    tamanoImagen: tamano,
                    rotacion: camara.rotacion,
                    lente: camara.lente,
                    destacados: destacados,
                    zonasConAlerta: zonasConAlerta,
                    color: PaletaApp.oscuro.acento,
                    colorAlerta: PaletaApp.oscuro.peligro,
                    visibilidadMinima: visibilidadMinima,
                  ),
                ),
              if (pintorExtra != null) CustomPaint(painter: pintorExtra),
            ],
          ),
        ),
      ),
    );
  }
}

Set<int> puntosDeGrupos(EjercicioSpec e) => {for (final g in e.puntosRequeridos) ...gruposPuntos[g] ?? const <int>[]};

/// Degradados arriba y abajo para leer textos sobre cualquier fondo.
class DegradadosCamara extends StatelessWidget {
  final double alturaInferior;
  const DegradadosCamara({super.key, this.alturaInferior = 300});

  Widget _degradado(bool arriba) => IgnorePointer(
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: 170, child: _degradado(true)),
        Positioned(bottom: 0, left: 0, right: 0, height: alturaInferior, child: _degradado(false)),
      ],
    );
  }
}

class BotonCircular extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  const BotonCircular({super.key, required this.icono, required this.tooltip, this.onPressed});

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

/// Barra superior sobre la cámara: cerrar, título, cronómetro y acciones.
class BarraCamara extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Duration? cronometro;
  final VoidCallback onCerrar;
  final List<Widget> acciones;

  const BarraCamara({
    super.key,
    required this.titulo,
    required this.onCerrar,
    this.subtitulo,
    this.cronometro,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          BotonCircular(icono: Icons.close_rounded, tooltip: 'Cerrar', onPressed: onCerrar),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: context.textos.titleMedium?.copyWith(color: AppColores.blanco),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: context.textos.labelMedium?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (cronometro != null)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFF87171), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formato.cronometro(cronometro!),
                        style: AppTipo.numero(13, AppColores.blanco.withValues(alpha: 0.9), peso: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          for (final a in acciones) ...[const SizedBox(width: 6), a],
        ],
      ),
    );
  }
}

/// Estados de la cámara (cargando, sin permiso, error). Si está lista muestra [hijo].
class EstadoCamaraVista extends StatelessWidget {
  final CamaraPose camara;
  final Widget hijo;
  const EstadoCamaraVista({super.key, required this.camara, required this.hijo});

  @override
  Widget build(BuildContext context) {
    return switch (camara.estado) {
      EstadoCamara.iniciando => const MensajeCamara(cargando: true, titulo: 'Preparando la cámara…'),
      EstadoCamara.sinPermiso => ErrorCamara(
        titulo: 'Necesitamos acceso a la cámara',
        texto:
            'Permite el uso de la cámara en la configuración del teléfono para analizar tu movimiento. '
            'Las imágenes se procesan en el teléfono y no se guardan.',
        onReintentar: camara.iniciar,
      ),
      EstadoCamara.sinCamara => const ErrorCamara(
        titulo: 'No encontramos una cámara',
        texto: 'Este dispositivo no tiene una cámara disponible. Puedes analizar un video desde la galería.',
      ),
      EstadoCamara.error => ErrorCamara(
        titulo: 'No se pudo abrir la cámara',
        texto: camara.mensajeError ?? 'Ocurrió un error inesperado.',
        onReintentar: camara.iniciar,
      ),
      EstadoCamara.lista => camara.camara == null ? const MensajeCamara(cargando: true, titulo: 'Reanudando…') : hijo,
    };
  }
}

class MensajeCamara extends StatelessWidget {
  final bool cargando;
  final String titulo;
  const MensajeCamara({super.key, required this.titulo, this.cargando = false});

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

class ErrorCamara extends StatelessWidget {
  final String titulo;
  final String texto;
  final VoidCallback? onReintentar;
  const ErrorCamara({super.key, required this.titulo, required this.texto, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Center(
      child: SingleChildScrollView(
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

/// Guía de encuadre: marco tipo visor y estado de las partes del cuerpo.
class PanelEncuadre extends StatelessWidget {
  final EjercicioSpec ejercicio;
  final List<String> faltantes;
  final bool hayPersona;
  final VoidCallback onComenzar;
  final String? encabezado;

  const PanelEncuadre({
    super.key,
    required this.ejercicio,
    required this.faltantes,
    required this.hayPersona,
    required this.onComenzar,
    this.encabezado,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final listo = faltantes.isEmpty && hayPersona;
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
                if (encabezado != null) ...[
                  Text(encabezado!, style: context.textos.labelMedium?.copyWith(color: p.primario)),
                  const SizedBox(height: 6),
                ],
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
                Text(ejercicio.camara, style: context.textos.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in ejercicio.puntosRequeridos)
                      ChipDato(
                        texto: _capitalizar(nombresGrupo[g]?.split(' ').last ?? g),
                        icono: faltantes.contains(g) || !hayPersona ? Icons.close_rounded : Icons.check_rounded,
                        color: faltantes.contains(g) || !hayPersona ? p.peligro : p.exito,
                        fondo: faltantes.contains(g) || !hayPersona ? p.peligroSuave : p.exitoSuave,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                BotonPrincipal(
                  texto: 'Comenzar ahora',
                  icono: Icons.play_arrow_rounded,
                  variante: VarianteBoton.suave,
                  onPressed: onComenzar,
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

class CuentaRegresivaGrande extends StatelessWidget {
  final int cuenta;
  const CuentaRegresivaGrande({super.key, required this.cuenta});

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
            child: Text('${cuenta < 1 ? 1 : cuenta}', style: AppTipo.numero(84, AppColores.blanco)),
          ),
        ),
      ),
    );
  }
}

class BannerAviso extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final Severidad? severidad;
  const BannerAviso({super.key, required this.titulo, this.detalle, this.severidad});

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

/// Anillo con el contador de repeticiones (o la cuenta de una prueba).
class ContadorRepeticiones extends StatelessWidget {
  final int actual;
  final int? objetivo;
  final String? etiqueta;
  const ContadorRepeticiones({super.key, required this.actual, this.objetivo, this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final color = PaletaApp.oscuro.acento;
    final obj = objetivo;
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: obj == null || obj == 0 ? 0 : (actual / obj).clamp(0.0, 1.0)),
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
                etiqueta ?? (obj == null ? 'reps.' : 'de $obj'),
                style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fase del movimiento y avance hacia el rango mínimo.
class MedidorMovimiento extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  const MedidorMovimiento({super.key, required this.ctrl});

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

/// Indicadores durante la serie: avisos, contador, medidor y botón principal.
class HudEntrenamiento extends StatelessWidget {
  final ControladorTiempoReal ctrl;
  final VoidCallback onBoton;
  final String textoBoton;
  final IconData iconoBoton;

  const HudEntrenamiento({
    super.key,
    required this.ctrl,
    required this.onBoton,
    this.textoBoton = 'Finalizar y ver resultado',
    this.iconoBoton = Icons.stop_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final aviso = ctrl.aviso;
    final mostrarAviso = aviso != null && DateTime.now().difference(aviso.hora) < const Duration(seconds: 4);
    final faltan = ctrl.faltantes;
    final restante = ctrl.tiempoRestante;
    return Column(
      children: [
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: faltan.isNotEmpty && ctrl.estado?.valido == false
              ? BannerAviso(
                  key: const ValueKey('faltan'),
                  titulo: 'No se ven ${nombresGrupo[faltan.first] ?? faltan.first}',
                  detalle: 'Aléjate un poco o ajusta el teléfono.',
                  severidad: Severidad.info,
                )
              : mostrarAviso
              ? BannerAviso(
                  key: ValueKey(aviso.hora),
                  titulo: aviso.titulo,
                  detalle: aviso.detalle,
                  severidad: aviso.severidad,
                )
              : const SizedBox.shrink(),
        ),
        if (restante != null) ...[const SizedBox(height: 18), _TiempoRestante(restante: restante, total: ctrl.limite!)],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ContadorRepeticiones(actual: ctrl.repeticiones, objetivo: restante == null ? ctrl.objetivo : null),
              const SizedBox(width: 14),
              Expanded(child: MedidorMovimiento(ctrl: ctrl)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: onBoton,
            style: FilledButton.styleFrom(
              backgroundColor: AppColores.blanco,
              foregroundColor: AppColores.marino,
              minimumSize: const Size.fromHeight(56),
            ),
            icon: Icon(iconoBoton),
            label: Text(textoBoton),
          ),
        ),
      ],
    );
  }
}

class _TiempoRestante extends StatelessWidget {
  final Duration restante;
  final Duration total;
  const _TiempoRestante({required this.restante, required this.total});

  @override
  Widget build(BuildContext context) {
    final segundos = (restante.inMilliseconds / 1000).ceil();
    final fraccion = total.inMilliseconds == 0 ? 0.0 : restante.inMilliseconds / total.inMilliseconds;
    final color = segundos <= 5 ? PaletaApp.oscuro.peligro : AppColores.blanco;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: fraccion,
              strokeWidth: 7,
              color: color,
              backgroundColor: AppColores.blanco.withValues(alpha: 0.2),
            ),
          ),
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$segundos', style: AppTipo.numero(40, color)),
                Text('segundos', style: context.textos.labelSmall?.copyWith(color: AppColores.blanco)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
