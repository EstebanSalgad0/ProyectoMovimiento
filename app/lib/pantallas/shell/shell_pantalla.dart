import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';

/// Estructura con barra de navegación inferior para las 4 secciones principales.
class ShellPantalla extends StatelessWidget {
  final StatefulNavigationShell shell;

  const ShellPantalla({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.paleta.borde)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center_rounded),
              label: 'Entrenar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Cuenta',
            ),
          ],
        ),
      ),
    );
  }
}
