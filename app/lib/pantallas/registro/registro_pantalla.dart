import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/usuario.dart';

class RegistroPantalla extends ConsumerStatefulWidget {
  const RegistroPantalla({super.key});

  @override
  ConsumerState<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends ConsumerState<RegistroPantalla> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  RolUsuario _rol = RolUsuario.paciente;
  bool _acepta = false;
  bool _ver = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _usuario, _email, _contrasena, _confirmacion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    FocusScope.of(context).unfocus();
    if (!_formulario.currentState!.validate()) return;
    if (!_acepta) {
      setState(() => _error = 'Debes aceptar las condiciones para continuar.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .registrar(
            nombre: _nombre.text,
            usuario: _usuario.text,
            email: _email.text,
            contrasena: _contrasena.text,
            rol: _rol,
          );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
            children: [
              Text(
                'Crea tu perfil para guardar tus sesiones y seguir tu progreso.',
                style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
              ),
              const SizedBox(height: 20),
              Text('¿Cómo usarás la app?', style: context.textos.titleSmall),
              const SizedBox(height: 10),
              SegmentedButton<RolUsuario>(
                segments: const [
                  ButtonSegment(
                    value: RolUsuario.paciente,
                    label: Text('Entreno yo'),
                    icon: Icon(Icons.directions_run_rounded),
                  ),
                  ButtonSegment(
                    value: RolUsuario.profesional,
                    label: Text('Soy profesional'),
                    icon: Icon(Icons.medical_services_outlined),
                  ),
                ],
                selected: {_rol},
                onSelectionChanged: (s) => setState(() => _rol = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity(vertical: 1)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usuario,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 3) return 'Mínimo 3 caracteres';
                  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(t)) return 'Usa solo letras, números, punto o guion';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Correo no válido',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contrasena,
                obscureText: !_ver,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_ver ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _ver = !_ver),
                  ),
                ),
                validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmacion,
                obscureText: !_ver,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Repite la contraseña',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden' : null,
              ),
              const SizedBox(height: 18),
              Tarjeta(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                color: p.superficieAlta,
                colorBorde: p.superficieAlta,
                onTap: () => setState(() => _acepta = !_acepta),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: _acepta, onChanged: (v) => setState(() => _acepta = v ?? false)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${AppConfig.avisoMedico} Acepto que mis sesiones se guarden en este dispositivo '
                          'para fines del prototipo.',
                          style: context.textos.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: context.textos.bodySmall?.copyWith(color: p.peligro)),
              ],
              const SizedBox(height: 22),
              BotonPrincipal(texto: 'Crear cuenta', cargando: _cargando, onPressed: _crear),
            ],
          ),
        ),
      ),
    );
  }
}
