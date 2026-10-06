import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/anillo_puntaje.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/logo.dart';
import '../../estado/proveedores.dart';

class _Pagina {
  final String titulo;
  final String texto;
  final Widget Function(BuildContext) ilustracion;
  const _Pagina(this.titulo, this.texto, this.ilustracion);
}

class BienvenidaPantalla extends ConsumerStatefulWidget {
  const BienvenidaPantalla({super.key});

  @override
  ConsumerState<BienvenidaPantalla> createState() => _BienvenidaPantallaState();
}

class _BienvenidaPantallaState extends ConsumerState<BienvenidaPantalla> {
  final _paginas = PageController();
  int _actual = 0;

  late final _contenido = <_Pagina>[
    _Pagina(
      'Tu movimiento,\nanalizado con IA',
      'La cámara de tu teléfono detecta 33 puntos de tu cuerpo y evalúa la técnica de cada repetición.',
      (_) => const IlustracionEjercicio(
        ejercicioId: 'sentadilla',
        animada: true,
        conFondo: false,
        color: AppColores.blanco,
      ),
    ),
    _Pagina(
      'Correcciones\nen tiempo real',
      'Cuenta tus repeticiones y te indica, incluso por voz, qué ajustar mientras entrenas.',
      (context) => Stack(
        alignment: Alignment.center,
        children: [
          const IlustracionEjercicio(
            ejercicioId: 'elevacion_lateral',
            animada: true,
            conFondo: false,
            color: AppColores.blanco,
          ),
          Positioned(
            top: 12,
            right: 8,
            child: _Burbuja(icono: Icons.repeat_rounded, texto: 'Rep. 4'),
          ),
          Positioned(
            bottom: 18,
            left: 4,
            child: _Burbuja(icono: Icons.check_circle_rounded, texto: '¡Buena altura!'),
          ),
        ],
      ),
    ),
    _Pagina(
      'Sigue tu progreso\ny mejora cada día',
      'Revisa el puntaje de cada sesión, las correcciones frecuentes y tu evolución en el tiempo.',
      (context) => Center(
        child: AnilloPuntaje(
          puntaje: 86,
          tamano: 170,
          grosor: 16,
          colorPista: AppColores.blanco.withValues(alpha: 0.18),
          colorTexto: AppColores.blanco,
          subtitulo: 'puntaje de técnica',
        ),
      ),
    ),
  ];

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _terminar() => ref.read(ajustesProvider.notifier).marcarBienvenidaVista();

  void _siguiente() {
    if (_actual == _contenido.length - 1) {
      _terminar();
    } else {
      _paginas.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final esUltima = _actual == _contenido.length - 1;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 11,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: p.gradiente,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                      child: Row(
                        children: [
                          const LogoMovimiento(tamano: 30),
                          const SizedBox(width: 8),
                          Text(
                            AppConfig.nombreApp,
                            style: context.textos.titleMedium?.copyWith(color: AppColores.blanco),
                          ),
                          const Spacer(),
                          AnimatedOpacity(
                            opacity: esUltima ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: TextButton(
                              onPressed: esUltima ? null : _terminar,
                              style: TextButton.styleFrom(foregroundColor: AppColores.blanco),
                              child: const Text('Saltar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _paginas,
                        itemCount: _contenido.length,
                        onPageChanged: (i) => setState(() => _actual = i),
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(48, 12, 48, 28),
                          child: _contenido[i].ilustracion(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Medidas.margen, 28, Medidas.margen, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Desplazable para pantallas pequeñas o letra grande (accesibilidad).
                    Expanded(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey(_actual),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_contenido[_actual].titulo, style: context.textos.headlineMedium),
                              const SizedBox(height: 12),
                              Text(
                                _contenido[_actual].texto,
                                style: context.textos.bodyLarge?.copyWith(color: p.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (esUltima)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(AppConfig.avisoMedico, style: context.textos.bodySmall),
                      ),
                    Row(
                      children: [
                        for (var i = 0; i < _contenido.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _actual ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _actual ? p.primario : p.borde,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        const Spacer(),
                        BotonPrincipal(
                          texto: esUltima ? 'Comenzar' : 'Siguiente',
                          icono: esUltima ? Icons.arrow_forward_rounded : null,
                          expandido: false,
                          onPressed: _siguiente,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Burbuja({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColores.blanco,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: AppColores.azul),
          const SizedBox(width: 6),
          Text(texto, style: context.textos.labelMedium?.copyWith(color: AppColores.marino)),
        ],
      ),
    );
  }
}
