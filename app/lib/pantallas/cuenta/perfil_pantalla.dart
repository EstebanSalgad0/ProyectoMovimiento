import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/usuario.dart';

/// Datos personales y de salud. También es la configuración inicial tras
/// registrarse ([configuracionInicial]).
class PerfilPantalla extends ConsumerStatefulWidget {
  final bool configuracionInicial;

  const PerfilPantalla({super.key, this.configuracionInicial = false});

  @override
  ConsumerState<PerfilPantalla> createState() => _PerfilPantallaState();
}

class _PerfilPantallaState extends ConsumerState<PerfilPantalla> {
  late final Usuario _u = ref.read(authProvider)!;
  late final _nombre = TextEditingController(text: _u.nombre);
  late final _email = TextEditingController(text: _u.email);
  late final _estatura = TextEditingController(text: _u.estaturaCm?.toString() ?? '');
  late final _peso = TextEditingController(text: _u.pesoKg == null ? '' : Formato.numero(_u.pesoKg!, 1));
  late final _notas = TextEditingController(text: _u.notasSalud);
  late DateTime? _nacimiento = _u.fechaNacimiento;
  late Sexo? _sexo = _u.sexo;
  late Lado? _lado = _u.ladoDominante;
  late NivelActividad? _nivel = _u.nivelActividad;
  late Objetivo? _objetivo = _u.objetivo;
  late RolUsuario _rol = _u.rol;
  late Set<String> _molestias = {..._u.molestias};
  late int _meta = _u.metaSemanal;
  late int _color = _u.colorAvatar;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _estatura, _peso, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  Usuario get _borrador {
    final estatura = int.tryParse(_estatura.text.trim());
    final peso = double.tryParse(_peso.text.trim().replaceAll(',', '.'));
    return _u.copyWith(
      nombre: _nombre.text.trim().isEmpty ? _u.nombre : _nombre.text.trim(),
      email: _email.text.trim(),
      rol: _rol,
      fechaNacimiento: _nacimiento,
      sexo: _sexo,
      estaturaCm: estatura,
      pesoKg: peso,
      borrarEstatura: estatura == null,
      borrarPeso: peso == null,
      ladoDominante: _lado,
      nivelActividad: _nivel,
      objetivo: _objetivo,
      molestias: _molestias.toList(),
      notasSalud: _notas.text.trim(),
      metaSemanal: _meta,
      colorAvatar: _color,
    );
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 60, 1, 1),
      firstDate: DateTime(hoy.year - 110),
      lastDate: DateTime(hoy.year - 12, hoy.month, hoy.day),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Fecha de nacimiento',
    );
    if (f != null) setState(() => _nacimiento = f);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await ref.read(authProvider.notifier).actualizarPerfil(_borrador);
    if (widget.configuracionInicial) {
      await ref.read(configuracionInicialProvider.notifier).completar();
      return; // El router lleva al inicio.
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final borrador = _borrador;
    final inicial = widget.configuracionInicial;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !inicial,
        title: Text(inicial ? 'Configura tu perfil' : 'Mi perfil'),
        actions: [
          if (inicial)
            TextButton(
              onPressed: () => ref.read(configuracionInicialProvider.notifier).completar(),
              child: const Text('Omitir'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 32),
        children: [
          if (inicial) ...[
            Text('¡Hola, ${_u.primerNombre}!', style: context.textos.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Con estos datos adaptamos tus rutinas, tu meta semanal y las referencias de las pruebas. '
              'Puedes cambiarlos cuando quieras.',
              style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
            ),
            const SizedBox(height: 18),
          ],
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarUsuario(usuario: borrador, tamano: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < gradientesAvatar.length; i++)
                            Semantics(
                              label: 'Color ${i + 1}',
                              selected: _color == i,
                              button: true,
                              child: GestureDetector(
                                onTap: () => setState(() => _color = i),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    gradient: gradienteAvatar(i),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _color == i ? p.texto : Colors.transparent, width: 2.5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombre,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline_rounded)),
                ),
                const SizedBox(height: 14),
                Text('Uso la app como', style: context.textos.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<RolUsuario>(
                    segments: const [
                      ButtonSegment(value: RolUsuario.paciente, label: Text('Paciente')),
                      ButtonSegment(value: RolUsuario.profesional, label: Text('Profesional')),
                    ],
                    selected: {_rol},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _rol = s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Datos físicos'),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: p.superficieAlta,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Fecha de nacimiento'),
                    subtitle: Text(
                      _nacimiento == null
                          ? 'Sin indicar'
                          : '${_nacimiento!.day} ${Formato.mesCorto(_nacimiento!.month)} ${_nacimiento!.year} · '
                                '${borrador.edad} años',
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _elegirFecha,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Sexo', style: context.textos.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Sexo.values)
                      ChoiceChip(
                        label: Text(s.etiqueta),
                        selected: _sexo == s,
                        onSelected: (v) => setState(() => _sexo = v ? s : null),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estatura,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        decoration: const InputDecoration(labelText: 'Estatura', suffixText: 'cm'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _peso,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(labelText: 'Peso', suffixText: 'kg'),
                      ),
                    ),
                  ],
                ),
                if (borrador.imc != null) ...[
                  const SizedBox(height: 8),
                  Text('IMC ${Formato.numero(borrador.imc!, 1)}', style: context.textos.bodySmall),
                ],
                const SizedBox(height: 14),
                Text('Lado dominante', style: context.textos.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in Lado.values)
                      ChoiceChip(
                        label: Text(l.etiqueta),
                        selected: _lado == l,
                        onSelected: (v) => setState(() => _lado = v ? l : null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: '¿Qué buscas?'),
          for (final o in Objetivo.values) ...[
            _Opcion(
              titulo: o.etiqueta,
              detalle: o.detalle,
              seleccionada: _objetivo == o,
              onTap: () => setState(() => _objetivo = o),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const EncabezadoSeccion(titulo: 'Actividad física actual'),
          for (final n in NivelActividad.values) ...[
            _Opcion(
              titulo: n.etiqueta,
              detalle: n.detalle,
              seleccionada: _nivel == n,
              onTap: () => setState(() => _nivel = n),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const EncabezadoSeccion(titulo: 'Meta semanal'),
          Tarjeta(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Días de entrenamiento por semana', style: context.textos.titleSmall),
                      const SizedBox(height: 2),
                      Text('Se recomiendan al menos 3 días.', style: context.textos.bodySmall),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Menos días',
                  onPressed: _meta > 1 ? () => setState(() => _meta--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_meta', textAlign: TextAlign.center, style: AppTipo.numero(24, p.texto)),
                ),
                IconButton.outlined(
                  tooltip: 'Más días',
                  onPressed: _meta < 7 ? () => setState(() => _meta++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Salud'),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Tienes molestias en alguna zona?', style: context.textos.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in zonasMolestia.entries)
                      FilterChip(
                        label: Text(z.value),
                        selected: _molestias.contains(z.key),
                        onSelected: (v) =>
                            setState(() => _molestias = v ? {..._molestias, z.key} : ({..._molestias}..remove(z.key))),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notas,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notas para tu profesional (opcional)',
                    hintText: 'Ej.: operación de rodilla derecha en 2024',
                    alignLabelWithHint: true,
                  ),
                ),
                Text(
                  'Estos datos se guardan solo en este teléfono y se incluyen en los reportes que tú compartas.',
                  style: context.textos.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BotonPrincipal(
            texto: inicial ? 'Continuar' : 'Guardar cambios',
            icono: inicial ? Icons.arrow_forward_rounded : Icons.check_rounded,
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final String titulo;
  final String detalle;
  final bool seleccionada;
  final VoidCallback onTap;

  const _Opcion({required this.titulo, required this.detalle, required this.seleccionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: seleccionada ? p.primarioSuave : null,
      colorBorde: seleccionada ? p.primario : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: context.textos.titleSmall?.copyWith(color: seleccionada ? p.primario : null)),
                const SizedBox(height: 2),
                Text(detalle, style: context.textos.bodySmall),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              seleccionada ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              key: ValueKey(seleccionada),
              color: seleccionada ? p.primario : p.textoTerciario,
            ),
          ),
        ],
      ),
    );
  }
}
