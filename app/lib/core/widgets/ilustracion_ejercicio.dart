import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Ilustración de un ejercicio: un esqueleto estilizado que puede animarse
/// entre la posición inicial y la final. No usa imágenes (solo código), así
/// agregar un ejercicio nuevo es definir dos poses.
class IlustracionEjercicio extends StatefulWidget {
  final String ejercicioId;
  final bool animada;
  final double? progresoFijo;
  final bool conFondo;
  final Color? color;

  const IlustracionEjercicio({
    super.key,
    required this.ejercicioId,
    this.animada = false,
    this.progresoFijo,
    this.conFondo = true,
    this.color,
  });

  @override
  State<IlustracionEjercicio> createState() => _IlustracionEjercicioState();
}

class _IlustracionEjercicioState extends State<IlustracionEjercicio> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.animada) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant IlustracionEjercicio old) {
    super.didUpdateWidget(old);
    if (widget.animada && !_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    if (!widget.animada && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final def = ilustraciones[widget.ejercicioId] ?? ilustraciones['sentadilla']!;
    final lienzo = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = widget.animada ? Curves.easeInOutCubic.transform(_ctrl.value) : (widget.progresoFijo ?? 0.65);
        return CustomPaint(
          painter: _PintorFigura(
            def: def,
            t: t,
            color: widget.color ?? p.primario,
            colorArticulacion: p.superficie,
            colorProp: p.textoTerciario.withValues(alpha: 0.5),
          ),
          size: Size.infinite,
        );
      },
    );
    if (!widget.conFondo) return lienzo;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.primarioSuave, p.acentoSuave],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(6), child: lienzo),
    );
  }
}

/// Pose: articulaciones normalizadas en [0, 1] (y hacia abajo).
/// En vistas laterales, sufijo I = lado cercano / pierna delantera y D = lejano.
typedef Pose = Map<String, Offset>;

class DefIlustracion {
  final Pose inicio;
  final Pose fin;
  final bool lateral;
  final bool silla;
  const DefIlustracion({required this.inicio, required this.fin, this.lateral = false, this.silla = false});
}

const _segmentos = [
  ['hombroI', 'codoI'], ['codoI', 'manoI'], //
  ['hombroI', 'caderaI'], ['caderaI', 'rodillaI'], ['rodillaI', 'tobilloI'], ['tobilloI', 'pieI'],
];
const _segmentosLejanos = [
  ['hombroD', 'codoD'], ['codoD', 'manoD'], //
  ['hombroD', 'caderaD'], ['caderaD', 'rodillaD'], ['rodillaD', 'tobilloD'], ['tobilloD', 'pieD'],
];

Pose _frontal({
  required double cabezaY,
  required double hombroY,
  required double caderaY,
  required Offset codo,
  required Offset mano,
  required Offset rodilla,
  required Offset tobillo,
  double hombroX = 0.40,
  double caderaX = 0.43,
}) {
  Offset s(Offset o) => Offset(1 - o.dx, o.dy);
  final pie = tobillo + const Offset(-0.04, 0.02);
  return {
    'cabeza': Offset(0.5, cabezaY),
    'hombroI': Offset(hombroX, hombroY),
    'hombroD': Offset(1 - hombroX, hombroY),
    'codoI': codo,
    'codoD': s(codo),
    'manoI': mano,
    'manoD': s(mano),
    'caderaI': Offset(caderaX, caderaY),
    'caderaD': Offset(1 - caderaX, caderaY),
    'rodillaI': rodilla,
    'rodillaD': s(rodilla),
    'tobilloI': tobillo,
    'tobilloD': s(tobillo),
    'pieI': pie,
    'pieD': s(pie),
  };
}

Pose _lateral(Map<String, Offset> cerca, {Map<String, Offset>? lejos}) {
  final l = lejos ?? {for (final e in cerca.entries) e.key: e.value + const Offset(-0.025, -0.005)};
  return {
    'cabeza': cerca['cabeza']!,
    for (final k in ['hombro', 'codo', 'mano', 'cadera', 'rodilla', 'tobillo', 'pie']) ...{
      '${k}I': cerca[k]!,
      '${k}D': l[k]!,
    },
  };
}

