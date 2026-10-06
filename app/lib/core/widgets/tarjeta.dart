import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';

/// Superficie base de la app: fondo, borde suave y esquinas redondeadas.
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? colorBorde;
  final double radio;
  final Gradient? gradiente;

  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.colorBorde,
    this.radio = Medidas.radioL,
    this.gradiente,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final forma = BorderRadius.circular(radio);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradiente == null ? (color ?? p.superficie) : null,
          gradient: gradiente,
          borderRadius: forma,
          border: gradiente == null ? Border.all(color: colorBorde ?? p.borde) : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: forma,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Ícono dentro de un cuadrado redondeado de color suave.
class IconoCaja extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color fondo;
  final double tamano;

  const IconoCaja({super.key, required this.icono, required this.color, required this.fondo, this.tamano = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(tamano * 0.32)),
      child: Icon(icono, color: color, size: tamano * 0.52),
    );
  }
}

/// Píldora pequeña con ícono y texto.
class ChipDato extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Color? color;
  final Color? fondo;

  const ChipDato({super.key, required this.texto, this.icono, this.color, this.fondo});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final c = color ?? p.textoSecundario;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: fondo ?? p.superficieAlta, borderRadius: BorderRadius.circular(40)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 14, color: c), const SizedBox(width: 5)],
          Text(texto, style: context.textos.labelMedium?.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// Título de sección con acción opcional ("Ver todo").
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;
  final EdgeInsetsGeometry padding;

  const EncabezadoSeccion({
    super.key,
    required this.titulo,
    this.accion,
    this.onAccion,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: context.textos.titleMedium)),
          if (accion != null)
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                textStyle: context.textos.labelMedium,
              ),
              child: Text(accion!),
            ),
        ],
      ),
    );
  }
}
