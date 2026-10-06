import 'package:flutter/material.dart';

import '../../modelos/sesion.dart';
import '../../modelos/usuario.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';
import 'boton_principal.dart';

/// Pregunta cómo se sintió la persona (esfuerzo y dolor, escalas 0–10).
/// Devuelve null si cierra la hoja sin guardar.
Future<Sensaciones?> mostrarHojaSensaciones(BuildContext context, {Sensaciones? inicial, String? subtitulo}) {
  return showModalBottomSheet<Sensaciones>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _HojaSensaciones(inicial: inicial, subtitulo: subtitulo),
    ),
  );
}

class _HojaSensaciones extends StatefulWidget {
  final Sensaciones? inicial;
  final String? subtitulo;
  const _HojaSensaciones({this.inicial, this.subtitulo});

  @override
  State<_HojaSensaciones> createState() => _HojaSensacionesState();
}

class _HojaSensacionesState extends State<_HojaSensaciones> {
  late double _esfuerzo = (widget.inicial?.esfuerzo ?? 5).toDouble();
  late double _dolor = (widget.inicial?.dolor ?? 0).toDouble();
  late String? _zona = widget.inicial?.zonaDolor;
  late final _nota = TextEditingController(text: widget.inicial?.nota ?? '');

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final dolor = _dolor.round();
    Navigator.pop(
      context,
      Sensaciones(
        esfuerzo: _esfuerzo.round(),
        dolor: dolor,
        zonaDolor: dolor > 0 ? _zona : null,
        nota: _nota.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final dolor = _dolor.round();
    final colorDolor = dolor == 0
        ? p.exito
        : dolor <= 3
        ? p.advertencia
        : p.peligro;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿Cómo te sentiste?', style: context.textos.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.subtitulo ?? 'Ayuda a ajustar tu entrenamiento y queda en tu historial.',
            style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
          ),
          const SizedBox(height: 22),
          _Escala(
            titulo: 'Esfuerzo',
            etiqueta: Sensaciones.etiquetaEsfuerzo(_esfuerzo.round()),
            valor: _esfuerzo,
            color: p.primario,
            onChanged: (v) => setState(() => _esfuerzo = v),
            extremos: ('Reposo', 'Máximo'),
          ),
          const SizedBox(height: 18),
          _Escala(
            titulo: 'Dolor',
            etiqueta: Sensaciones.etiquetaDolor(dolor),
            valor: _dolor,
            color: colorDolor,
            onChanged: (v) => setState(() => _dolor = v),
            extremos: ('Sin dolor', 'El peor'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: dolor == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Dónde?', style: context.textos.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final z in zonasMolestia.entries)
                              ChoiceChip(
                                label: Text(z.value),
                                selected: _zona == z.key,
                                onSelected: (s) => setState(() => _zona = s ? z.key : null),
                              ),
                          ],
                        ),
                        if (dolor >= 7) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: p.peligroSuave, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.health_and_safety_outlined, color: p.peligro, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Un dolor intenso no es normal al ejercitarse. Descansa y consulta con un '
                                    'profesional de la salud antes de volver a entrenar.',
                                    style: context.textos.bodySmall?.copyWith(color: p.texto),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nota,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ej.: me costó la última serie'),
          ),
          const SizedBox(height: 8),
          BotonPrincipal(texto: 'Guardar', icono: Icons.check_rounded, onPressed: _guardar),
        ],
      ),
    );
  }
}

class _Escala extends StatelessWidget {
  final String titulo;
  final String etiqueta;
  final double valor;
  final Color color;
  final ValueChanged<double> onChanged;
  final (String, String) extremos;

  const _Escala({
    required this.titulo,
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.onChanged,
    required this.extremos,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: context.textos.titleSmall)),
            Text(etiqueta, style: context.textos.labelLarge?.copyWith(color: color)),
            const SizedBox(width: 10),
            Text('${valor.round()}', style: AppTipo.numero(24, color)),
            Text('/10', style: context.textos.labelMedium?.copyWith(color: p.textoTerciario)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color),
          child: Slider(
            value: valor,
            max: 10,
            divisions: 10,
            label: '${valor.round()}',
            semanticFormatterCallback: (v) => '$titulo ${v.round()} de 10',
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(extremos.$1, style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
            Text(extremos.$2, style: context.textos.labelSmall?.copyWith(color: p.textoTerciario)),
          ],
        ),
      ],
    );
  }
}

/// Resumen de las sensaciones de una sesión, o invitación a registrarlas.
class TarjetaSensaciones extends StatelessWidget {
  final Sensaciones? sensaciones;
  final VoidCallback onEditar;

  const TarjetaSensaciones({super.key, required this.sensaciones, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final s = sensaciones;
    if (s == null) {
      return Material(
        color: p.primarioSuave,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onEditar,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sentiment_satisfied_alt_rounded, color: p.primario, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Cómo te sentiste?', style: context.textos.titleSmall),
                      const SizedBox(height: 2),
                      Text('Registra tu esfuerzo y si hubo dolor.', style: context.textos.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.primario),
              ],
            ),
          ),
        ),
      );
    }
    final colorDolor = s.dolor == 0
        ? p.exito
        : s.dolor <= 3
        ? p.advertencia
        : p.peligro;
    return Material(
      color: p.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.borde),
      ),
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Cómo te sentiste', style: context.textos.titleSmall)),
                  Icon(Icons.edit_outlined, size: 18, color: p.textoTerciario),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DatoSensacion(
                      titulo: 'Esfuerzo',
                      valor: s.esfuerzo,
                      etiqueta: Sensaciones.etiquetaEsfuerzo(s.esfuerzo),
                      color: p.primario,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatoSensacion(
                      titulo: 'Dolor',
                      valor: s.dolor,
                      etiqueta: [
                        Sensaciones.etiquetaDolor(s.dolor),
                        if (s.zonaDolor != null) zonasMolestia[s.zonaDolor] ?? s.zonaDolor!,
                      ].join(' · '),
                      color: colorDolor,
                    ),
                  ),
                ],
              ),
              if (s.nota.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('“${s.nota}”', style: context.textos.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoSensacion extends StatelessWidget {
  final String titulo;
  final int valor;
  final String etiqueta;
  final Color color;
  const _DatoSensacion({required this.titulo, required this.valor, required this.etiqueta, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: context.textos.labelMedium?.copyWith(color: context.paleta.textoSecundario)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$valor', style: AppTipo.numero(26, color)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text('/10', style: context.textos.labelSmall?.copyWith(color: context.paleta.textoTerciario)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: valor / 10,
            minHeight: 6,
            color: color,
            backgroundColor: context.paleta.superficieAlta,
          ),
        ),
        const SizedBox(height: 6),
        Text(etiqueta, style: context.textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
