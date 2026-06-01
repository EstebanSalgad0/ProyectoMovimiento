import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/boton_principal.dart';
import '../../servicios/auth_servicios.dart';
import '../../servicios/historial_servicio.dart';
import '../../servicios/servicio_ia.dart';
import '../../rutas.dart';

class AnalizandoPantalla extends StatefulWidget {
  const AnalizandoPantalla({super.key});

  @override
  State<AnalizandoPantalla> createState() => _AnalizandoPantallaState();
}

class _AnalizandoPantallaState extends State<AnalizandoPantalla> {
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciado) {
      _iniciado = true;
      _analizarVideo();
    }
  }

  Future<void> _analizarVideo() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final video    = args?['video']    as File?;
    final ejercicio= args?['ejercicio'] as String? ?? 'sentadilla';

    if (video == null) {
      Navigator.pushReplacementNamed(context, Rutas.preparacion);
      return;
    }

    try {
      final resultado = await ServicioIA.analizarVideo(
        video: video,
        ejercicio: ejercicio,
      );

      final usuario = AuthServicio.usuarioActual.isNotEmpty
          ? AuthServicio.usuarioActual
          : 'anonimo';
      final videoNombre = video.path.split(Platform.pathSeparator).last;

      try {
        await HistorialServicio.guardarAnalisis(
          usuario: usuario,
          resultado: resultado,
          videoNombre: videoNombre,
        );
      } catch (_) {
        // Si falla el guardado local, igual mostramos el resultado.
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, Rutas.resultado, arguments: resultado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.pushReplacementNamed(context, Rutas.preparacion);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final nombreVideo = (args?['video'] as File?)?.path.split('\\').last ?? 'video.mp4';
    final ejercicio   = args?['ejercicio'] as String? ?? 'sentadilla';

    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(titulo: 'Analizando', centrado: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card video
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColores.fondoCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColores.bordeDefault),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColores.azulLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: AppColores.azulPrincipal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombreVideo, style: AppTipo.bodyMedium()
                            .copyWith(color: AppColores.textoPrincipal)),
                        Text(ejercicio.replaceAll('_', ' '), style: AppTipo.caption()
                            .copyWith(color: AppColores.textoSecundario)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColores.correctoBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Listo', style: AppTipo.badge()
                        .copyWith(color: AppColores.correctoTexto)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Spinner
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: AppColores.azulLight,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppColores.azulPrincipal,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Procesando tu video', style: AppTipo.cardTitle()
                .copyWith(color: AppColores.textoPrincipal)),
            const SizedBox(height: 4),
            Text('La IA está evaluando tu video', style: AppTipo.caption()
                .copyWith(color: AppColores.textoSecundario)),

            const Spacer(),

            BotonPrincipal(
              texto: 'Cancelar',
              secundario: true,
              onPressed: () => Navigator.pushReplacementNamed(context, Rutas.preparacion),
            ),
          ],
        ),
      ),
    );
  }
}