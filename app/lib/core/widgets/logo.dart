import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Logo de la app: una figura hecha de articulaciones y segmentos (como los
/// puntos que detecta la IA) con un arco de medición en la rodilla.
///
/// También se usa para generar el ícono (ver tool/generar_iconos.py).
class LogoMovimiento extends StatelessWidget {
  final double tamano;

  /// Con el fondo degradado; sin fondo se dibuja solo la figura (capa frontal
  /// del ícono adaptable de Android).
  final bool conFondo;

  /// Esquinas redondeadas (falso para el ícono de iOS, que aplica su máscara).
  final bool redondeado;

  const LogoMovimiento({super.key, this.tamano = 64, this.conFondo = true, this.redondeado = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamano,
      child: CustomPaint(
        painter: PintorLogo(conFondo: conFondo, redondeado: redondeado),
      ),
    );
  }
}

class PintorLogo extends CustomPainter {
  final bool conFondo;
  final bool redondeado;

  const PintorLogo({this.conFondo = true, this.redondeado = true});

  static const _marino = AppColores.marino;
  static const _azul = AppColores.azul;
  static const _turquesa = AppColores.turquesa;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    if (conFondo) {
      final forma = redondeado
          ? RRect.fromRectAndRadius(rect, Radius.circular(s * 0.23))
          : RRect.fromRectXY(rect, 0, 0);
      canvas.drawRRect(
        forma,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_marino, _azul, _turquesa],
            stops: [0, 0.55, 1],
          ).createShader(rect),
      );
      // Brillo suave detrás de la figura.
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.38, Paint()..color = AppColores.blanco.withValues(alpha: 0.07));
    }

    // Sin fondo la figura se reduce a la zona segura del ícono adaptable.
    final escala = conFondo ? 1.0 : 0.66;
    canvas.save();
    canvas.translate(s * (1 - escala) / 2, s * (1 - escala) / 2);
    canvas.scale(escala);

    Offset p(double x, double y) => Offset(x * s, y * s);
    final cabeza = p(0.50, 0.215);
    final hombroI = p(0.405, 0.355), hombroD = p(0.595, 0.355);
    final codoI = p(0.315, 0.265), codoD = p(0.685, 0.265);
    final munecaI = p(0.255, 0.16), munecaD = p(0.745, 0.16);
    final caderaI = p(0.445, 0.585), caderaD = p(0.555, 0.585);
    final rodillaI = p(0.425, 0.725), tobilloI = p(0.425, 0.865);
    final rodillaD = p(0.665, 0.655), tobilloD = p(0.635, 0.805);

    final grosor = s * 0.052;
    final segmento = Paint()
      ..color = AppColores.blanco
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Arco de medición en la rodilla levantada (el "goniómetro").
    final muslo = math.atan2(caderaD.dy - rodillaD.dy, caderaD.dx - rodillaD.dx);
    final pierna = math.atan2(tobilloD.dy - rodillaD.dy, tobilloD.dx - rodillaD.dx);
    var barrido = pierna - muslo;
    while (barrido > math.pi) {
      barrido -= 2 * math.pi;
    }
    while (barrido < -math.pi) {
      barrido += 2 * math.pi;
    }
    final arco = Rect.fromCircle(center: rodillaD, radius: s * 0.115);
    canvas
      ..drawArc(arco, muslo, barrido, true, Paint()..color = const Color(0xFFFFC56B).withValues(alpha: 0.35))
      ..drawArc(
        arco,
        muslo,
        barrido,
        false,
        Paint()
          ..color = const Color(0xFFFFC56B)
          ..strokeWidth = s * 0.018
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

    final tronco = Path()
      ..moveTo(hombroI.dx, hombroI.dy)
      ..lineTo(hombroD.dx, hombroD.dy)
      ..lineTo(caderaD.dx, caderaD.dy)
      ..lineTo(caderaI.dx, caderaI.dy)
      ..close();
    canvas.drawPath(
      tronco,
      Paint()
        ..color = AppColores.blanco
        ..strokeWidth = grosor
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (final (a, b) in [
      (hombroI, codoI),
      (codoI, munecaI),
      (hombroD, codoD),
      (codoD, munecaD),
      (caderaI, rodillaI),
      (rodillaI, tobilloI),
      (caderaD, rodillaD),
      (rodillaD, tobilloD),
    ]) {
      canvas.drawLine(a, b, segmento);
    }

    // Articulaciones: blanco con anillo turquesa, como los puntos de la IA.
    final relleno = Paint()..color = AppColores.blanco;
    final anillo = Paint()
      ..color = _turquesa
      ..strokeWidth = s * 0.016
      ..style = PaintingStyle.stroke;
    for (final j in [codoI, codoD, munecaI, munecaD, rodillaI, tobilloI, rodillaD, tobilloD, hombroI, hombroD]) {
      canvas
        ..drawCircle(j, s * 0.036, relleno)
        ..drawCircle(j, s * 0.036, anillo);
    }
    canvas.drawCircle(cabeza, s * 0.072, relleno);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PintorLogo old) => old.conFondo != conFondo || old.redondeado != redondeado;
}
