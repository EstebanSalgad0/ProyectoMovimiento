import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/boton_principal.dart';
import '../../core/widgets/ilustracion_ejercicio.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/evaluacion.dart';
import '../../modelos/sesion.dart';
import '../../modelos/usuario.dart';
import '../../rutas.dart';
import '../tiempo_real/camara_pose.dart';
import '../tiempo_real/ciclo_camara.dart';
import '../tiempo_real/componentes_camara.dart';
import '../tiempo_real/controlador_tiempo_real.dart';

const _ejercicioPrueba = 'sentarse_pararse';
const _duracionPrueba = Duration(seconds: 30);

enum _Fase { intro, prueba, guardando, resultado }

/// Prueba de sentarse y pararse en 30 segundos (CDC STEADI): la cámara cuenta
/// las veces que la persona se pone de pie y compara con valores de referencia
/// para su edad y sexo.
class PruebaStsPantalla extends ConsumerStatefulWidget {
  const PruebaStsPantalla({super.key});

  @override
  ConsumerState<PruebaStsPantalla> createState() => _PruebaStsPantallaState();
}

class _PruebaStsPantallaState extends ConsumerState<PruebaStsPantalla>
    with WidgetsBindingObserver, CicloCamara<PruebaStsPantalla> {
  _Fase _fase = _Fase.intro;
  CamaraPose? _camara;
  ControladorTiempoReal? _ctrl;
  EvaluacionFuncional? _evaluacion;

  late int? _edad = ref.read(authProvider)?.edad;
  late Sexo? _sexo = ref.read(authProvider)?.sexo;

  @override
  CamaraPose? get camaraDelCiclo => _camara;

  @override
  bool get reanudarCamara => _fase == _Fase.prueba;

  @override
  void dispose() {
    _cerrarCamara();
    super.dispose();
  }

  void _cerrarCamara() {
    _ctrl?.removeListener(_alCambiar);
    _ctrl?.dispose();
    _camara?.dispose();
    _ctrl = null;
    _camara = null;
  }

  void _comenzar() {
    final spec = ref.read(especificacionPersonalizadaProvider);
    final ejercicio = spec.buscar(_ejercicioPrueba);
    if (ejercicio == null) return;
    final ajustes = ref.read(ajustesProvider);
    final voz = ref.read(vozProvider)..cambiarVelocidad(ajustes.velocidadVoz);
    final camara = CamaraPose(preferirFrontal: ajustes.camaraFrontal);
    final ctrl = ControladorTiempoReal(
      camara: camara,
      spec: spec,
      ejercicio: ejercicio,
      voz: voz,
      vozActiva: ajustes.voz,
      vibracion: ajustes.vibracion,
      segundosCuentaRegresiva: ajustes.cuentaRegresiva < 3 ? 3 : ajustes.cuentaRegresiva,
      limite: _duracionPrueba,
    )..addListener(_alCambiar);
    setState(() {
      _camara = camara;
      _ctrl = ctrl;
      _fase = _Fase.prueba;
    });
    camara.iniciar();
  }

  void _alCambiar() {
    if (_ctrl?.etapa == EtapaSesion.serieCompleta && _fase == _Fase.prueba) _terminar();
  }

  Future<void> _terminar() async {
    final c = _ctrl!;
    setState(() => _fase = _Fase.guardando);
    final r = await c.finalizar();
    final usuario = ref.read(authProvider);
    if (r == null || usuario == null || !mounted) return;
    Sesion? sesion;
    if (r.resultado.numeroRepeticiones > 0) {
      sesion = await ref
          .read(historialProvider.notifier)
          .registrar(r.resultado, OrigenSesion.tiempoReal, esqueleto: r.esqueleto);
    }
    final e = EvaluacionFuncional.sts30(
      usuario: usuario.usuario,
      repeticiones: r.conteoFinal,
      edad: _edad,
      sexo: _sexo,
      sesionId: sesion?.id,
    );
    await ref.read(evaluacionesProvider.notifier).agregar(e);
    if (!mounted) return;
    _cerrarCamara();
    HapticFeedback.heavyImpact();
    setState(() {
      _evaluacion = e;
      _fase = _Fase.resultado;
    });
  }

  Future<void> _cancelar() async {
    final c = _ctrl;
    if (c != null && c.etapa == EtapaSesion.activa) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Detener la prueba?'),
          content: const Text('La prueba se debe completar durante los 30 segundos. Este intento no se guardará.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Detener')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _cerrarCamara();
    setState(() => _fase = _Fase.intro);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_fase) {
      _Fase.intro => _Intro(
        edad: _edad,
        sexo: _sexo,
        onEdad: (v) => setState(() => _edad = v),
        onSexo: (v) => setState(() => _sexo = v),
        onComenzar: _comenzar,
      ),
      _Fase.resultado => _Resultado(evaluacion: _evaluacion!, onRepetir: () => setState(() => _fase = _Fase.intro)),
      _ => _vistaPrueba(),
    };
  }

  Widget _vistaPrueba() {
    final c = _ctrl;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _fase == _Fase.prueba) _cancelar();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: c == null || _fase == _Fase.guardando
              ? const SafeArea(child: MensajeCamara(cargando: true, titulo: 'Calculando tu resultado…'))
              : ListenableBuilder(
                  listenable: c,
                  builder: (context, _) {
                    final camara = c.camara;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        VistaCamaraPose(
                          camara: camara,
                          destacados: puntosDeGrupos(c.ejercicio),
                          mostrarEsqueleto: ref.watch(ajustesProvider).mostrarEsqueleto,
                          visibilidadMinima: c.spec.globales.visibilidadMinima,
                        ),
                        const DegradadosCamara(),
                        SafeArea(
                          child: Column(
                            children: [
                              BarraCamara(
                                titulo: 'Prueba de 30 segundos',
                                subtitulo: 'Sentarse y pararse',
                                onCerrar: _cancelar,
                                acciones: [
                                  BotonCircular(
                                    icono: c.vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                    tooltip: c.vozActiva ? 'Silenciar voz' : 'Activar voz',
                                    onPressed: c.alternarVoz,
                                  ),
                                ],
                              ),
                              Expanded(
                                child: EstadoCamaraVista(
                                  camara: camara,
                                  hijo: switch (c.etapa) {
                                    EtapaSesion.cuentaRegresiva => CuentaRegresivaGrande(cuenta: c.cuenta),
                                    EtapaSesion.activa => HudEntrenamiento(
                                      ctrl: c,
                                      onBoton: _cancelar,
                                      textoBoton: 'Detener prueba',
                                    ),
                                    EtapaSesion.encuadre => PanelEncuadre(
                                      ejercicio: c.ejercicio,
                                      faltantes: c.faltantes,
                                      hayPersona: camara.puntos != null,
                                      onComenzar: c.comenzarAhora,
                                      encabezado: 'SIÉNTATE CON LOS BRAZOS CRUZADOS SOBRE EL PECHO',
                                    ),
                                    _ => const MensajeCamara(cargando: true, titulo: '¡Tiempo!'),
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ intro
class _Intro extends StatelessWidget {
  final int? edad;
  final Sexo? sexo;
  final ValueChanged<int?> onEdad;
  final ValueChanged<Sexo?> onSexo;
  final VoidCallback onComenzar;

  const _Intro({
    required this.edad,
    required this.sexo,
    required this.onEdad,
    required this.onSexo,
    required this.onComenzar,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    const pasos = [
      'Usa una silla firme sin apoyabrazos, apoyada contra la pared.',
      'Siéntate al centro, con los pies apoyados en el suelo y los brazos cruzados sobre el pecho.',
      'Deja el teléfono de costado, a unos 2,5 m, para que se vea todo tu cuerpo y la silla.',
      'Cuando escuches «Comienza», ponte de pie por completo y vuelve a sentarte tantas veces como puedas.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de 30 segundos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Medidas.radioL),
            child: const SizedBox(
              height: 180,
              child: IlustracionEjercicio(ejercicioId: _ejercicioPrueba, animada: true),
            ),
          ),
          const SizedBox(height: 18),
          Text('Sentarse y pararse', style: context.textos.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Mide la fuerza y resistencia de tus piernas. Es una prueba recomendada por el programa STEADI '
            'del CDC para estimar el riesgo de caídas en personas mayores.',
            style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
          ),
          const SizedBox(height: 20),
          const EncabezadoSeccion(titulo: 'Cómo se hace'),
          Tarjeta(
            child: Column(
              children: [
                for (var i = 0; i < pasos.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == pasos.length - 1 ? 0 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.primarioSuave, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: context.textos.labelMedium?.copyWith(color: p.primario)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(pasos[i], style: context.textos.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.advertenciaSuave, borderRadius: BorderRadius.circular(18)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_outlined, color: p.advertencia),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Detente si sientes mareo, dolor o falta de aire. Si tienes riesgo de caerte, hazla con '
                    'alguien a tu lado.',
                    style: context.textos.bodySmall?.copyWith(color: p.texto),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const EncabezadoSeccion(titulo: 'Para comparar tu resultado'),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Edad', style: context.textos.titleSmall)),
                    IconButton.outlined(
                      tooltip: 'Restar un año',
                      onPressed: edad == null || edad! <= 18 ? null : () => onEdad(edad! - 1),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        edad == null ? '—' : '$edad',
                        textAlign: TextAlign.center,
                        style: AppTipo.numero(24, p.texto),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Sumar un año',
                      onPressed: edad != null && edad! >= 110 ? null : () => onEdad((edad ?? 64) + 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Sexo', style: context.textos.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Sexo.values)
                      ChoiceChip(label: Text(s.etiqueta), selected: sexo == s, onSelected: (_) => onSexo(s)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Hay valores de referencia para personas de 60 a 94 años. Para otras edades se registra '
                  'tu resultado para seguir tu progreso.',
                  style: context.textos.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BotonPrincipal(texto: 'Comenzar prueba', icono: Icons.timer_outlined, onPressed: onComenzar),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- resultado
class _Resultado extends ConsumerWidget {
  final EvaluacionFuncional evaluacion;
  final VoidCallback onRepetir;

  const _Resultado({required this.evaluacion, required this.onRepetir});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final e = evaluacion;
    final clasificacion = e.clasificacion ?? ClasificacionSts30.sinReferencia;
    final (color, fondo) = switch (clasificacion) {
      ClasificacionSts30.enRango => (p.exito, p.exitoSuave),
      ClasificacionSts30.bajoPromedio => (p.advertencia, p.advertenciaSuave),
      ClasificacionSts30.sinReferencia => (p.info, p.infoSuave),
    };
    final anteriores = [
      for (final x in ref.watch(evaluacionesProvider).value ?? const <EvaluacionFuncional>[])
        if (x.tipo == TipoEvaluacion.sentarsePararse30s && x.id != e.id) x,
    ].take(4).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cerrar', onPressed: () => context.pop()),
        title: const Text('Tu resultado'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          Tarjeta(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (e.repeticiones ?? 0).toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text('${v.round()}', style: AppTipo.numero(84, p.texto)),
                ),
                Text('veces de pie en 30 segundos', style: context.textos.bodyMedium),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(40)),
                  child: Text(clasificacion.etiqueta, style: context.textos.labelLarge?.copyWith(color: color)),
                ),
                const SizedBox(height: 12),
                Text(
                  clasificacion.detalle,
                  textAlign: TextAlign.center,
                  style: context.textos.bodyMedium?.copyWith(color: p.textoSecundario),
                ),
                if (e.umbralReferencia != null) ...[
                  const SizedBox(height: 16),
                  _BarraReferencia(valor: e.repeticiones ?? 0, umbral: e.umbralReferencia!, color: color),
                  const SizedBox(height: 8),
                  Text(
                    'Referencia para ${e.sexo == Sexo.masculino ? 'hombres' : 'mujeres'} de ${e.edad} años: '
                    '${e.umbralReferencia} o más',
                    style: context.textos.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (e.sesionId != null)
            Tarjeta(
              onTap: () => context.push(Rutas.sesion(e.sesionId!)),
              child: Row(
                children: [
                  IconoCaja(icono: Icons.insights_rounded, color: p.primario, fondo: p.primarioSuave),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ver tu técnica', style: context.textos.titleSmall),
                        const SizedBox(height: 2),
                        Text('Detalle de cada repetición y correcciones', style: context.textos.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.textoTerciario),
                ],
              ),
            ),
          if (anteriores.isNotEmpty) ...[
            const SizedBox(height: 24),
            const EncabezadoSeccion(titulo: 'Pruebas anteriores'),
            Tarjeta(
              child: Column(
                children: [
                  for (final a in anteriores)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(Formato.fechaRelativa(a.fecha), style: context.textos.bodyMedium)),
                          Text('${a.repeticiones ?? 0}', style: AppTipo.numero(20, p.texto)),
                          const SizedBox(width: 8),
                          _Diferencia(diferencia: (e.repeticiones ?? 0) - (a.repeticiones ?? 0)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: p.textoTerciario),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Referencia: ${ReferenciaSts30.fuente}. Es una herramienta de tamizaje, no un diagnóstico.',
                  style: context.textos.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          BotonPrincipal(texto: 'Listo', icono: Icons.check_rounded, onPressed: () => context.pop()),
          const SizedBox(height: 10),
          BotonPrincipal(
            texto: 'Repetir prueba',
            icono: Icons.replay_rounded,
            variante: VarianteBoton.secundario,
            onPressed: onRepetir,
          ),
        ],
      ),
    );
  }
}

class _BarraReferencia extends StatelessWidget {
  final int valor;
  final int umbral;
  final Color color;
  const _BarraReferencia({required this.valor, required this.umbral, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final maximo = (umbral * 1.6).ceilToDouble();
    return LayoutBuilder(
      builder: (context, c) {
        final x = (umbral / maximo) * c.maxWidth;
        return SizedBox(
          height: 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (valor / maximo).clamp(0.0, 1.0),
                    minHeight: 10,
                    color: color,
                    backgroundColor: p.superficieAlta,
                  ),
                ),
              ),
              Positioned(
                left: x - 1,
                top: 2,
                child: Container(width: 2, height: 22, color: p.texto),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Diferencia extends StatelessWidget {
  final int diferencia;
  const _Diferencia({required this.diferencia});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final color = diferencia > 0
        ? p.exito
        : diferencia < 0
        ? p.peligro
        : p.textoTerciario;
    return SizedBox(
      width: 48,
      child: Text(
        diferencia == 0 ? '=' : '${diferencia > 0 ? '+' : ''}$diferencia',
        textAlign: TextAlign.end,
        style: context.textos.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
