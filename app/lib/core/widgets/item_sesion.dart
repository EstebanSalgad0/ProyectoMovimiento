import 'package:flutter/material.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';
import 'insignia_estado.dart';


// Acá estoy creando un widget para mostrar los ejercicios reciebtes.
// Tomo los parámetros de nombre fecha estado e icono, RECORDAR ACOTAR SEGÚN MODELO.

class ItemSesion extends StatelessWidget {
  final String nombre;
  final String fecha;
  final EstadoAnalisis estado;
  final IconData icono;

  const ItemSesion({
    super.key,
    required this.nombre,
    required this.fecha,
    required this.estado,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColores.fondoCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.bordeDefault),
      ),
      child: Row(
        children: [
          // Icono
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColores.azulLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: AppColores.azulPrincipal, size: 24),
          ),
          const SizedBox(width: 14),
          // Nombre y fecha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: AppTipo.bodyMedium()
                    .copyWith(color: AppColores.textoPrincipal)),
                const SizedBox(height: 2),
                Text(fecha, style: AppTipo.caption()
                    .copyWith(color: AppColores.textoSecundario)),
              ],
            ),
          ),
          // Insignia
          InsigniaEstado(estado: estado),
        ],
      ),
    );
  }
}