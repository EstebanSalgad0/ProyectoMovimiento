import 'package:flutter/material.dart';

import '../../modelos/usuario.dart';
import '../tema/colores.dart';

/// Degradados disponibles para el avatar (Usuario.colorAvatar es el índice).
const gradientesAvatar = <List<Color>>[
  [AppColores.marino, AppColores.azul],
  [Color(0xFF0F766E), AppColores.turquesa],
  [Color(0xFF7C3AED), Color(0xFFC084FC)],
  [Color(0xFFC2410C), Color(0xFFFB923C)],
  [Color(0xFFBE185D), Color(0xFFF472B6)],
  [Color(0xFF15803D), Color(0xFF4ADE80)],
];

LinearGradient gradienteAvatar(int indice) => LinearGradient(
  colors: gradientesAvatar[indice.clamp(0, gradientesAvatar.length - 1)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Círculo con las iniciales del usuario sobre su color elegido.
class AvatarUsuario extends StatelessWidget {
  final Usuario usuario;
  final double tamano;
  final int? colorForzado;

  const AvatarUsuario({super.key, required this.usuario, this.tamano = 62, this.colorForzado});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: gradienteAvatar(colorForzado ?? usuario.colorAvatar), shape: BoxShape.circle),
      child: Text(
        usuario.iniciales,
        style: TextStyle(
          color: AppColores.blanco,
          fontWeight: FontWeight.w700,
          fontSize: tamano * 0.36,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}
