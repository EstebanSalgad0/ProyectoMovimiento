import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../rutas.dart';

class LoginPantalla extends ConsumerStatefulWidget {
  const LoginPantalla({super.key});

  @override
  ConsumerState<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends ConsumerState<LoginPantalla> {
  final _formulario = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _verContrasena = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    FocusScope.of(context).unfocus();
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).iniciarSesion(_usuarioCtrl.text, _contrasenaCtrl.text);
      // El router redirige a inicio al detectar la sesión.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _usarDemo() {
    _usuarioCtrl.text = 'usuario.prueba';
    _contrasenaCtrl.text = '1234';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado con degradado e ilustración
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: p.gradiente,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 12, 56),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColores.blanco.withValues(alpha: 0.35), width: 1.5),
                              ),
                              child: const LogoMovimiento(tamano: 60),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              AppConfig.nombreApp,
                              style: context.textos.headlineMedium?.copyWith(color: AppColores.blanco),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppConfig.lema,
                              style: context.textos.bodyMedium?.copyWith(
                                color: AppColores.blanco.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 120,
                        height: 140,
                        child: IlustracionEjercicio(
                          ejercicioId: 'zancada',
                          animada: true,
                          conFondo: false,
                          color: AppColores.blanco,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Medidas.margen),
                child: Column(
                  children: [
                    Tarjeta(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formulario,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Iniciar sesión', style: context.textos.titleLarge),
                              const SizedBox(height: 4),
                              Text('Ingresa para continuar con tus sesiones.', style: context.textos.bodySmall),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _usuarioCtrl,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _contrasenaCtrl,
                                obscureText: !_verContrasena,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _ingresar(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                    icon: Icon(
                                      _verContrasena ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setState(() => _verContrasena = !_verContrasena),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: _error == null
                                    ? const SizedBox(height: 22)
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline_rounded, color: p.peligro, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: context.textos.bodySmall?.copyWith(color: p.peligro),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              BotonPrincipal(texto: 'Ingresar', cargando: _cargando, onPressed: _ingresar),
                              const SizedBox(height: 6),
                              Center(
                                child: TextButton(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'La recuperación de contraseña llegará con el backend de usuarios.',
                                      ),
                                    ),
                                  ),
                                  child: const Text('¿Olvidaste tu contraseña?'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Tarjeta(
                      color: p.primarioSuave,
                      colorBorde: p.primarioSuave,
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          Icon(Icons.science_outlined, color: p.primario),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Modo demo: usuario.prueba · 1234',
                              style: context.textos.bodySmall?.copyWith(color: p.primario),
                            ),
                          ),
                          TextButton(onPressed: _usarDemo, child: const Text('Usar')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('¿No tienes cuenta?', style: context.textos.bodyMedium),
                        TextButton(onPressed: () => context.push(Rutas.registro), child: const Text('Crear cuenta')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
