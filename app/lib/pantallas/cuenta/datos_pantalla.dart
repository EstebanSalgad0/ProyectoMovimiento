import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/sesion.dart';
import '../../servicios/auth_servicio.dart';
import '../../servicios/exportacion_servicio.dart';

/// Reporte para el profesional, exportación de datos, almacenamiento y
/// eliminación de la cuenta.
class DatosPantalla extends ConsumerStatefulWidget {
  const DatosPantalla({super.key});

  @override
  ConsumerState<DatosPantalla> createState() => _DatosPantallaState();
}

class _DatosPantallaState extends ConsumerState<DatosPantalla> {
  int _dias = 30;
  bool _generando = false;
  bool _exportando = false;
  int? _tamanoVideos;

  @override
  void initState() {
    super.initState();
    _calcularVideos();
  }

  Future<void> _calcularVideos() async {
    try {
      final t = await ref.read(adjuntosServicioProvider).tamanoVideos();
      if (mounted) setState(() => _tamanoVideos = t);
    } catch (_) {}
  }

  void _aviso(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _reporte() async {
    final usuario = ref.read(authProvider);
    if (usuario == null) return;
    setState(() => _generando = true);
    try {
      final (regular, negrita) = await ExportacionServicio.fuentesDeAssets();
      final bytes = await ExportacionServicio.reportePdf(
        usuario: usuario,
        sesiones: ref.read(historialProvider).value ?? const [],
        evaluaciones: ref.read(evaluacionesProvider).value ?? const [],
        spec: ref.read(especificacionProvider),
        regular: regular,
        negrita: negrita,
        dias: _dias,
      );
      final archivo = await ExportacionServicio.guardarTemporal(
        'reporte_${usuario.usuario}_${ExportacionServicio.marcaFecha(DateTime.now())}.pdf',
        bytes,
      );
      await ExportacionServicio.compartir(archivo, asunto: 'Reporte de actividad', tipo: 'application/pdf');
    } catch (e) {
      _aviso('No se pudo generar el reporte: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _exportar() async {
    final usuario = ref.read(authProvider);
    if (usuario == null) return;
    setState(() => _exportando = true);
    try {
      final datos = ExportacionServicio.datosUsuario(
        usuario: usuario,
        sesiones: ref.read(historialProvider).value ?? const [],
        evaluaciones: ref.read(evaluacionesProvider).value ?? const [],
        rutinas: ref.read(rutinasPropiasProvider),
        objetivos: ref.read(objetivosProvider),
      );
      final archivo = await ExportacionServicio.guardarTemporal(
        'datos_${usuario.usuario}_${ExportacionServicio.marcaFecha(DateTime.now())}.json',
        utf8.encode(ExportacionServicio.jsonLegible(datos)),
      );
      await ExportacionServicio.compartir(archivo, asunto: 'Mis datos de Movimiento', tipo: 'application/json');
    } catch (e) {
      _aviso('No se pudieron exportar los datos: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.paleta.peligro),
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _borrarVideos() async {
    if (!await _confirmar(
      '¿Borrar los videos?',
      'Se eliminarán las copias de los videos analizados. Los resultados y esqueletos se mantienen.',
      'Borrar',
    )) {
      return;
    }
    await ref.read(historialProvider.notifier).borrarVideos();
    await _calcularVideos();
    _aviso('Videos eliminados');
  }

  Future<void> _borrarHistorial() async {
    if (!await _confirmar(
      '¿Borrar todo el historial?',
      'Se eliminarán tus sesiones y evaluaciones de este teléfono. Esta acción no se puede deshacer.',
      'Borrar',
    )) {
      return;
    }
    await ref.read(historialProvider.notifier).borrarTodo();
    await ref.read(evaluacionesProvider.notifier).borrarTodo();
    await _calcularVideos();
    _aviso('Historial eliminado');
  }

  Future<void> _eliminarCuenta() async {
    final ctrl = TextEditingController();
    String? error;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se eliminarán tu cuenta y todos tus datos de este teléfono: sesiones, evaluaciones, rutinas y '
                'videos. Escribe tu contraseña para confirmar.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Contraseña', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.paleta.peligro),
              onPressed: () async {
                try {
                  await ref.read(authProvider.notifier).eliminarCuenta(ctrl.text);
                  if (context.mounted) Navigator.pop(context, true);
                } on ErrorAuth catch (e) {
                  setDialog(() => error = e.mensaje);
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (confirmado == true && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final usuario = ref.watch(authProvider);
    final ajustes = ref.watch(ajustesProvider);
    final sesiones = ref.watch(historialProvider).value ?? const <Sesion>[];
    final evaluaciones = ref.watch(evaluacionesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Datos y privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 32),
        children: [
          const EncabezadoSeccion(titulo: 'Compartir con tu profesional'),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconoCaja(icono: Icons.picture_as_pdf_rounded, color: p.peligro, fondo: p.peligroSuave),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reporte en PDF', style: context.textos.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Resumen, técnica por ejercicio, correcciones, dolor y pruebas.',
                            style: context.textos.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 días')),
                      ButtonSegment(value: 30, label: Text('30 días')),
                      ButtonSegment(value: 90, label: Text('90 días')),
                    ],
                    selected: {_dias},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _dias = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                BotonPrincipal(
                  texto: 'Generar y compartir',
                  icono: Icons.ios_share_rounded,
                  cargando: _generando,
                  onPressed: _reporte,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Tus datos'),
          Tarjeta(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Guardado en este teléfono'),
                  subtitle: Text(
                    '${Formato.plural(sesiones.length, 'sesión', 'sesiones')} · '
                    '${Formato.plural(evaluaciones.length, 'evaluación', 'evaluaciones')}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Exportar mis datos'),
                  subtitle: const Text('Archivo JSON con todo tu historial'),
                  trailing: _exportando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _exportando ? null : _exportar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Videos'),
          Tarjeta(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.video_file_outlined),
                  title: const Text('Guardar videos analizados'),
                  subtitle: const Text('Para revisarlos después con el esqueleto encima'),
                  value: ajustes.guardarVideos,
                  onChanged: ref.read(ajustesProvider.notifier).cambiarGuardarVideos,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Borrar videos guardados'),
                  subtitle: Text(_tamanoVideos == null ? 'Calculando…' : Formato.tamanoArchivo(_tamanoVideos!)),
                  onTap: _borrarVideos,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Privacidad'),
          Tarjeta(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Procesamiento en el teléfono'),
                  subtitle: Text(
                    'En tiempo real, las imágenes no salen de tu dispositivo. Los videos solo se envían al servidor '
                    'que tú configures.',
                  ),
                ),
                if (usuario?.consentimientoFecha != null)
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Consentimiento'),
                    subtitle: Text(
                      'Aceptado el ${usuario!.consentimientoFecha!.day} '
                      '${Formato.mesCorto(usuario.consentimientoFecha!.month)} '
                      '${usuario.consentimientoFecha!.year} (versión ${usuario.consentimientoVersion ?? '—'})',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Zona de cuidado'),
          Tarjeta(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: p.peligro),
                  title: Text('Borrar historial', style: TextStyle(color: p.peligro)),
                  subtitle: const Text('Sesiones y evaluaciones de este teléfono'),
                  onTap: _borrarHistorial,
                ),
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: p.peligro),
                  title: Text('Eliminar cuenta', style: TextStyle(color: p.peligro)),
                  subtitle: const Text('Borra tu cuenta y todos tus datos'),
                  onTap: _eliminarCuenta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
