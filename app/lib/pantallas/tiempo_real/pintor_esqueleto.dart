import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../motor/puntos.dart';

/// Segmentos del esqueleto asociados a cada zona del cuerpo.
const _segmentosPorZona = <String, List<List<int>>>{
  'rodillas': [
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
  ],
  'cadera': [
    [23, 24],
    [11, 23],
    [12, 24],
  ],
  'tronco': [
    [11, 23],
    [12, 24],
    [11, 12],
  ],
  'hombros': [
    [11, 12],
    [11, 13],
    [12, 14],
  ],
  'codos': [
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
  ],
  'munecas': [
    [13, 15],
    [14, 16],
  ],
};

/// Dibuja los puntos detectados por ML Kit sobre la vista de la cámara.
class PintorEsqueleto extends CustomPainter {
  final List<Punto> puntos;
  final Size tamanoImagen;
  final InputImageRotation rotacion;
  final CameraLensDirection lente;
  final Set<int> destacados;
  final Set<String> zonasConAlerta;
  final Color color;
  final Color colorAlerta;
  final double visibilidadMinima;

  PintorEsqueleto({
    required this.puntos,
    required this.tamanoImagen,
    required this.rotacion,
    required this.lente,
    required this.destacados,
    required this.zonasConAlerta,
    required this.color,
    required this.colorAlerta,
    this.visibilidadMinima = 0.5,
  });

  // Conversión de coordenadas de imagen a lienzo (según el ejemplo oficial de
  // google_mlkit: compensa rotación del sensor y espejo de la cámara frontal).
  double _x(double x, Size lienzo) {
    switch (rotacion) {
      case InputImageRotation.rotation90deg:
        return x * lienzo.width / (Platform.isIOS ? tamanoImagen.width : tamanoImagen.height);
      case InputImageRotation.rotation270deg:
        return lienzo.width - x * lienzo.width / (Platform.isIOS ? tamanoImagen.width : tamanoImagen.height);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return lente == CameraLensDirection.back
            ? x * lienzo.width / tamanoImagen.width
            : lienzo.width - x * lienzo.width / tamanoImagen.width;
    }
  }

  double _y(double y, Size lienzo) {
    switch (rotacion) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * lienzo.height / (Platform.isIOS ? tamanoImagen.height : tamanoImagen.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * lienzo.height / tamanoImagen.height;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset pos(int i) => Offset(_x(puntos[i].x, size), _y(puntos[i].y, size));
    bool visible(int i) => puntos[i].v >= visibilidadMinima;

    final enAlerta = <String>{};
    for (final zona in zonasConAlerta) {
      for (final s in _segmentosPorZona[zona] ?? const <List<int>>[]) {
        enAlerta.add('${s[0]}-${s[1]}');
      }
    }

    final base = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.9);
    final alerta = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = colorAlerta;
    final sombra = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.25);

    for (final s in conexionesEsqueleto) {
      if (!visible(s[0]) || !visible(s[1])) continue;
      canvas.drawLine(pos(s[0]), pos(s[1]), sombra);
      canvas.drawLine(pos(s[0]), pos(s[1]), enAlerta.contains('${s[0]}-${s[1]}') ? alerta : base);
    }

    final relleno = Paint()..color = Colors.white;
    for (var i = 11; i < numPuntos; i++) {
      if (!visible(i) || (i >= 17 && i <= 22)) continue; // se omiten dedos
      final destacado = destacados.contains(i);
      final borde = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = destacado ? 3.5 : 2.5
        ..color = destacado ? color : color.withValues(alpha: 0.7);
      final r = destacado ? 7.0 : 4.5;
      canvas.drawCircle(pos(i), r, relleno);
      canvas.drawCircle(pos(i), r, borde);
    }
    if (visible(nariz)) canvas.drawCircle(pos(nariz), 5, relleno);
  }

  @override
  bool shouldRepaint(covariant PintorEsqueleto old) =>
      !identical(old.puntos, puntos) || old.zonasConAlerta.length != zonasConAlerta.length || old.color != color;
}
