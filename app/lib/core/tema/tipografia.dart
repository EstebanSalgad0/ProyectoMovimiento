import 'package:flutter/material.dart';

/// Escala tipográfica (Plus Jakarta Sans, incluida en assets/fuentes: no
/// depende de internet).
class AppTipo {
  static const familia = 'PlusJakartaSans';

  static TextTheme textTheme(Color texto, Color secundario) {
    TextStyle s(double size, FontWeight w, {double? alto, double espaciado = 0, Color? color}) => TextStyle(
      fontFamily: familia,
      fontSize: size,
      fontWeight: w,
      height: alto,
      letterSpacing: espaciado,
      color: color ?? texto,
    );
    return TextTheme(
      displaySmall: s(34, FontWeight.w800, alto: 1.1, espaciado: -0.8),
      headlineMedium: s(28, FontWeight.w800, alto: 1.15, espaciado: -0.6),
      headlineSmall: s(23, FontWeight.w700, alto: 1.2, espaciado: -0.4),
      titleLarge: s(19, FontWeight.w700, alto: 1.25, espaciado: -0.2),
      titleMedium: s(16, FontWeight.w700, alto: 1.3),
      titleSmall: s(14, FontWeight.w600, alto: 1.3),
      bodyLarge: s(16, FontWeight.w400, alto: 1.5),
      bodyMedium: s(14, FontWeight.w400, alto: 1.45),
      bodySmall: s(12.5, FontWeight.w400, alto: 1.4, color: secundario),
      labelLarge: s(15, FontWeight.w700, espaciado: 0.1),
      labelMedium: s(12.5, FontWeight.w600, espaciado: 0.1),
      labelSmall: s(11, FontWeight.w700, espaciado: 0.6),
    );
  }

  /// Números grandes (puntajes, contadores) con cifras de ancho fijo.
  static TextStyle numero(double size, Color color, {FontWeight peso = FontWeight.w800}) => TextStyle(
    fontFamily: familia,
    fontSize: size,
    fontWeight: peso,
    color: color,
    height: 1,
    letterSpacing: -1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
