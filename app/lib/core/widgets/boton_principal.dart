import 'package:flutter/material.dart';

import '../tema/colores.dart';

enum VarianteBoton { primario, secundario, suave, peligro }

class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final VarianteBoton variante;
  final bool cargando;
  final bool expandido;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.variante = VarianteBoton.primario,
    this.cargando = false,
    this.expandido = true,
  });

  /// Atajo para mantener la API de la v1 (`secundario: true`).
  const BotonPrincipal.secundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.expandido = true,
  }) : variante = VarianteBoton.secundario;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final accion = cargando ? null : onPressed;
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cargando)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: variante == VarianteBoton.secundario ? p.primario : p.sobrePrimario,
            ),
          )
        else if (icono != null)
          Icon(icono, size: 21),
        if (cargando || icono != null) const SizedBox(width: 10),
        Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
      ],
    );

    final Widget boton = switch (variante) {
      VarianteBoton.primario => FilledButton(onPressed: accion, child: contenido),
      VarianteBoton.secundario => OutlinedButton(onPressed: accion, child: contenido),
      VarianteBoton.suave => FilledButton(
        onPressed: accion,
        style: FilledButton.styleFrom(backgroundColor: p.primarioSuave, foregroundColor: p.primario),
        child: contenido,
      ),
      VarianteBoton.peligro => FilledButton(
        onPressed: accion,
        style: FilledButton.styleFrom(backgroundColor: p.peligro, foregroundColor: AppColores.blanco),
        child: contenido,
      ),
    };
    return expandido ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}
