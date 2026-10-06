import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../estado/proveedores.dart';
import '../../modelos/evaluacion.dart';
import '../../modelos/resultado_analisis.dart' show Severidad;
import '../../modelos/usuario.dart';
import '../../motor/puntos.dart';
import '../tiempo_real/camara_pose.dart';
import '../tiempo_real/ciclo_camara.dart';
import '../tiempo_real/componentes_camara.dart';
import 'controlador_goniometro.dart';

/// Mide el rango de movimiento de una articulación con la cámara, como un
/// goniómetro: muestra el ángulo en vivo y guarda el máximo alcanzado.
class GoniometroPantalla extends ConsumerStatefulWidget {
  final Articulacion? articulacionInicial;

  const GoniometroPantalla({super.key, this.articulacionInicial});

  @override
  ConsumerState<GoniometroPantalla> createState() => _GoniometroPantallaState();
}

class _GoniometroPantallaState extends ConsumerState<GoniometroPantalla>
    with WidgetsBindingObserver, CicloCamara<GoniometroPantalla> {
  late final CamaraPose _camara;
  late final ControladorGoniometro _ctrl;
  bool _guardando = false;

  @override
  CamaraPose? get camaraDelCiclo => _camara;

  @override
  void initState() {
    super.initState();
    final ajustes = ref.read(ajustesProvider);
    _camara = CamaraPose(preferirFrontal: ajustes.camaraFrontal);
    _ctrl = ControladorGoniometro(
      camara: _camara,
      articulacion: widget.articulacionInicial ?? Articulacion.hombro,
      lado: ref.read(authProvider)?.ladoDominante ?? Lado.derecho,
    );
    _camara.iniciar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _camara.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final maximo = _ctrl.maximo;
    final usuario = ref.read(authProvider);
    if (maximo == null || usuario == null) return;
    setState(() => _guardando = true);
    final e = EvaluacionFuncional.rango(
      usuario: usuario.usuario,
      articulacion: _ctrl.articulacion,
      lado: _ctrl.lado,
      maximo: maximo,
    );
    await ref.read(evaluacionesProvider.notifier).agregar(e);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _guardando = false);
    final pct = ((e.fraccionReferencia ?? 0) * 100).round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Guardado: ${e.articulacion!.etiqueta.toLowerCase()} ${e.lado!.etiqueta.toLowerCase()} '
          '${maximo.round()}° ($pct % de la referencia)',
        ),
      ),
    );
    _ctrl.reiniciar();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final (a, b, c) = indicesArticulacion(_ctrl.articulacion, _ctrl.lado);
            return Stack(
              fit: StackFit.expand,
              children: [
                VistaCamaraPose(
                  camara: _camara,
                  destacados: {a, b, c},
                  mostrarEsqueleto: ref.watch(ajustesProvider).mostrarEsqueleto,
                  pintorExtra: _camara.puntos == null || _camara.tamanoImagen == null
                      ? null
                      : _PintorAngulo(
                          puntos: _camara.puntos!,
                          indices: (a, b, c),
                          tamanoImagen: _camara.tamanoImagen!,
                          rotacion: _camara.rotacion,
                          lente: _camara.lente,
                          valor: _ctrl.valor,
                          color: PaletaApp.oscuro.acento,
                        ),
                ),
                const DegradadosCamara(alturaInferior: 380),
                SafeArea(
                  child: Column(
                    children: [
                      BarraCamara(
                        titulo: 'Goniómetro',
                        subtitulo: '${_ctrl.articulacion.movimiento} · lado ${_ctrl.lado.etiqueta.toLowerCase()}',
                        onCerrar: () => context.pop(),
                        acciones: [
                          BotonCircular(
                            icono: Icons.cameraswitch_rounded,
                            tooltip: 'Cambiar cámara',
                            onPressed: _camara.puedeCambiarCamara && _camara.lista ? _camara.cambiarCamara : null,
                          ),
                        ],
                      ),
                      Expanded(
                        child: EstadoCamaraVista(
                          camara: _camara,
                          hijo: _Panel(ctrl: _ctrl, guardando: _guardando, onGuardar: _guardar),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final ControladorGoniometro ctrl;
  final bool guardando;
  final VoidCallback onGuardar;

  const _Panel({required this.ctrl, required this.guardando, required this.onGuardar});

  @override
  Widget build(BuildContext context) {
    final p = PaletaApp.oscuro;
    final blanco70 = AppColores.blanco.withValues(alpha: 0.75);
    final maximo = ctrl.maximo;
    final referencia = ctrl.articulacion.referencia;
    return Column(
      children: [
        const SizedBox(height: 10),
        if (!ctrl.visible)
          BannerAviso(
            titulo: 'No se ve el ${ctrl.articulacion.etiqueta.toLowerCase()} ${ctrl.lado.etiqueta.toLowerCase()}',
            detalle: 'Ubica el teléfono de costado y aléjate hasta que se vea la articulación completa.',
            severidad: Severidad.info,
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColores.blanco.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _Lectura(
                        titulo: 'AHORA',
                        valor: ctrl.valor == null ? '—' : '${ctrl.valor!.round()}°',
                        color: AppColores.blanco,
                      ),
                    ),
                    Expanded(
                      child: _Lectura(
                        titulo: 'MÁXIMO',
                        valor: maximo == null ? '—' : '${maximo.round()}°',
                        color: p.acento,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('REFERENCIA', style: context.textos.labelSmall?.copyWith(color: blanco70)),
                        Text('$referencia°', style: AppTipo.numero(20, blanco70)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maximo == null ? 0 : (maximo / referencia).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: p.acento,
                    backgroundColor: AppColores.blanco.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final a in Articulacion.values) ...[
                        _Opcion(
                          texto: a.etiqueta,
                          seleccionada: ctrl.articulacion == a,
                          onTap: () => ctrl.configurar(articulacion: a),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(width: 1, height: 22, color: AppColores.blanco.withValues(alpha: 0.2)),
                      const SizedBox(width: 6),
                      for (final l in Lado.values) ...[
                        _Opcion(
                          texto: l == Lado.izquierdo ? 'Izq.' : 'Der.',
                          seleccionada: ctrl.lado == l,
                          onTap: () => ctrl.configurar(lado: l),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(ctrl.articulacion.instruccion, style: context.textos.bodySmall?.copyWith(color: blanco70)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ctrl.reiniciar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColores.blanco,
                          side: BorderSide(color: AppColores.blanco.withValues(alpha: 0.4)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reiniciar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: maximo == null || guardando ? null : onGuardar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColores.blanco,
                          foregroundColor: AppColores.marino,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Lectura extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;
  const _Lectura({required this.titulo, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: context.textos.labelSmall?.copyWith(color: AppColores.blanco.withValues(alpha: 0.75))),
        Text(valor, style: AppTipo.numero(38, color)),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;
  const _Opcion({required this.texto, required this.seleccionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionada ? AppColores.blanco : AppColores.blanco.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            texto,
            style: context.textos.labelLarge?.copyWith(color: seleccionada ? AppColores.marino : AppColores.blanco),
          ),
        ),
      ),
    );
  }
}

/// Dibuja los dos segmentos de la articulación y el arco del ángulo.
class _PintorAngulo extends CustomPainter {
  final List<Punto> puntos;
  final (int, int, int) indices;
  final Size tamanoImagen;
  final InputImageRotation rotacion;
  final CameraLensDirection lente;
  final double? valor;
  final Color color;

  _PintorAngulo({
    required this.puntos,
    required this.indices,
    required this.tamanoImagen,
    required this.rotacion,
    required this.lente,
    required this.valor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final (ia, ib, ic) = indices;
    if (valor == null) return;
    Offset o(int i) => aLienzo(puntos[i].x, puntos[i].y, size, tamanoImagen, rotacion, lente);
    final a = o(ia), b = o(ib), c = o(ic);
    final linea = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(b, a, linea)
      ..drawLine(b, c, linea);

    // Arco entre los dos segmentos (por el lado del ángulo interior).
    final radio = math.min(60.0, math.min((a - b).distance, (c - b).distance) * 0.45);
    final angA = math.atan2(a.dy - b.dy, a.dx - b.dx);
    final angC = math.atan2(c.dy - b.dy, c.dx - b.dx);
    var barrido = angC - angA;
    while (barrido > math.pi) {
      barrido -= 2 * math.pi;
    }
    while (barrido < -math.pi) {
      barrido += 2 * math.pi;
    }
    final rect = Rect.fromCircle(center: b, radius: radio);
    canvas
      ..drawArc(rect, angA, barrido, true, Paint()..color = color.withValues(alpha: 0.25))
      ..drawArc(
        rect,
        angA,
        barrido,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawCircle(b, 9, Paint()..color = AppColores.blanco)
      ..drawCircle(b, 6, Paint()..color = color);

    // Valor junto a la articulación.
    final texto = TextPainter(
      text: TextSpan(
        text: '${valor!.round()}°',
        style: AppTipo.numero(
          30,
          AppColores.blanco,
        ).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 8)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final medio = angA + barrido / 2;
    final pos = b + Offset(math.cos(medio + math.pi), math.sin(medio + math.pi)) * (radio + 34);
    texto.paint(canvas, pos - Offset(texto.width / 2, texto.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorAngulo old) => true;
}
