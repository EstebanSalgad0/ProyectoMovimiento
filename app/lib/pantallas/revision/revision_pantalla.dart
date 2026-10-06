import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/presentacion.dart';
import '../../core/widgets/estadistica.dart';
import '../../estado/proveedores.dart';
import '../../modelos/esqueleto.dart';
import '../../modelos/resultado_analisis.dart';
import '../../modelos/sesion.dart';
import '../../motor/puntos.dart';

/// Revisión de una sesión: reproduce el esqueleto grabado (o el video con el
/// esqueleto encima), con marcas de cada repetición en la línea de tiempo.
class RevisionPantalla extends ConsumerStatefulWidget {
  final String sesionId;

  const RevisionPantalla({super.key, required this.sesionId});

  @override
  ConsumerState<RevisionPantalla> createState() => _RevisionPantallaState();
}

class _RevisionPantallaState extends ConsumerState<RevisionPantalla> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_alTick);
  Duration _ultimoTick = Duration.zero;
  Sesion? _sesion;
  EsqueletoGrabado? _esqueleto;
  VideoPlayerController? _video;
  bool _cargando = true;
  bool _reproduciendo = false;
  double _velocidad = 1;
  double _t = 0; // ms desde el inicio del esqueleto (modo sin video)

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sesiones = ref.read(historialProvider).value ?? const <Sesion>[];
    final sesion = sesiones.where((s) => s.id == widget.sesionId).firstOrNull;
    EsqueletoGrabado? esq;
    VideoPlayerController? video;
    if (sesion != null) {
      try {
        esq = await ref.read(adjuntosServicioProvider).leerEsqueleto(sesion.id);
      } catch (_) {}
      final ruta = sesion.videoRuta;
      if (ruta != null && File(ruta).existsSync()) {
        final c = VideoPlayerController.file(File(ruta));
        try {
          await c.initialize();
          c.addListener(_alCambiarVideo);
          video = c;
        } catch (_) {
          await c.dispose();
        }
      }
    }
    if (!mounted) {
      await video?.dispose();
      return;
    }
    setState(() {
      _sesion = sesion;
      _esqueleto = esq;
      _video = video;
      _cargando = false;
    });
  }

  void _alCambiarVideo() {
    if (!mounted) return;
    final v = _video!;
    setState(() => _reproduciendo = v.value.isPlaying);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _video?.removeListener(_alCambiarVideo);
    _video?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- tiempo
  int get _inicioAbs => _video != null ? 0 : (_esqueleto?.tMs.firstOrNull ?? 0);
  int get _totalMs => _video?.value.duration.inMilliseconds ?? (_esqueleto?.duracionMs ?? 0);
  int get _ahoraAbs => _video?.value.position.inMilliseconds ?? (_inicioAbs + _t.round());

  void _alTick(Duration transcurrido) {
    final dt = (transcurrido - _ultimoTick).inMicroseconds / 1000;
    _ultimoTick = transcurrido;
    setState(() {
      _t += dt * _velocidad;
      if (_t >= _totalMs) {
        _t = _totalMs.toDouble();
        _pausar();
      }
    });
  }

  void _pausar() {
    if (_video != null) {
      _video!.pause();
    } else {
      _ticker.stop();
      _reproduciendo = false;
    }
  }

  void _alternar() {
    final v = _video;
    if (v != null) {
      v.value.isPlaying ? v.pause() : v.play();
      return;
    }
    if (_reproduciendo) {
      _pausar();
    } else {
      if (_t >= _totalMs) _t = 0;
      _ultimoTick = Duration.zero;
      _ticker.start();
      _reproduciendo = true;
    }
    setState(() {});
  }

  void _irA(int relativoMs) {
    final ms = relativoMs.clamp(0, _totalMs);
    final v = _video;
    if (v != null) {
      v.seekTo(Duration(milliseconds: ms));
    } else {
      setState(() => _t = ms.toDouble());
    }
  }

  void _cambiarVelocidad(double v) {
    setState(() => _velocidad = v);
    _video?.setPlaybackSpeed(v);
  }

  // ------------------------------------------------------------ interfaz
  @override
  Widget build(BuildContext context) {
    final oscuro = PaletaApp.oscuro;
    final temaOscuro = AppTema.oscuro;
    return Theme(
      data: temaOscuro.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
        appBarTheme: temaOscuro.appBarTheme.copyWith(backgroundColor: const Color(0xFF070B14)),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Revisar movimiento')),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: AppColores.blanco))
            : _sesion == null || (_esqueleto == null && _video == null)
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: EstadoVacio(
                    icono: Icons.videocam_off_outlined,
                    titulo: 'No hay grabación para esta sesión',
                    mensaje:
                        'Las sesiones nuevas guardan el esqueleto del movimiento (y el video, si lo analizaste) '
                        'para revisarlas aquí.',
                  ),
                ),
              )
            : _contenido(context, oscuro),
      ),
    );
  }

  Widget _contenido(BuildContext context, PaletaApp p) {
    final r = _sesion!.resultado;
    final esq = _esqueleto;
    final ahora = _ahoraAbs;
    Repeticion? repActual;
    for (final rep in r.repeticiones) {
      if (ahora >= rep.inicioMs && ahora <= rep.finMs) repActual = rep;
    }
    Map<int, (Offset, double)> puntos = const {};
    if (esq != null && esq.tMs.isNotEmpty) {
      final i = esq.indiceEn(ahora - esq.tMs.first);
      if ((esq.tMs[i] - ahora).abs() < 300) puntos = esq.puntosDe(i);
    }
    final alerta = repActual != null && repActual.fallos.isNotEmpty;
    final pintor = _PintorGrabado(puntos: puntos, color: alerta ? p.advertencia : p.acento, visibilidadMinima: 0.5);

    final video = _video;
    final aspecto = video?.value.aspectRatio ?? esq?.aspecto ?? 9 / 16;
    final visor = AspectRatio(
      aspectRatio: aspecto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              VideoPlayer(video)
            else
              CustomPaint(painter: _PintorCuadricula(color: AppColores.blanco.withValues(alpha: 0.06))),
            CustomPaint(painter: pintor),
            Positioned(
              left: 12,
              top: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: repActual == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(repActual.numero),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'Repetición ${repActual.numero} · ${repActual.puntaje} pts',
                          style: context.textos.labelMedium?.copyWith(color: AppColores.blanco),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    final hallazgos = {for (final h in r.hallazgos) h.codigo: h};
    final total = _totalMs;
    final relativo = (ahora - _inicioAbs).clamp(0, total);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(child: visor),
            ),
          ),
          if (repActual != null && repActual.fallos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                repActual.fallos.map((c) => hallazgos[c]?.titulo ?? c).join(' · '),
                style: context.textos.bodySmall?.copyWith(color: p.advertencia),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LineaTiempo(
              total: total,
              valor: relativo,
              inicioAbs: _inicioAbs,
              repeticiones: r.repeticiones,
              paleta: p,
              onCambiar: _irA,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  Formato.cronometro(Duration(milliseconds: relativo)),
                  style: AppTipo.numero(12, AppColores.blanco.withValues(alpha: 0.7), peso: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  Formato.cronometro(Duration(milliseconds: total)),
                  style: AppTipo.numero(12, AppColores.blanco.withValues(alpha: 0.7), peso: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final v in const [0.5, 1.0, 2.0])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${v == 0.5 ? '0,5' : v.toStringAsFixed(0)}×'),
                    selected: _velocidad == v,
                    showCheckmark: false,
                    onSelected: (_) => _cambiarVelocidad(v),
                  ),
                ),
              const SizedBox(width: 12),
              IconButton.filled(
                iconSize: 34,
                style: IconButton.styleFrom(backgroundColor: AppColores.blanco, foregroundColor: AppColores.marino),
                tooltip: _reproduciendo ? 'Pausar' : 'Reproducir',
                onPressed: _alternar,
                icon: Icon(_reproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
            ],
          ),
          if (r.repeticiones.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: r.repeticiones.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final rep = r.repeticiones[i];
                  final (color, _) = Presentacion.coloresEstado(p, estadoDePuntaje(rep.puntaje));
                  final activa = identical(rep, repActual);
                  return ActionChip(
                    backgroundColor: activa ? color.withValues(alpha: 0.25) : null,
                    side: BorderSide(color: color.withValues(alpha: 0.7)),
                    label: Text('${rep.numero} · ${rep.puntaje}'),
                    onPressed: () => _irA(rep.inicioMs - _inicioAbs - 300),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LineaTiempo extends StatelessWidget {
  final int total;
  final int valor;
  final int inicioAbs;
  final List<Repeticion> repeticiones;
  final PaletaApp paleta;
  final ValueChanged<int> onCambiar;

  const _LineaTiempo({
    required this.total,
    required this.valor,
    required this.inicioAbs,
    required this.repeticiones,
    required this.paleta,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            left: 24,
            right: 24,
            child: CustomPaint(
              painter: _PintorMarcas(total: total, inicioAbs: inicioAbs, repeticiones: repeticiones, paleta: paleta),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColores.blanco,
              inactiveTrackColor: AppColores.blanco.withValues(alpha: 0.2),
              thumbColor: AppColores.blanco,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: total == 0 ? 0 : valor.toDouble().clamp(0, total.toDouble()),
              max: total == 0 ? 1 : total.toDouble(),
              semanticFormatterCallback: (v) => Formato.cronometro(Duration(milliseconds: v.round())),
              onChanged: total == 0 ? null : (v) => onCambiar(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorMarcas extends CustomPainter {
  final int total;
  final int inicioAbs;
  final List<Repeticion> repeticiones;
  final PaletaApp paleta;

  _PintorMarcas({required this.total, required this.inicioAbs, required this.repeticiones, required this.paleta});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    for (final r in repeticiones) {
      final x0 = ((r.inicioMs - inicioAbs) / total).clamp(0.0, 1.0) * size.width;
      final x1 = ((r.finMs - inicioAbs) / total).clamp(0.0, 1.0) * size.width;
      final (color, _) = Presentacion.coloresEstado(paleta, estadoDePuntaje(r.puntaje));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, size.height / 2 - 9, x1 < x0 + 3 ? x0 + 3 : x1, size.height / 2 + 9),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMarcas old) => old.total != total || old.repeticiones != repeticiones;
}

/// Esqueleto en coordenadas normalizadas (0–1) sobre el tamaño del visor.
class _PintorGrabado extends CustomPainter {
  final Map<int, (Offset, double)> puntos;
  final Color color;
  final double visibilidadMinima;

  _PintorGrabado({required this.puntos, required this.color, required this.visibilidadMinima});

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.isEmpty) return;
    Offset? pos(int i) {
      final p = puntos[i];
      if (p == null || p.$2 < visibilidadMinima) return null;
      return Offset(p.$1.dx * size.width, p.$1.dy * size.height);
    }

    final linea = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sombra = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.3);
    for (final c in conexionesEsqueleto) {
      final a = pos(c[0]), b = pos(c[1]);
      if (a == null || b == null) continue;
      canvas
        ..drawLine(a, b, sombra)
        ..drawLine(a, b, linea);
    }
    final relleno = Paint()..color = Colors.white;
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color;
    for (final i in puntos.keys) {
      final p = pos(i);
      if (p == null) continue;
      canvas
        ..drawCircle(p, i == nariz ? 6 : 5, relleno)
        ..drawCircle(p, i == nariz ? 6 : 5, borde);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorGrabado old) => !identical(old.puntos, puntos) || old.color != color;
}

class _PintorCuadricula extends CustomPainter {
  final Color color;
  _PintorCuadricula({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF111827));
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const paso = 32.0;
    for (var x = 0.0; x < size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCuadricula old) => old.color != color;
}
