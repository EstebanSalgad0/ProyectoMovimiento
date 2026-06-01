import 'package:flutter/material.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/tipografia.dart';
import '../../../core/widgets/encabezado.dart';
import '../../../core/widgets/boton_principal.dart';
import '../../../rutas.dart';

class TiempoRealPantalla extends StatelessWidget {
  const TiempoRealPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(
        titulo: 'Tiempo real',
        centrado: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card cámara
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60),
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
                    child: const Icon(Icons.videocam_rounded,
                        color: AppColores.azulPrincipal, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text('Grabate en tiempo real',
                      style: AppTipo.cardTitle()
                          .copyWith(color: AppColores.textoPrincipal)),
                  const SizedBox(height: 6),
                  Text('Posiciona la cámara frente a ti',
                      style: AppTipo.caption()
                          .copyWith(color: AppColores.textoSecundario)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Antes de comenzar', style: AppTipo.labelMedium()
                .copyWith(color: AppColores.textoSecundario)),
            const SizedBox(height: 12),

            _itemInstruccion(context, '1', 'Posiciona el dispositivo frente a ti',
                'Preocura que se vea tu cuerpo completo'),
            _itemInstruccion(context, '2', 'Asegurate de tener buena iluminacion',
                'Evita contraluces o sombras fuertes'),
            _itemInstruccion(context, '3', 'Temporizador de inicio',
                '5 segundos antes de comenzar la grabación'),
            _itemInstruccion(context, '4', 'Duración del ejercicio',
                '10 segundos de grabación por sesión'),

            const Spacer(),

            BotonPrincipal(
              texto: 'Volver al inicio',
              onPressed: () => Navigator.pushReplacementNamed(context, Rutas.inicio),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemInstruccion(BuildContext context, String numero, String titulo, String subtitulo) {
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
}