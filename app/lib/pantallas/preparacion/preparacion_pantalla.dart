import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/boton_principal.dart';
import '../../rutas.dart';
import '../../servicios/servicio_ia.dart';
import '../../modelos/resultado_analisis.dart';

class PreparacionPantalla extends StatefulWidget {
  const PreparacionPantalla({super.key});

  @override
  State<PreparacionPantalla> createState() => _PreparacionPantallaState();
}

class _PreparacionPantallaState extends State<PreparacionPantalla> {
  File? _videoSeleccionado;
  String _ejercicioSeleccionado = 'sentadilla';
  bool _cargando = false;

  final List<String> _ejercicios = [
    'sentadilla',
    'zancada',
    'curl_biceps_sentado',
    'press_hombros_sentado',
  ];

  Future<void> _seleccionarVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() => _videoSeleccionado = File(result.files.single.path!));
    }
  }

  Future<void> _analizarVideo() async {
    if (_videoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un video primero')),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      Rutas.analizando,
      arguments: {
        'video': _videoSeleccionado,
        'ejercicio': _ejercicioSeleccionado,
      },
    );
  }

  Widget _itemInstruccion(String numero, String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppColores.azulLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(numero, style: AppTipo.badge()
                  .copyWith(color: AppColores.azulPrincipal)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTipo.bodyMedium()
                  .copyWith(color: AppColores.textoPrincipal)),
              const SizedBox(height: 2),
              Text(subtitulo, style: AppTipo.caption()
                  .copyWith(color: AppColores.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(titulo: 'Preparación', centrado: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Card subir video
          GestureDetector(
            onTap: _seleccionarVideo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 50),
              decoration: BoxDecoration(
                color: AppColores.fondoCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColores.bordeDefault, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColores.azulLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.upload_rounded,
                        color: AppColores.azulPrincipal, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _videoSeleccionado != null
                        ? 'Video subido correctamente'
                        : 'Sube tu video',
                    style: AppTipo.cardTitle().copyWith(
                      color: _videoSeleccionado != null
                          ? AppColores.correctoTexto
                          : AppColores.textoPrincipal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Selector de ejercicio
          Text('Ejercicio', style: AppTipo.labelMedium()
              .copyWith(color: AppColores.textoSecundario)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColores.fondoCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColores.bordeDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ejercicioSeleccionado,
                isExpanded: true,
                style: AppTipo.body().copyWith(color: AppColores.textoPrincipal),
                items: _ejercicios.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.replaceAll('_', ' ')),
                )).toList(),
                onChanged: (v) => setState(() => _ejercicioSeleccionado = v!),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Antes de grabar', style: AppTipo.labelMedium()
              .copyWith(color: AppColores.textoSecundario)),
          const SizedBox(height: 12),
          _itemInstruccion('1', 'Graba de frente o de lado', 'Para mejor detección de postura'),
          _itemInstruccion('2', 'Asegúrate de tener buena luz', 'Evita contraluces o sombras fuertes'),
          _itemInstruccion('3', 'Muestra el cuerpo completo', 'Desde la cabeza hasta los pies'),
          const SizedBox(height: 8),

          _cargando
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              BotonPrincipal(
                texto: 'Analizar video',
                onPressed: _analizarVideo,
              ),

              const SizedBox(height: 12),

              BotonPrincipal(
                texto: 'Grabarse en tiempo real',
                secundario: true,
                onPressed: () => Navigator.pushNamed(context, Rutas.tiempoReal),
              ),
            ],
          ),

        ],
      ),
    );
  }
}