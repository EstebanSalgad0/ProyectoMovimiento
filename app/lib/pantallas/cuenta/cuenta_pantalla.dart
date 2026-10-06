import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../servicios/servicio_ia.dart';

/// Perfil y ajustes: tema, voz, cámara, servidor de análisis y datos.
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

  Future<void> _confirmarBorrado(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar historial?'),
        content: const Text('Se eliminarán todas tus sesiones de este teléfono. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.paleta.peligro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(historialProvider.notifier).borrarTodo();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historial eliminado')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final usuario = ref.watch(authProvider);
    final ajustes = ref.watch(ajustesProvider);
    final notificador = ref.read(ajustesProvider.notifier);
    final sesiones = ref.watch(historialProvider).value?.length ?? 0;

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
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: p.gradiente, shape: BoxShape.circle),
                      child: Text(
                        usuario.iniciales,
                        style: context.textos.titleLarge?.copyWith(color: AppColores.blanco),
                      ),
                    ),
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
                  ],
                ),
              ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Preferencias'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Apariencia', style: context.textos.titleSmall),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Sistema'),
                                icon: Icon(Icons.brightness_auto_rounded),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Claro'),
                                icon: Icon(Icons.light_mode_rounded),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Oscuro'),
                                icon: Icon(Icons.dark_mode_rounded),
                              ),
                            ],
                            selected: {ajustes.tema},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => notificador.cambiarTema(s.first),
                          ),
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
                  SwitchListTile(
                    secondary: const Icon(Icons.camera_front_outlined),
                    title: const Text('Usar cámara frontal'),
                    subtitle: const Text('Para verte mientras entrenas'),
                    value: ajustes.camaraFrontal,
                    onChanged: notificador.cambiarCamaraFrontal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Servidor de análisis de video'),
            const _TarjetaServidor(),
            const SizedBox(height: 24),

            const EncabezadoSeccion(titulo: 'Datos y privacidad'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Procesamiento en el teléfono'),
                    subtitle: Text('En tiempo real, las imágenes no salen de tu dispositivo.'),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: p.peligro),
                    title: Text('Borrar historial', style: TextStyle(color: p.peligro)),
                    subtitle: const Text('Elimina las sesiones guardadas en este teléfono'),
                    onTap: () => _confirmarBorrado(context, ref),
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
    final ctrl = TextEditingController(text: ref.read(ajustesProvider).urlServidor);
    final nueva = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dirección del servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
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
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
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
