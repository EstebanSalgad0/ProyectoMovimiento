import 'package:flutter/material.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';

class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final bool secundario;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: secundario ? AppColores.fondoCard : AppColores.azulPrincipal,
          foregroundColor: secundario ? AppColores.textoPrincipal : AppColores.textoSobreAzul,
          elevation: 0,
          side: secundario ? const BorderSide(color: AppColores.bordeDefault) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(texto, style: AppTipo.cardTitle()),
      ),
    );
  }
}