import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../rutas.dart';
import '../analizando/analizando_pantalla.dart';
import '../ejercicios/selector_ejercicio.dart';

/// Preparación del análisis de video: elegir ejercicio y grabar o subir un video.
class PreparacionPantalla extends ConsumerStatefulWidget {
  final String? ejercicioInicial;

  const PreparacionPantalla({super.key, this.ejercicioInicial});

  @override
  ConsumerState<PreparacionPantalla> createState() => _PreparacionPantallaState();
}

class _PreparacionPantallaState extends ConsumerState<PreparacionPantalla> {
  late String _ejercicio;
  File? _video;
  VideoPlayerController? _reproductor;
  int? _tamano;

  @override
  void initState() {
    super.initState();
    final spec = ref.read(especificacionProvider);
    _ejercicio = spec.buscar(widget.ejercicioInicial ?? '')?.id ?? spec.ejercicios.first.id;
  }

  @override
  void dispose() {
    _reproductor?.dispose();
    super.dispose();
  }

  Future<void> _elegirVideo(ImageSource fuente) async {
    try {
      final archivo = await ImagePicker().pickVideo(source: fuente, maxDuration: AppConfig.duracionMaximaVideo);
      if (archivo == null) return;
      final video = File(archivo.path);
      final reproductor = VideoPlayerController.file(video);
      await reproductor.initialize();
      await reproductor.setLooping(true);
      final tamano = await video.length();
      final anterior = _reproductor;
      setState(() {
        _video = video;
        _reproductor = reproductor;
        _tamano = tamano;
      });
      await anterior?.dispose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir el video: $e')));
    }
  }

  Future<void> _cambiarEjercicio() async {
    final id = await mostrarSelectorEjercicio(context);
    if (id != null) setState(() => _ejercicio = id);
  }

  void _analizar() {
    final video = _video;
    if (video == null) return;
    _reproductor?.pause();
    context.push(
      Rutas.analizando,
      extra: SolicitudAnalisis(video: video, ejercicio: _ejercicio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final e = ref.watch(especificacionProvider).ejercicio(_ejercicio);
    final reproductor = _reproductor;

    return Scaffold(
      appBar: AppBar(title: const Text('Analizar video')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 24),
        children: [
          const EncabezadoSeccion(titulo: 'Ejercicio'),
          Tarjeta(
            padding: const EdgeInsets.all(10),
            onTap: _cambiarEjercicio,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 64, height: 64, child: IlustracionEjercicio(ejercicioId: e.id)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nombre, style: context.textos.titleMedium),
                      const SizedBox(height: 2),
                      Text(Presentacion.categoria(e.categoria), style: context.textos.bodySmall),
                    ],
                  ),
                ),
                TextButton(onPressed: _cambiarEjercicio, child: const Text('Cambiar')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion(titulo: 'Video'),
          if (reproductor == null)
            Row(
              children: [
                Expanded(
                  child: _OpcionFuente(
                    icono: Icons.videocam_rounded,
                    titulo: 'Grabar',
                    subtitulo: 'Hasta ${AppConfig.duracionMaximaVideo.inSeconds} s',
                    onTap: () => _elegirVideo(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OpcionFuente(
                    icono: Icons.video_library_rounded,
                    titulo: 'Galería',
                    subtitulo: 'Elegir un video',
                    onTap: () => _elegirVideo(ImageSource.gallery),
                  ),
                ),
              ],
            )
          else
            Tarjeta(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(Medidas.radioL)),
                    child: Container(
                      color: Colors.black,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(aspectRatio: reproductor.value.aspectRatio, child: VideoPlayer(reproductor)),
                          ValueListenableBuilder(
                            valueListenable: reproductor,
                            builder: (context, valor, _) => IconButton.filled(
                              iconSize: 34,
                              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.45)),
                              icon: Icon(valor.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              color: AppColores.blanco,
                              tooltip: valor.isPlaying ? 'Pausar' : 'Reproducir',
                              onPressed: () => valor.isPlaying ? reproductor.pause() : reproductor.play(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: p.exito),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Video listo', style: context.textos.titleSmall),
                              Text(
                                [
                                  Formato.segundos(reproductor.value.duration.inMilliseconds / 1000),
                                  if (_tamano != null) Formato.tamanoArchivo(_tamano!),
                                ].join(' · '),
                                style: context.textos.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<ImageSource>(
                          tooltip: 'Cambiar video',
                          onSelected: _elegirVideo,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: ImageSource.camera, child: Text('Grabar otro')),
                            PopupMenuItem(value: ImageSource.gallery, child: Text('Elegir de la galería')),
                          ],
                          child: const Padding(padding: EdgeInsets.all(8), child: Text('Cambiar')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const EncabezadoSeccion(titulo: 'Para un buen análisis'),
          Tarjeta(
            child: Column(
              children: [
                _Consejo(
                  icono: Presentacion.iconoVista(e.vistaRecomendada),
                  titulo: 'Graba ${Presentacion.vista(e.vistaRecomendada).toLowerCase()}',
                  texto: e.camara,
                ),
                const _Consejo(
                  icono: Icons.accessibility_new_rounded,
                  titulo: 'Cuerpo completo en cuadro',
                  texto: 'Que se vean cabeza, manos y pies durante todo el ejercicio.',
                ),
                const _Consejo(
                  icono: Icons.wb_sunny_outlined,
                  titulo: 'Buena iluminación',
                  texto: 'Evita contraluces, sombras fuertes y ropa del mismo color que el fondo.',
                ),
                const _Consejo(
                  icono: Icons.timer_outlined,
                  titulo: 'Entre 3 y 10 repeticiones',
                  texto: 'Videos de 10 a 40 segundos se analizan más rápido.',
                  ultimo: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Medidas.margen, 8, Medidas.margen, 12),
          child: BotonPrincipal(
            texto: _video == null ? 'Elige un video para continuar' : 'Analizar video',
            icono: Icons.auto_awesome_rounded,
            onPressed: _video == null ? null : _analizar,
          ),
        ),
      ),
    );
  }
}

class _OpcionFuente extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionFuente({required this.icono, required this.titulo, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          IconoCaja(icono: icono, color: p.primario, fondo: p.primarioSuave, tamano: 54),
          const SizedBox(height: 12),
          Text(titulo, style: context.textos.titleSmall),
          const SizedBox(height: 2),
          Text(subtitulo, style: context.textos.bodySmall),
        ],
      ),
    );
  }
}

class _Consejo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final bool ultimo;

  const _Consejo({required this.icono, required this.titulo, required this.texto, this.ultimo = false});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: p.primario, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: context.textos.titleSmall),
                const SizedBox(height: 2),
                Text(texto, style: context.textos.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