final ilustraciones = <String, DefIlustracion>{
  'sentadilla': DefIlustracion(
    lateral: true,
    inicio: _lateral({
      'cabeza': const Offset(0.50, 0.11),
      'hombro': const Offset(0.50, 0.25),
      'codo': const Offset(0.52, 0.38),
      'mano': const Offset(0.53, 0.50),
      'cadera': const Offset(0.50, 0.52),
      'rodilla': const Offset(0.51, 0.72),
      'tobillo': const Offset(0.50, 0.91),
      'pie': const Offset(0.59, 0.93),
    }),
    fin: _lateral({
      'cabeza': const Offset(0.57, 0.33),
      'hombro': const Offset(0.51, 0.45),
      'codo': const Offset(0.65, 0.46),
      'mano': const Offset(0.79, 0.45),
      'cadera': const Offset(0.37, 0.69),
      'rodilla': const Offset(0.62, 0.73),
      'tobillo': const Offset(0.50, 0.91),
      'pie': const Offset(0.59, 0.93),
    }),
  ),
  'zancada': DefIlustracion(
    lateral: true,
    inicio: _lateral(
      {
        'cabeza': const Offset(0.50, 0.11),
        'hombro': const Offset(0.50, 0.25),
        'codo': const Offset(0.51, 0.38),
        'mano': const Offset(0.51, 0.50),
        'cadera': const Offset(0.50, 0.52),
        'rodilla': const Offset(0.52, 0.72),
        'tobillo': const Offset(0.51, 0.91),
        'pie': const Offset(0.60, 0.93),
      },
      lejos: {
        'codo': const Offset(0.48, 0.38),
        'mano': const Offset(0.47, 0.50),
        'hombro': const Offset(0.48, 0.25),
        'cadera': const Offset(0.48, 0.52),
        'rodilla': const Offset(0.49, 0.72),
        'tobillo': const Offset(0.48, 0.91),
        'pie': const Offset(0.57, 0.93),
      },
    ),
    fin: _lateral(
      {
        'cabeza': const Offset(0.49, 0.23),
        'hombro': const Offset(0.48, 0.36),
        'codo': const Offset(0.50, 0.49),
        'mano': const Offset(0.50, 0.60),
        'cadera': const Offset(0.47, 0.62),
        'rodilla': const Offset(0.68, 0.70),
        'tobillo': const Offset(0.69, 0.91),
        'pie': const Offset(0.78, 0.93),
      },
      lejos: {
        'codo': const Offset(0.46, 0.49),
        'mano': const Offset(0.45, 0.60),
        'hombro': const Offset(0.46, 0.36),
        'cadera': const Offset(0.45, 0.62),
        'rodilla': const Offset(0.34, 0.85),
        'tobillo': const Offset(0.17, 0.87),
        'pie': const Offset(0.15, 0.93),
      },
    ),
  ),
  'curl_biceps_sentado': DefIlustracion(
    silla: true,
    inicio: _frontal(
      cabezaY: 0.15,
      hombroY: 0.29,
      caderaY: 0.59,
      codo: const Offset(0.37, 0.44),
      mano: const Offset(0.36, 0.58),
      rodilla: const Offset(0.39, 0.67),
      tobillo: const Offset(0.39, 0.91),
    ),
    fin: _frontal(
      cabezaY: 0.15,
      hombroY: 0.29,
      caderaY: 0.59,
      codo: const Offset(0.37, 0.44),
      mano: const Offset(0.39, 0.31),
      rodilla: const Offset(0.39, 0.67),
      tobillo: const Offset(0.39, 0.91),
    ),
  ),
  'press_hombros_sentado': DefIlustracion(
    silla: true,
    inicio: _frontal(
      cabezaY: 0.22,
      hombroY: 0.36,
      caderaY: 0.63,
      codo: const Offset(0.24, 0.38),
      mano: const Offset(0.25, 0.23),
      rodilla: const Offset(0.39, 0.70),
      tobillo: const Offset(0.39, 0.92),
    ),
    fin: _frontal(
      cabezaY: 0.22,
      hombroY: 0.36,
      caderaY: 0.63,
      codo: const Offset(0.31, 0.20),
      mano: const Offset(0.37, 0.05),
      rodilla: const Offset(0.39, 0.70),
      tobillo: const Offset(0.39, 0.92),
    ),
  ),
  'elevacion_lateral': DefIlustracion(
    inicio: _frontal(
      cabezaY: 0.11,
      hombroY: 0.25,
      caderaY: 0.52,
      codo: const Offset(0.37, 0.39),
      mano: const Offset(0.36, 0.51),
      rodilla: const Offset(0.43, 0.72),
      tobillo: const Offset(0.43, 0.91),
    ),
    fin: _frontal(
      cabezaY: 0.11,
      hombroY: 0.25,
      caderaY: 0.52,
      codo: const Offset(0.25, 0.27),
      mano: const Offset(0.12, 0.25),
      rodilla: const Offset(0.43, 0.72),
      tobillo: const Offset(0.43, 0.91),
    ),
  ),
  'sentarse_pararse': DefIlustracion(
    lateral: true,
    silla: true,
    inicio: _lateral({
      'cabeza': const Offset(0.47, 0.23),
      'hombro': const Offset(0.44, 0.36),
      'codo': const Offset(0.53, 0.45),
      'mano': const Offset(0.47, 0.40),
      'cadera': const Offset(0.40, 0.62),
      'rodilla': const Offset(0.61, 0.63),
      'tobillo': const Offset(0.61, 0.90),
      'pie': const Offset(0.70, 0.92),
    }),
    fin: _lateral({
      'cabeza': const Offset(0.56, 0.12),
      'hombro': const Offset(0.54, 0.26),
      'codo': const Offset(0.62, 0.35),
      'mano': const Offset(0.56, 0.31),
      'cadera': const Offset(0.53, 0.52),
      'rodilla': const Offset(0.58, 0.71),
      'tobillo': const Offset(0.61, 0.90),
      'pie': const Offset(0.70, 0.92),
    }),
  ),
};

