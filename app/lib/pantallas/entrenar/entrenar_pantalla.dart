import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../ejercicios/catalogo_ejercicios.dart';
import '../evaluaciones/panel_evaluaciones.dart';
import '../rutinas/lista_rutinas.dart';

/// Pestaña "Entrenar": ejercicios sueltos, rutinas guiadas y evaluaciones.
class EntrenarPantalla extends StatefulWidget {
  /// 'ejercicios', 'rutinas' o 'evaluaciones'.
  final String? seccion;

  const EntrenarPantalla({super.key, this.seccion});

  @override
  State<EntrenarPantalla> createState() => _EntrenarPantallaState();
}

class _EntrenarPantallaState extends State<EntrenarPantalla> with SingleTickerProviderStateMixin {
  static const _secciones = ['ejercicios', 'rutinas', 'evaluaciones'];
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: _indice(widget.seccion));

  int _indice(String? s) => s == null ? 0 : _secciones.indexOf(s).clamp(0, 2);

  @override
  void didUpdateWidget(covariant EntrenarPantalla old) {
    super.didUpdateWidget(old);
    if (widget.seccion != null && widget.seccion != old.seccion) _tabs.animateTo(_indice(widget.seccion));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrenar', style: context.textos.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Ejercicios con análisis, rutinas guiadas y pruebas',
                    style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelStyle: context.textos.titleSmall,
              unselectedLabelColor: p.textoSecundario,
              dividerColor: p.borde,
              tabs: const [
                Tab(text: 'Ejercicios'),
                Tab(text: 'Rutinas'),
                Tab(text: 'Evaluaciones'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [CatalogoEjercicios(), ListaRutinas(), PanelEvaluaciones()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
