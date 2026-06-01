import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colores.dart';

class AppTema {
  static ThemeData get tema => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColores.fondoApp,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColores.azulPrincipal,
      primary: AppColores.azulPrincipal,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColores.azulPrincipal,
        foregroundColor: AppColores.textoSobreAzul,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColores.fondoCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.bordeDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.bordeDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.azulPrincipal, width: 1.5),
      ),
    ),
  );
}