class _PintorFigura extends CustomPainter {
  final DefIlustracion def;
  final double t;
  final Color color;
  final Color colorArticulacion;
  final Color colorProp;

  _PintorFigura({
    required this.def,
    required this.t,
    required this.color,
    required this.colorArticulacion,
    required this.colorProp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final origen = Offset((size.width - lado) / 2, (size.height - lado) / 2);
    Offset pos(String k) {
      final a = def.inicio[k]!, b = def.fin[k]!;
      return origen + Offset(lerpDouble(a.dx, b.dx, t)! * lado, lerpDouble(a.dy, b.dy, t)! * lado);
    }

    final grosor = lado * 0.045;
    if (def.silla) _pintarSilla(canvas, origen, lado);

    final suelo = Paint()
      ..color = colorProp
      ..strokeWidth = lado * 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origen + Offset(lado * 0.12, lado * 0.955), origen + Offset(lado * 0.88, lado * 0.955), suelo);

    Paint trazo(double alfa) => Paint()
      ..color = color.withValues(alpha: alfa)
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Lado lejano primero, más tenue, para dar profundidad.
    final lejano = trazo(def.lateral ? 0.38 : 1);
    for (final s in _segmentosLejanos) {
      canvas.drawLine(pos(s[0]), pos(s[1]), lejano);
    }
    final cercano = trazo(1);
    canvas.drawLine(pos('hombroI'), pos('hombroD'), def.lateral ? lejano : cercano);
    canvas.drawLine(pos('caderaI'), pos('caderaD'), def.lateral ? lejano : cercano);
    for (final s in _segmentos) {
      canvas.drawLine(pos(s[0]), pos(s[1]), cercano);
    }

    // Cuello y cabeza
    final hombros = Offset.lerp(pos('hombroI'), pos('hombroD'), 0.5)!;
    final cabeza = pos('cabeza');
    canvas.drawLine(hombros, Offset.lerp(hombros, cabeza, 0.55)!, cercano);
    canvas.drawCircle(cabeza, lado * 0.062, Paint()..color = color);

    // Articulaciones como en el seguimiento de pose
    final relleno = Paint()..color = colorArticulacion;
    final borde = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor * 0.45;
    for (final k in [
      'codoI',
      'rodillaI',
      'caderaI',
      'hombroI',
      'manoI',
      if (!def.lateral) ...['codoD', 'rodillaD', 'caderaD', 'hombroD', 'manoD'],
    ]) {
      final c = pos(k);
      canvas.drawCircle(c, grosor * 0.55, relleno);
      canvas.drawCircle(c, grosor * 0.55, borde);
    }
  }

  void _pintarSilla(Canvas canvas, Offset o, double lado) {
    final p = Paint()
      ..color = colorProp
      ..strokeWidth = lado * 0.028
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (def.lateral) {
      final asiento = lado * 0.655;
      canvas.drawLine(o + Offset(lado * 0.24, asiento), o + Offset(lado * 0.47, asiento), p);
      canvas.drawLine(o + Offset(lado * 0.26, asiento), o + Offset(lado * 0.26, lado * 0.94), p);
      canvas.drawLine(o + Offset(lado * 0.45, asiento), o + Offset(lado * 0.45, lado * 0.94), p);
      canvas.drawLine(o + Offset(lado * 0.24, asiento), o + Offset(lado * 0.22, lado * 0.36), p);
    } else {
      final asiento = lado * 0.66;
      canvas.drawLine(o + Offset(lado * 0.30, asiento), o + Offset(lado * 0.70, asiento), p);
      canvas.drawLine(o + Offset(lado * 0.32, asiento), o + Offset(lado * 0.32, lado * 0.94), p);
      canvas.drawLine(o + Offset(lado * 0.68, asiento), o + Offset(lado * 0.68, lado * 0.94), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorFigura old) => old.t != t || old.color != color || old.def != def;
}
