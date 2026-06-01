import 'package:flutter/material.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/boton_principal.dart';
import '../../rutas.dart';
import '../../servicios/auth_servicios.dart';

class CuentaPantalla extends StatelessWidget {
  const CuentaPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = AuthServicio.usuarioActual;
    final iniciales = usuario
        .split('.')
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();

    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(
        titulo: 'Cuenta',
        centrado: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card usuario
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColores.fondoCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColores.bordeDefault),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColores.azulDark,
                    child: Text(iniciales, style: AppTipo.bodyMedium()
                        .copyWith(color: AppColores.textoSobreAzul)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.toUpperCase(), style: AppTipo.bodyMedium()
                          .copyWith(color: AppColores.textoPrincipal)),
                      Text('${usuario.toLowerCase()}@login.cl',
                          style: AppTipo.caption()
                              .copyWith(color: AppColores.textoSecundario)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card cerrar sesión
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: AppColores.fondoCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColores.bordeDefault),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: AppColores.peligroBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColores.rojoCerrarSesion, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('¿Cerrar sesión?', style: AppTipo.cardTitle()
                      .copyWith(color: AppColores.textoPrincipal)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón cerrar sesión
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  AuthServicio.logout();
                  Navigator.pushReplacementNamed(context, Rutas.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.rojoCerrarSesion,
                  foregroundColor: AppColores.textoSobreAzul,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cerrar sesión', style: AppTipo.cardTitle()
                    .copyWith(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),

            // Botón cancelar
            BotonPrincipal(
              texto: 'Cancelar',
              secundario: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}