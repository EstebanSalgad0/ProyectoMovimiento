import 'package:flutter/material.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';

enum EstadoAnalisis { correcto, advertencia, peligro }

class InsigniaEstado extends StatelessWidget {
  final EstadoAnalisis estado;

  const InsigniaEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (texto, bg, color) = switch (estado) {
      EstadoAnalisis.correcto    => ('Correcto',    AppColores.correctoBg,    AppColores.correctoTexto),
      EstadoAnalisis.advertencia => ('Advertencia', AppColores.advertenciaBg, AppColores.advertenciaTexto),
      EstadoAnalisis.peligro     => ('Peligro',     AppColores.peligroBg,     AppColores.peligroTexto),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto, style: AppTipo.badge().copyWith(color: color)),
    );
  }
}