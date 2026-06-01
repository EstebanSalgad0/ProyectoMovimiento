import 'package:flutter/material.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';

class Encabezado extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final bool mostrarVolver;
  final bool centrado;
  final String? saludo;
  final String? nombreUsuario;
  final VoidCallback? onAvatarTap;

  const Encabezado({
    super.key,
    required this.titulo,
    this.mostrarVolver = false,
    this.centrado = false,
    this.saludo,
    this.nombreUsuario,
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => Size.fromHeight(saludo != null ? 120 : 100);

  @override
  Widget build(BuildContext context) {
    if (saludo != null && nombreUsuario != null) {
      final iniciales = nombreUsuario!
          .split('.')
          .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
          .join();
      return Container(
        color: AppColores.fondoHeader,
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
        alignment: Alignment.bottomLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saludo!,
                    style: AppTipo.caption().copyWith(color: AppColores.textoSobreAzul)),
                const SizedBox(height: 4),
                Text(nombreUsuario!,
                    style: AppTipo.sectionTitle().copyWith(
                        color: AppColores.textoSobreAzul,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColores.azulDark,
                child: Text(iniciales,
                    style: AppTipo.bodyMedium().copyWith(color: AppColores.textoSobreAzul)),
              ),
            ),
          ],
        ),
      );
    }

    // Header estándar
    return Container(
      color: AppColores.fondoHeader,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
      alignment: centrado ? Alignment.bottomCenter : Alignment.bottomLeft,
      child: Row(
        mainAxisAlignment: centrado ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (mostrarVolver) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: AppColores.textoSobreAzul, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Text(titulo,
              style: AppTipo.sectionTitle().copyWith(color: AppColores.textoSobreAzul)),
        ],
      ),
    );
  }
}