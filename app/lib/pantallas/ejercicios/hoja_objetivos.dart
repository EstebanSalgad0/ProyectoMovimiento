import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/colores.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../estado/proveedores.dart';
import '../../modelos/resultado_analisis.dart';
import '../../motor/especificacion.dart';

/// Ajustes personales de las verificaciones de un ejercicio: cambiar el
/// umbral o desactivar una revisión (p. ej., menos profundidad tras una
/// cirugía de rodilla). Se aplican en tiempo real y en el análisis de video.
Future<void> mostrarHojaObjetivos(BuildContext context, String ejercicioId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => _HojaObjetivos(ejercicioId: ejercicioId, scroll: scroll),
    ),
  );
}

String formatoUmbral(double v, RangoAjuste r) => switch (r.unidad) {
  '°' => '${v.round()}°',
  's' => '${Formato.numero(v, 1)} s',
  _ => Formato.numero(v, 2),
};

class _HojaObjetivos extends ConsumerWidget {
  final String ejercicioId;
  final ScrollController scroll;
  const _HojaObjetivos({required this.ejercicioId, required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final e = ref.watch(especificacionProvider).buscar(ejercicioId);
    final ajustes = ref.watch(objetivosProvider)[ejercicioId] ?? const <String, AjusteVerificacion>{};
    if (e == null) return const SizedBox.shrink();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('Objetivos personalizados', style: context.textos.titleLarge)),
            if (ajustes.isNotEmpty)
              TextButton.icon(
                onPressed: () => ref.read(objetivosProvider.notifier).restablecer(ejercicioId),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Restablecer'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Adapta lo que revisa la IA en «${e.nombre}» a tu condición. Úsalo con la guía de tu profesional.',
          style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
        ),
        const SizedBox(height: 16),
        for (final v in e.verificaciones) ...[
          _FilaObjetivo(
            key: ValueKey('${v.codigo}-${ajustes[v.codigo]?.umbral}-${ajustes[v.codigo]?.activa}'),
            ejercicioId: ejercicioId,
            verificacion: v,
            ajuste: ajustes[v.codigo],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FilaObjetivo extends ConsumerStatefulWidget {
  final String ejercicioId;
  final Verificacion verificacion;
  final AjusteVerificacion? ajuste;

  const _FilaObjetivo({super.key, required this.ejercicioId, required this.verificacion, this.ajuste});

  @override
  ConsumerState<_FilaObjetivo> createState() => _FilaObjetivoState();
}

class _FilaObjetivoState extends ConsumerState<_FilaObjetivo> {
  late double _valor = widget.ajuste?.umbral ?? widget.verificacion.umbral;

  bool get _activa => widget.ajuste?.activa ?? true;

  void _guardar({double? umbral, bool? activa}) {
    final v = widget.verificacion;
    final nuevoUmbral = umbral ?? _valor;
    final nuevaActiva = activa ?? _activa;
    final igualBase = (nuevoUmbral - v.umbral).abs() < 1e-9 && nuevaActiva;
    ref
        .read(objetivosProvider.notifier)
        .ajustar(
          widget.ejercicioId,
          v.codigo,
          igualBase
              ? null
              : AjusteVerificacion(
                  umbral: (nuevoUmbral - v.umbral).abs() < 1e-9 ? null : nuevoUmbral,
                  activa: nuevaActiva,
                ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final v = widget.verificacion;
    final r = v.rangoAjuste;
    final valor = _valor.clamp(r.min, r.max).toDouble();
    final cambiado = (valor - v.umbral).abs() > 1e-9;
    final divisiones = ((r.max - r.min) / r.paso).round();
    final (color, _) = Presentacion.coloresSeveridad(p, Severidad.desde(v.severidad));
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _activa ? p.superficie : p.superficieAlta,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cambiado || !_activa ? p.primario.withValues(alpha: 0.5) : p.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v.titulo,
                  style: context.textos.titleSmall?.copyWith(color: _activa ? null : p.textoTerciario),
                ),
              ),
              Switch(
                value: _activa,
                onChanged: (a) => _guardar(activa: a),
              ),
            ],
          ),
          if (_activa) ...[
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: valor,
                    min: r.min,
                    max: r.max,
                    divisions: divisiones > 0 ? divisiones : null,
                    label: formatoUmbral(valor, r),
                    activeColor: cambiado ? p.primario : color,
                    onChanged: (x) => setState(() => _valor = x),
                    onChangeEnd: (x) => _guardar(umbral: x),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    formatoUmbral(valor, r),
                    textAlign: TextAlign.end,
                    style: context.textos.titleSmall?.copyWith(color: cambiado ? p.primario : null),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                cambiado ? 'Recomendado: ${formatoUmbral(v.umbral, r)}' : 'Valor recomendado',
                style: context.textos.bodySmall,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text('No se revisará ni restará puntaje.', style: context.textos.bodySmall),
            ),
        ],
      ),
    );
  }
}
