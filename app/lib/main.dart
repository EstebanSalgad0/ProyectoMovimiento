import 'package:flutter/material.dart';
import 'core/tema/tema.dart';
import 'rutas.dart';

void main() {
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicina App',
      debugShowCheckedModeBanner: false,
      theme: AppTema.tema,
      initialRoute: Rutas.login,
      routes: Rutas.rutas,
    );
  }
}