import 'package:flutter/material.dart';

/// Colores de marca (constantes, iguales en modo claro y oscuro).
class AppColores {
  static const azul = Color(0xFF2F6FED);
  static const azulOscuro = Color(0xFF1D4FC4);
  static const marino = Color(0xFF14285E);
  static const turquesa = Color(0xFF12B5A5);
  static const blanco = Color(0xFFFFFFFF);
}

/// Paleta semántica que cambia según el tema. Se obtiene con `context.paleta`.
@immutable
class PaletaApp extends ThemeExtension<PaletaApp> {
  final Color fondo;
  final Color superficie;
  final Color superficieAlta;
  final Color borde;
  final Color texto;
  final Color textoSecundario;
  final Color textoTerciario;
  final Color primario;
  final Color primarioSuave;
  final Color sobrePrimario;
  final Color acento;
  final Color acentoSuave;
  final Color exito;
  final Color exitoSuave;
  final Color advertencia;
  final Color advertenciaSuave;
  final Color peligro;
  final Color peligroSuave;
  final Color info;
  final Color infoSuave;
  final List<Color> gradienteHero;

  const PaletaApp({
    required this.fondo,
    required this.superficie,
    required this.superficieAlta,
    required this.borde,
    required this.texto,
    required this.textoSecundario,
    required this.textoTerciario,
    required this.primario,
    required this.primarioSuave,
    required this.sobrePrimario,
    required this.acento,
    required this.acentoSuave,
    required this.exito,
    required this.exitoSuave,
    required this.advertencia,
    required this.advertenciaSuave,
    required this.peligro,
    required this.peligroSuave,
    required this.info,
    required this.infoSuave,
    required this.gradienteHero,
  });

  static const claro = PaletaApp(
    fondo: Color(0xFFF4F6FB),
    superficie: Color(0xFFFFFFFF),
    superficieAlta: Color(0xFFEEF2F9),
    borde: Color(0xFFE3E8F2),
    texto: Color(0xFF0E1726),
    textoSecundario: Color(0xFF55617B),
    textoTerciario: Color(0xFF8792A8),
    primario: AppColores.azul,
    primarioSuave: Color(0xFFE8F0FF),
    sobrePrimario: Color(0xFFFFFFFF),
    acento: AppColores.turquesa,
    acentoSuave: Color(0xFFDDF6F2),
    exito: Color(0xFF15924A),
    exitoSuave: Color(0xFFE2F5E9),
    advertencia: Color(0xFFC46A06),
    advertenciaSuave: Color(0xFFFDF0DC),
    peligro: Color(0xFFD42A2A),
    peligroSuave: Color(0xFFFDE6E6),
    info: Color(0xFF0B7BC0),
    infoSuave: Color(0xFFE0F1FC),
    gradienteHero: [AppColores.marino, AppColores.azul, AppColores.turquesa],
  );

  static const oscuro = PaletaApp(
    fondo: Color(0xFF0A0F1C),
    superficie: Color(0xFF121A2B),
    superficieAlta: Color(0xFF1A2438),
    borde: Color(0xFF26324A),
    texto: Color(0xFFE8EEF9),
    textoSecundario: Color(0xFF9DA9C1),
    textoTerciario: Color(0xFF6E7A94),
    primario: Color(0xFF7AA2FF),
    primarioSuave: Color(0xFF1B2A4F),
    sobrePrimario: Color(0xFF0B1530),
    acento: Color(0xFF2DD4BF),
    acentoSuave: Color(0xFF0F2E2C),
    exito: Color(0xFF4ADE80),
    exitoSuave: Color(0xFF10291B),
    advertencia: Color(0xFFFBBF24),
    advertenciaSuave: Color(0xFF2E2310),
    peligro: Color(0xFFF87171),
    peligroSuave: Color(0xFF2F1518),
    info: Color(0xFF38BDF8),
    infoSuave: Color(0xFF0B2536),
    gradienteHero: [Color(0xFF14285E), Color(0xFF1D4ED8), Color(0xFF0F766E)],
  );

  LinearGradient get gradiente =>
      LinearGradient(colors: gradienteHero, begin: Alignment.topLeft, end: Alignment.bottomRight);

  @override
  PaletaApp copyWith({Color? primario, Color? acento}) => PaletaApp(
    fondo: fondo,
    superficie: superficie,
    superficieAlta: superficieAlta,
    borde: borde,
    texto: texto,
    textoSecundario: textoSecundario,
    textoTerciario: textoTerciario,
    primario: primario ?? this.primario,
    primarioSuave: primarioSuave,
    sobrePrimario: sobrePrimario,
    acento: acento ?? this.acento,
    acentoSuave: acentoSuave,
    exito: exito,
    exitoSuave: exitoSuave,
    advertencia: advertencia,
    advertenciaSuave: advertenciaSuave,
    peligro: peligro,
    peligroSuave: peligroSuave,
    info: info,
    infoSuave: infoSuave,
    gradienteHero: gradienteHero,
  );

  @override
  PaletaApp lerp(ThemeExtension<PaletaApp>? other, double t) {
    if (other is! PaletaApp) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletaApp(
      fondo: c(fondo, other.fondo),
      superficie: c(superficie, other.superficie),
      superficieAlta: c(superficieAlta, other.superficieAlta),
      borde: c(borde, other.borde),
      texto: c(texto, other.texto),
      textoSecundario: c(textoSecundario, other.textoSecundario),
      textoTerciario: c(textoTerciario, other.textoTerciario),
      primario: c(primario, other.primario),
      primarioSuave: c(primarioSuave, other.primarioSuave),
      sobrePrimario: c(sobrePrimario, other.sobrePrimario),
      acento: c(acento, other.acento),
      acentoSuave: c(acentoSuave, other.acentoSuave),
      exito: c(exito, other.exito),
      exitoSuave: c(exitoSuave, other.exitoSuave),
      advertencia: c(advertencia, other.advertencia),
      advertenciaSuave: c(advertenciaSuave, other.advertenciaSuave),
      peligro: c(peligro, other.peligro),
      peligroSuave: c(peligroSuave, other.peligroSuave),
      info: c(info, other.info),
      infoSuave: c(infoSuave, other.infoSuave),
      gradienteHero: [for (var i = 0; i < gradienteHero.length; i++) c(gradienteHero[i], other.gradienteHero[i])],
    );
  }
}

extension ContextoTema on BuildContext {
  PaletaApp get paleta => Theme.of(this).extension<PaletaApp>() ?? PaletaApp.claro;
  TextTheme get textos => Theme.of(this).textTheme;
}
