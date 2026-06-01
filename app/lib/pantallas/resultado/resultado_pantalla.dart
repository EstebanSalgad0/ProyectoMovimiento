import 'package:flutter/material.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/encabezado.dart';
import '../../core/widgets/boton_principal.dart';
import '../../modelos/resultado_analisis.dart';
import '../../rutas.dart';

class ResultadoPantalla extends StatelessWidget {
  const ResultadoPantalla({super.key});

  Color _colorPuntaje(int puntaje) {
    if (puntaje >= 80) return AppColores.correctoTexto;
    if (puntaje >= 50) return AppColores.advertenciaTexto;
    return AppColores.peligroTexto;
  }

  Color _bgPuntaje(int puntaje) {
    if (puntaje >= 80) return AppColores.correctoBg;
    if (puntaje >= 50) return AppColores.advertenciaBg;
    return AppColores.peligroBg;
  }

  String _labelPuntaje(int puntaje) {
    if (puntaje >= 80) return 'Ejercicio correcto';
    if (puntaje >= 50) return 'Ejercicio con advertencias';
    return 'Ejercicio con errores';
  }

  IconData _iconoPuntaje(int puntaje) {
    if (puntaje >= 80) return Icons.check;
    if (puntaje >= 50) return Icons.warning_amber_rounded;
    return Icons.close;
  }

  Widget _itemDetalle(String feedback, int puntaje) {
    final esNegativo = [
      'mejore', 'alinee', 'flexione', 'extienda', 'nivele',
      'acerque', 'aumente', 'distribuya', 'baje', 'cierre'
    ].any((w) => feedback.toLowerCase().contains(w));

    final color = esNegativo ? AppColores.advertenciaTexto : AppColores.correctoTexto;
    final bg    = esNegativo ? AppColores.advertenciaBg    : AppColores.correctoBg;
    final icono = esNegativo ? Icons.warning_amber_rounded : Icons.check;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColores.fondoCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.bordeDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icono, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(feedback, style: AppTipo.body()
                .copyWith(color: AppColores.textoPrincipal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultado = ModalRoute.of(context)?.settings.arguments as ResultadoAnalisis?;

    // Datos hardcodeados si no hay resultado real aún
    final puntaje  = resultado?.puntaje   ?? 100;
    final ejercicio= resultado?.ejercicio ?? 'sentadilla';
    final feedback = resultado?.feedback  ?? ['Ejercicio analizado correctamente.'];

    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(
        titulo: 'Resultado',
        centrado: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Card resultado general
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgPuntaje(puntaje),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _colorPuntaje(puntaje),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconoPuntaje(puntaje), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_labelPuntaje(puntaje), style: AppTipo.cardTitle()
                          .copyWith(color: _colorPuntaje(puntaje))),
                      Text(ejercicio.replaceAll('_', ' '), style: AppTipo.caption()
                          .copyWith(color: _colorPuntaje(puntaje))),
                    ],
                  ),
                ),
                Text('$puntaje/100', style: AppTipo.statNumber()
                    .copyWith(color: _colorPuntaje(puntaje))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Detalle del análisis', style: AppTipo.labelMedium()
              .copyWith(color: AppColores.textoSecundario)),
          const SizedBox(height: 10),

          ...feedback.map((f) => _itemDetalle(f, puntaje)),
          const SizedBox(height: 24),

          // Mensaje final
          Center(
            child: Column(
              children: [
                Text(
                  puntaje >= 80 ? '¡Felicitaciones!' : 'Sigue mejorando',
                  style: AppTipo.cardTitle().copyWith(color: AppColores.textoPrincipal),
                ),
                const SizedBox(height: 4),
                Text(
                  puntaje >= 80
                      ? 'Nada que corregir. ¡Bien hecho!'
                      : 'Revisa el feedback para mejorar.',
                  style: AppTipo.caption().copyWith(color: AppColores.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          BotonPrincipal(
            texto: 'Volver al inicio',
            onPressed: () => Navigator.pushReplacementNamed(context, Rutas.inicio),
          ),
          const SizedBox(height: 10),
          BotonPrincipal(
            texto: 'Analizar otro video',
            secundario: true,
            onPressed: () => Navigator.pushReplacementNamed(context, Rutas.preparacion),
          ),
        ],
      ),
    );
  }
}