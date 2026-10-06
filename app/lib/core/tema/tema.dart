import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colores.dart';
import 'tipografia.dart';

/// Radios y espaciados de la app.
class Medidas {
  static const radioS = 10.0;
  static const radioM = 16.0;
  static const radioL = 22.0;
  static const radioXL = 28.0;
  static const margen = 20.0;
}

class AppTema {
  static ThemeData get claro => _construir(PaletaApp.claro, Brightness.light);
  static ThemeData get oscuro => _construir(PaletaApp.oscuro, Brightness.dark);

  static ThemeData _construir(PaletaApp p, Brightness brillo) {
    final esquema = ColorScheme.fromSeed(seedColor: AppColores.azul, brightness: brillo).copyWith(
      primary: p.primario,
      onPrimary: p.sobrePrimario,
      secondary: p.acento,
      surface: p.superficie,
      onSurface: p.texto,
      onSurfaceVariant: p.textoSecundario,
      outline: p.borde,
      outlineVariant: p.borde,
      error: p.peligro,
      surfaceContainerHighest: p.superficieAlta,
      surfaceContainerHigh: p.superficieAlta,
      surfaceContainer: p.superficie,
      surfaceContainerLow: p.superficie,
    );
    final textos = AppTipo.textTheme(p.texto, p.textoSecundario);
    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Medidas.radioM),
      borderSide: BorderSide(color: p.borde),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: p.fondo,
      fontFamily: AppTipo.familia,
      textTheme: textos,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.fondo,
        foregroundColor: p.texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textos.titleLarge,
        systemOverlayStyle: brillo == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: p.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Medidas.radioL),
          side: BorderSide(color: p.borde),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primario,
          foregroundColor: p.sobrePrimario,
          minimumSize: const Size(64, 54),
          textStyle: textos.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioM)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.texto,
          minimumSize: const Size(64, 54),
          side: BorderSide(color: p.borde, width: 1.4),
          textStyle: textos.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioM)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primario, textStyle: textos.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textos.bodyMedium?.copyWith(color: p.textoTerciario),
        labelStyle: textos.bodyMedium?.copyWith(color: p.textoSecundario),
        prefixIconColor: p.textoSecundario,
        suffixIconColor: p.textoSecundario,
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(borderSide: BorderSide(color: p.primario, width: 1.8)),
        errorBorder: bordeCampo.copyWith(borderSide: BorderSide(color: p.peligro)),
        focusedErrorBorder: bordeCampo.copyWith(borderSide: BorderSide(color: p.peligro, width: 1.8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.superficie,
        selectedColor: p.primarioSuave,
        side: BorderSide(color: p.borde),
        labelStyle: textos.labelMedium?.copyWith(color: p.texto),
        secondaryLabelStyle: textos.labelMedium?.copyWith(color: p.primario),
        checkmarkColor: p.primario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarioSuave,
        height: 70,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => textos.labelMedium!.copyWith(
            color: estados.contains(WidgetState.selected) ? p.primario : p.textoSecundario,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) =>
              IconThemeData(color: estados.contains(WidgetState.selected) ? p.primario : p.textoSecundario, size: 24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.superficie,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.borde,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Medidas.radioXL))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioXL)),
        titleTextStyle: textos.titleLarge,
        contentTextStyle: textos.bodyMedium?.copyWith(color: p.textoSecundario),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.texto,
        contentTextStyle: textos.bodyMedium?.copyWith(color: p.superficie),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioM)),
      ),
      dividerTheme: DividerThemeData(color: p.borde, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textoSecundario,
        titleTextStyle: textos.titleSmall,
        subtitleTextStyle: textos.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? p.sobrePrimario : p.textoTerciario,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? p.primario : p.superficieAlta,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? p.primario : p.borde,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (e) => e.contains(WidgetState.selected) ? p.primarioSuave : p.superficie,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (e) => e.contains(WidgetState.selected) ? p.primario : p.textoSecundario,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.borde)),
          textStyle: WidgetStatePropertyAll(textos.labelMedium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primario,
        linearTrackColor: p.superficieAlta,
        circularTrackColor: p.superficieAlta,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
