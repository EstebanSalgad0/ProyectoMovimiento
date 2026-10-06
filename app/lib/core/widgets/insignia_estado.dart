import 'package:flutter/material.dart';

import '../../modelos/sesion.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';
import '../utils/presentacion.dart';

/// Píldora con el estado de un análisis ("Muy bien", "Mejorable", "A corregir").
class InsigniaEstado extends StatelessWidget {
  final EstadoAnalisis estado;

  const InsigniaEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = Presentacion.coloresEstado(context.paleta, estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(40)),
      child: Text(Presentacion.etiquetaEstado(estado), style: context.textos.labelSmall?.copyWith(color: color)),
    );
  }
}

/// Puntaje compacto en un círculo de color.
class InsigniaPuntaje extends StatelessWidget {
  final int puntaje;
  final double tamano;

  const InsigniaPuntaje({super.key, required this.puntaje, this.tamano = 46});

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = Presentacion.coloresEstado(context.paleta, estadoDePuntaje(puntaje));
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Text('$puntaje', style: AppTipo.numero(tamano * 0.38, color)),
    );
  }
}
