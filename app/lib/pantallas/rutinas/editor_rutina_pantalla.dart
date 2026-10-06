import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/rutina.dart';
import '../../rutas.dart';
import '../ejercicios/selector_ejercicio.dart';

/// Crea o edita una rutina propia: nombre, ejercicios y, para cada uno,
/// series, repeticiones y descanso.
class EditorRutinaPantalla extends ConsumerStatefulWidget {
  final String? rutinaId;

  const EditorRutinaPantalla({super.key, this.rutinaId});

  @override
  ConsumerState<EditorRutinaPantalla> createState() => _EditorRutinaPantallaState();
}

class _EditorRutinaPantallaState extends ConsumerState<EditorRutinaPantalla> {
  late final Rutina? _original = widget.rutinaId == null
      ? null
      : buscarRutina(ref.read(rutinasPropiasProvider), widget.rutinaId!);
  late final _nombre = TextEditingController(text: _original?.nombre ?? '');
  late final _descripcion = TextEditingController(text: _original?.descripcion ?? '');
  late List<ItemRutina> _items = [...?_original?.items];

  /// Claves estables para reordenar sin perder el estado de cada fila.
  late List<int> _claves = [for (var i = 0; i < _items.length; i++) i];
  late int _siguienteClave = _items.length;
  bool _guardando = false;

  bool get _valida => _nombre.text.trim().isNotEmpty && _items.isNotEmpty;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final id = await mostrarSelectorEjercicio(context, titulo: 'Agregar ejercicio');
    if (id == null || !mounted) return;
    final e = ref.read(especificacionProvider).buscar(id);
    setState(() {
      _items = [..._items, ItemRutina(ejercicioId: id, repeticiones: e?.objetivoRepeticiones ?? 10)];
      _claves = [..._claves, _siguienteClave++];
    });
  }

  void _cambiar(int i, ItemRutina nuevo) => setState(() => _items = [..._items]..[i] = nuevo);

  Future<void> _guardar() async {
    if (!_valida) return;
    setState(() => _guardando = true);
    final rutina = Rutina(
      id: _original?.id ?? Rutina.nuevoId(),
      nombre: _nombre.text.trim(),
      descripcion: _descripcion.text.trim(),
      items: _items,
      nivel: _original?.nivel ?? 'basica',
    );
    await ref.read(rutinasPropiasProvider.notifier).guardar(rutina);
    if (!mounted) return;
    if (_original == null) {
      context.pushReplacement(Rutas.rutina(rutina.id));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final spec = ref.watch(especificacionProvider);
    final borrador = Rutina(id: 'borrador', nombre: '', items: _items);
    return Scaffold(
      appBar: AppBar(title: Text(_original == null ? 'Nueva rutina' : 'Editar rutina')),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        buildDefaultDragHandles: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Piernas de los lunes'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descripcion,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Ejercicios', style: context.textos.titleMedium)),
                if (_items.isNotEmpty)
                  Text(
                    '${borrador.totalSeries} series · ~${borrador.minutosEstimados} min',
                    style: context.textos.labelMedium?.copyWith(color: p.textoSecundario),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_items.length > 1) Text('Mantén presionado para reordenar.', style: context.textos.bodySmall),
            const SizedBox(height: 12),
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              BotonPrincipal(
                texto: 'Agregar ejercicio',
                icono: Icons.add_rounded,
                variante: VarianteBoton.suave,
                onPressed: _agregar,
              ),
              const SizedBox(height: 20),
              BotonPrincipal(
                texto: 'Guardar rutina',
                icono: Icons.check_rounded,
                cargando: _guardando,
                onPressed: _valida ? _guardar : null,
              ),
            ],
          ),
        ),
        itemCount: _items.length,
        onReorderItem: (desde, destino) {
          setState(() {
            final lista = [..._items], claves = [..._claves];
            lista.insert(destino, lista.removeAt(desde));
            claves.insert(destino, claves.removeAt(desde));
            _items = lista;
            _claves = claves;
          });
        },
        itemBuilder: (context, i) {
          final item = _items[i];
          final e = spec.buscar(item.ejercicioId);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(_claves[i]),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tarjeta(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: IlustracionEjercicio(ejercicioId: item.ejercicioId),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e?.nombre ?? item.ejercicioId,
                            style: context.textos.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          icon: Icon(Icons.close_rounded, color: p.textoTerciario),
                          onPressed: () => setState(() {
                            _items = [..._items]..removeAt(i);
                            _claves = [..._claves]..removeAt(i);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Contador(
                              etiqueta: 'Series',
                              valor: item.series,
                              min: 1,
                              max: 8,
                              onChanged: (v) => _cambiar(i, item.copyWith(series: v)),
                            ),
                          ),
                          Expanded(
                            child: _Contador(
                              etiqueta: 'Reps.',
                              valor: item.repeticiones,
                              min: 1,
                              max: 40,
                              onChanged: (v) => _cambiar(i, item.copyWith(repeticiones: v)),
                            ),
                          ),
                          Expanded(
                            child: _Contador(
                              etiqueta: 'Descanso',
                              valor: item.descansoS,
                              min: 15,
                              max: 240,
                              paso: 15,
                              sufijo: ' s',
                              onChanged: (v) => _cambiar(i, item.copyWith(descansoS: v)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final int min;
  final int max;
  final int paso;
  final String sufijo;
  final ValueChanged<int> onChanged;

  const _Contador({
    required this.etiqueta,
    required this.valor,
    required this.min,
    required this.max,
    required this.onChanged,
    this.paso = 1,
    this.sufijo = '',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    Widget boton(IconData icono, String tooltip, int? nuevo) => SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: tooltip,
        style: IconButton.styleFrom(backgroundColor: p.superficieAlta),
        onPressed: nuevo == null ? null : () => onChanged(nuevo),
        icon: Icon(icono),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: p.textoSecundario)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              boton(Icons.remove_rounded, 'Menos $etiqueta', valor - paso >= min ? valor - paso : null),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$valor$sufijo', textAlign: TextAlign.center, style: AppTipo.numero(17, p.texto)),
                ),
              ),
              boton(Icons.add_rounded, 'Más $etiqueta', valor + paso <= max ? valor + paso : null),
            ],
          ),
        ],
      ),
    );
  }
}
