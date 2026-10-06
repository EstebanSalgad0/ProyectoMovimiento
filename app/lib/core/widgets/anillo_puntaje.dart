import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../modelos/sesion.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';
import '../utils/presentacion.dart';

/// Anillo animado con el puntaje (0–100) y su color según el estado.
class AnilloPuntaje extends StatelessWidget {
  final int puntaje;
  final double tamano;
  final double grosor;
  final bool animar;
  final Color? colorPista;
  final Color? colorTexto;
  final String? subtitulo;

  const AnilloPuntaje({
    super.key,
    required this.puntaje,
    this.tamano = 132,
    this.grosor = 12,
    this.animar = true,
    this.colorPista,
    this.colorTexto,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final (color, _) = Presentacion.coloresEstado(p, estadoDePuntaje(puntaje));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animar ? 0 : puntaje.toDouble(), end: puntaje.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, valor, _) {
        return SizedBox(
          width: tamano,
          height: tamano,
          child: CustomPaint(
            painter: _PintorAnillo(
              fraccion: valor / 100,
              color: color,
              pista: colorPista ?? p.superficieAlta,
              grosor: grosor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${valor.round()}', style: AppTipo.numero(tamano * 0.3, colorTexto ?? p.texto)),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo ?? 'de 100',
                    style: context.textos.labelSmall?.copyWith(
                      color: (colorTexto ?? p.textoSecundario).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double fraccion;
  final Color color;
  final Color pista;
  final double grosor;

  _PintorAnillo({required this.fraccion, required this.color, required this.pista, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arco = rect.deflate(grosor / 2);
    final base = Paint()
      ..color = pista
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arco, 0, math.pi * 2, false, base);
    if (fraccion <= 0) return;
    final barrido = math.pi * 2 * fraccion.clamp(0.0, 1.0);
    final relleno = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arco, -math.pi / 2, barrido, false, relleno);
  }

  @override
  bool shouldRepaint(covariant _PintorAnillo old) =>
      old.fraccion != fraccion || old.color != color || old.pista != pista;
}
