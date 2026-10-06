import 'package:flutter/material.dart';

import '../../modelos/resultado_analisis.dart';
import '../../modelos/sesion.dart';
import '../tema/colores.dart';

/// Textos, íconos y colores para mostrar datos del motor en la interfaz.
class Presentacion {
  static String categoria(String c) => switch (c) {
    'tren_inferior' => 'Tren inferior',
    'tren_superior' => 'Tren superior',
    'funcional' => 'Funcional',
    _ => 'General',
  };

  static String posicion(String p) => p == 'sentado' ? 'Sentado' : 'De pie';

  static String dificultad(String d) => switch (d) {
    'basica' => 'Básica',
    'intermedia' => 'Intermedia',
    'avanzada' => 'Avanzada',
    _ => d,
  };

  static String vista(String? v) => switch (v) {
    'frontal' => 'De frente',
    'lateral' => 'De costado',
    'oblicua' => 'En diagonal',
    _ => 'Sin determinar',
  };

  static IconData iconoVista(String? v) => switch (v) {
    'lateral' => Icons.switch_left_rounded,
    'frontal' => Icons.person_rounded,
    _ => Icons.videocam_rounded,
  };

  static String zona(String z) => switch (z) {
    'rodillas' => 'Rodillas',
    'cadera' => 'Cadera',
    'tronco' => 'Tronco',
    'hombros' => 'Hombros',
    'codos' => 'Codos',
    'munecas' => 'Muñecas',
    _ => 'General',
  };

  static IconData iconoZona(String zona, [String codigo = '']) {
    if (codigo.endsWith('_RITMO')) return Icons.speed_rounded;
    switch (codigo) {
      case 'CALIDAD_BAJA':
        return Icons.visibility_off_rounded;
      case 'VISTA_RECOMENDADA':
        return Icons.videocam_rounded;
      case 'SIN_REPETICIONES':
      case 'REPETICIONES_INCOMPLETAS':
        return Icons.replay_rounded;
    }
    return switch (zona) {
      'rodillas' => Icons.airline_seat_legroom_extra_rounded,
      'cadera' => Icons.accessibility_rounded,
      'tronco' => Icons.accessibility_new_rounded,
      'hombros' => Icons.sports_gymnastics_rounded,
      'codos' => Icons.fitness_center_rounded,
      'munecas' => Icons.back_hand_rounded,
      _ => Icons.insights_rounded,
    };
  }

  static IconData iconoCategoria(String categoria) => switch (categoria) {
    'tren_inferior' => Icons.airline_seat_legroom_extra_rounded,
    'tren_superior' => Icons.fitness_center_rounded,
    'funcional' => Icons.event_seat_rounded,
    _ => Icons.directions_run_rounded,
  };

  static (Color, Color) coloresSeveridad(PaletaApp p, Severidad s) => switch (s) {
    Severidad.alta => (p.peligro, p.peligroSuave),
    Severidad.moderada => (p.advertencia, p.advertenciaSuave),
    Severidad.leve => (p.info, p.infoSuave),
    Severidad.info => (p.textoSecundario, p.superficieAlta),
  };

  static (Color, Color) coloresEstado(PaletaApp p, EstadoAnalisis e) => switch (e) {
    EstadoAnalisis.correcto => (p.exito, p.exitoSuave),
    EstadoAnalisis.advertencia => (p.advertencia, p.advertenciaSuave),
    EstadoAnalisis.peligro => (p.peligro, p.peligroSuave),
  };

  static String etiquetaEstado(EstadoAnalisis e) => switch (e) {
    EstadoAnalisis.correcto => 'Muy bien',
    EstadoAnalisis.advertencia => 'Mejorable',
    EstadoAnalisis.peligro => 'A corregir',
  };

  static String mensajePuntaje(int puntaje, int repeticiones) {
    if (repeticiones == 0) return 'No logramos contar repeticiones completas en este registro.';
    if (puntaje >= 90) return 'Técnica excelente. ¡Sigue así!';
    if (puntaje >= 80) return 'Muy buena ejecución, con pequeños detalles por pulir.';
    if (puntaje >= 50) return 'Vas bien. Revisa las correcciones para mejorar tu técnica.';
    return 'Hay aspectos importantes por corregir. Revisa las indicaciones con calma.';
  }
}
