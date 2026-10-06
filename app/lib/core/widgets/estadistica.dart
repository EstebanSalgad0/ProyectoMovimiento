import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/tipografia.dart';
import 'tarjeta.dart';

/// Indicador numérico compacto (KPI).
class TileEstadistica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color? color;
  final Color? fondo;

  const TileEstadistica({
    super.key,
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.color,
    this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final c = color ?? p.primario;
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoCaja(icono: icono, color: c, fondo: fondo ?? p.primarioSuave, tamano: 34),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: AppTipo.numero(24, p.texto)),
          ),
          const SizedBox(height: 4),
          Text(etiqueta, style: context.textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Mensaje para listas vacías o estados sin datos.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  const EstadoVacio({super.key, required this.icono, required this.titulo, required this.mensaje, this.accion});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          IconoCaja(icono: icono, color: p.primario, fondo: p.primarioSuave, tamano: 56),
          const SizedBox(height: 14),
          Text(titulo, style: context.textos.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            mensaje,
            style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
            textAlign: TextAlign.center,
          ),
          if (accion != null) ...[const SizedBox(height: 18), accion!],
        ],
      ),
    );
  }
}
