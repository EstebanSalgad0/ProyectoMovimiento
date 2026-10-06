import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../rutas.dart';
import '../../servicios/auth_servicio.dart';
import '../../servicios/servicio_ia.dart';

/// Perfil, logros, ajustes de entrenamiento, apariencia, servidor y datos.
class CuentaPantalla extends ConsumerWidget {
  const CuentaPantalla({super.key});

  Future<void> _confirmarCerrarSesion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus sesiones quedan guardadas en este teléfono.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).cerrarSesion();
  }

  Future<void> _cambiarContrasena(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DialogoContrasena());
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final usuario = ref.watch(authProvider);
    final ajustes = ref.watch(ajustesProvider);
    final notificador = ref.read(ajustesProvider.notifier);
    final sesiones = ref.watch(historialProvider).value?.length ?? 0;
    final logros = ref.watch(logrosProvider);
    final desbloqueados = logros.where((l) => l.desbloqueado).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Medidas.margen, 16, Medidas.margen, 32),
          children: [
            Text('Cuenta', style: context.textos.headlineMedium),
            const SizedBox(height: 16),
            if (usuario != null)
              Tarjeta(
                padding: const EdgeInsets.all(18),
                onTap: () => context.push(Rutas.perfil),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AvatarUsuario(usuario: usuario),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(usuario.nombre, style: context.textos.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                usuario.email.isEmpty ? '@${usuario.usuario}' : usuario.email,
                                style: context.textos.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ChipDato(texto: usuario.rol.etiqueta, color: p.primario, fondo: p.primarioSuave),
                                  ChipDato(texto: Formato.plural(sesiones, 'sesión', 'sesiones')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textoTerciario),
                      ],
                    ),
                    if (usuario.avancePerfil < 1) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: usuario.avancePerfil,
                                minHeight: 7,
                                backgroundColor: p.superficieAlta,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Perfil ${(usuario.avancePerfil * 100).round()} %',
                            style: context.textos.labelMedium?.copyWith(color: p.primario),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Tarjeta(
              onTap: () => context.push(Rutas.logros),
              child: Row(
                children: [
                  IconoCaja(icono: Icons.emoji_events_rounded, color: p.advertencia, fondo: p.advertenciaSuave),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Logros', style: context.textos.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${desbloqueados.length} de ${logros.length} desbloqueados',
                          style: context.textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  for (final l in desbloqueados.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(gradient: p.gradiente, shape: BoxShape.circle),
                        child: Icon(l.icono, size: 16, color: AppColores.blanco),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: p.textoTerciario),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Entrenamiento'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (usuario != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Meta semanal', style: context.textos.bodyLarge),
                                Text('Días de entrenamiento', style: context.textos.bodySmall),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Menos días',
                            onPressed: usuario.metaSemanal > 1
                                ? () => ref
                                      .read(authProvider.notifier)
                                      .actualizarPerfil(usuario.copyWith(metaSemanal: usuario.metaSemanal - 1))
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          Text('${usuario.metaSemanal}', style: AppTipo.numero(20, p.texto)),
                          IconButton(
                            tooltip: 'Más días',
                            onPressed: usuario.metaSemanal < 7
                                ? () => ref
                                      .read(authProvider.notifier)
                                      .actualizarPerfil(usuario.copyWith(metaSemanal: usuario.metaSemanal + 1))
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    secondary: const Icon(Icons.record_voice_over_outlined),
                    title: const Text('Indicaciones por voz'),
                    subtitle: const Text('Cuenta repeticiones y dice qué corregir'),
                    value: ajustes.voz,
                    onChanged: notificador.cambiarVoz,
                  ),
                  if (ajustes.voz)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(value: 0.4, label: Text('Lenta')),
                            ButtonSegment(value: 0.5, label: Text('Normal')),
                            ButtonSegment(value: 0.6, label: Text('Rápida')),
                          ],
                          selected: {ajustes.velocidadVoz},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => notificador.cambiarVelocidadVoz(s.first),
                        ),
                      ),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Vibrar en cada repetición'),
                    value: ajustes.vibracion,
                    onChanged: notificador.cambiarVibracion,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.accessibility_new_rounded),
                    title: const Text('Mostrar esqueleto'),
                    subtitle: const Text('Dibuja los puntos del cuerpo sobre la cámara'),
                    value: ajustes.mostrarEsqueleto,
                    onChanged: notificador.cambiarMostrarEsqueleto,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.camera_front_outlined),
                    title: const Text('Usar cámara frontal'),
                    subtitle: const Text('Para verte mientras entrenas'),
                    value: ajustes.camaraFrontal,
                    onChanged: notificador.cambiarCamaraFrontal,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cuenta regresiva antes de empezar', style: context.textos.bodyLarge),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 3, label: Text('3 s')),
                              ButtonSegment(value: 5, label: Text('5 s')),
                              ButtonSegment(value: 10, label: Text('10 s')),
                            ],
                            selected: {ajustes.cuentaRegresiva},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => notificador.cambiarCuentaRegresiva(s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Apariencia'),
            Tarjeta(
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode_rounded)),
                  ],
                  selected: {ajustes.tema},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => notificador.cambiarTema(s.first),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Servidor de análisis de video'),
            const _TarjetaServidor(),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Cuenta y datos'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Mi perfil'),
                    subtitle: const Text('Datos personales, objetivo y salud'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(Rutas.perfil),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Cambiar contraseña'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _cambiarContrasena(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Datos y privacidad'),
                    subtitle: const Text('Reporte PDF, exportar, borrar datos'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(Rutas.datos),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Acerca de'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text(AppConfig.nombreCompleto),
                    subtitle: Text('Versión ${AppConfig.version} · ${AppConfig.nivelMadurez}'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.health_and_safety_outlined),
                    title: Text('Aviso'),
                    subtitle: Text(AppConfig.avisoMedico),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Licencias de software'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppConfig.nombreCompleto,
                      applicationVersion: AppConfig.version,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BotonPrincipal(
              texto: 'Cerrar sesión',
              icono: Icons.logout_rounded,
              variante: VarianteBoton.secundario,
              onPressed: () => _confirmarCerrarSesion(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoContrasena extends ConsumerStatefulWidget {
  const _DialogoContrasena();

  @override
  ConsumerState<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends ConsumerState<_DialogoContrasena> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nueva.text != _repetida.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(authProvider.notifier).cambiarContrasena(actual: _actual.text, nueva: _nueva.text);
      if (mounted) Navigator.pop(context, true);
    } on ErrorAuth catch (e) {
      setState(() {
        _error = e.mensaje;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _actual,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nueva,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 6 caracteres'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _repetida,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Repite la nueva contraseña', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _TarjetaServidor extends ConsumerStatefulWidget {
  const _TarjetaServidor();

  @override
  ConsumerState<_TarjetaServidor> createState() => _TarjetaServidorState();
}

class _TarjetaServidorState extends ConsumerState<_TarjetaServidor> {
  EstadoServidor? _estado;
  bool _probando = false;

  Future<void> _probar() async {
    setState(() => _probando = true);
    final estado = await ref.read(servicioIAProvider).verificar();
    if (mounted) {
      setState(() {
        _estado = estado;
        _probando = false;
      });
    }
  }

  Future<void> _editar() async {
    final nueva = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoServidor(inicial: ref.read(ajustesProvider).urlServidor),
    );
    if (nueva == null) return;
    await ref.read(ajustesProvider.notifier).cambiarUrlServidor(nueva);
    setState(() => _estado = null);
    await _probar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final url = ref.watch(ajustesProvider.select((a) => a.urlServidor));
    final estado = _estado;
    final (color, texto) = estado == null
        ? (p.textoTerciario, 'Sin verificar')
        : estado.disponible
        ? (p.exito, 'Conectado${estado.version == null ? '' : ' · v${estado.version}'}')
        : (p.peligro, 'Sin conexión');
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoCaja(icono: Icons.dns_outlined, color: p.primario, fondo: p.primarioSuave, tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(url, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(texto, style: context.textos.bodySmall?.copyWith(color: color)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (estado != null && !estado.disponible && estado.detalle != null) ...[
            const SizedBox(height: 10),
            Text(estado.detalle!, style: context.textos.bodySmall),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BotonPrincipal(
                  texto: 'Probar',
                  variante: VarianteBoton.suave,
                  cargando: _probando,
                  onPressed: _probar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BotonPrincipal(texto: 'Cambiar', variante: VarianteBoton.secundario, onPressed: _editar),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Solo se usa para analizar videos. El modo tiempo real funciona sin servidor.',
            style: context.textos.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DialogoServidor extends StatefulWidget {
  final String inicial;
  const _DialogoServidor({required this.inicial});

  @override
  State<_DialogoServidor> createState() => _DialogoServidorState();
}

class _DialogoServidorState extends State<_DialogoServidor> {
  late final _ctrl = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dirección del servidor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'http://192.168.1.50:8000'),
          ),
          const SizedBox(height: 12),
          Text(
            'Emulador Android: http://10.0.2.2:8000\nTeléfono físico: la IP local de tu PC en la misma red Wi-Fi.',
            style: context.textos.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Guardar')),
      ],
    );
  }
}
