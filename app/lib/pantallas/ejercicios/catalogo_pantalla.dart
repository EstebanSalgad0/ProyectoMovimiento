import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/estadistica.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../motor/especificacion.dart';
import '../../rutas.dart';

class CatalogoPantalla extends ConsumerStatefulWidget {
  const CatalogoPantalla({super.key});

  @override
  ConsumerState<CatalogoPantalla> createState() => _CatalogoPantallaState();
}

class _CatalogoPantallaState extends ConsumerState<CatalogoPantalla> {
  String _filtro = 'todos';
  String _busqueda = '';

  static const _filtros = {
    'todos': 'Todos',
    'tren_inferior': 'Tren inferior',
    'tren_superior': 'Tren superior',
    'funcional': 'Funcional',
  };

  String _normalizar(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final todos = ref.watch(especificacionProvider).ejercicios;
    final q = _normalizar(_busqueda.trim());
    final visibles = todos.where((e) {
      final pasaFiltro = _filtro == 'todos' || e.categoria == _filtro;
      final pasaBusqueda =
          q.isEmpty || _normalizar(e.nombre).contains(q) || e.musculos.any((m) => _normalizar(m).contains(q));
      return pasaFiltro && pasaBusqueda;
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ejercicios', style: context.textos.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${todos.length} movimientos con análisis de técnica',
                      style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o músculo',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Medidas.margen),
                  children: [
                    for (final f in _filtros.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.value),
                          selected: _filtro == f.key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filtro = f.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (visibles.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(Medidas.margen),
                sliver: SliverToBoxAdapter(
                  child: EstadoVacio(
                    icono: Icons.search_off_rounded,
                    titulo: 'Sin resultados',
                    mensaje: 'Prueba con otro nombre o cambia el filtro.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Medidas.margen, 12, Medidas.margen, 32),
                sliver: SliverGrid.builder(
                  itemCount: visibles.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemBuilder: (context, i) => _TarjetaEjercicio(ejercicio: visibles[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEjercicio extends StatelessWidget {
  final EjercicioSpec ejercicio;
  const _TarjetaEjercicio({required this.ejercicio});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Tarjeta(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Rutas.ejercicio(ejercicio.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Medidas.radioL)),
              child: Hero(
                tag: 'ilustracion-${ejercicio.id}',
                child: IlustracionEjercicio(ejercicioId: ejercicio.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ejercicio.nombre, style: context.textos.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Presentacion.iconoCategoria(ejercicio.categoria), size: 14, color: p.textoTerciario),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${Presentacion.dificultad(ejercicio.dificultad)} · ${Presentacion.posicion(ejercicio.posicion)}',
                        style: context.textos.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
