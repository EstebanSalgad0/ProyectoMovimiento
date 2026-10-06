import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../modelos/esqueleto.dart';
import '../../modelos/resultado_analisis.dart';
import '../../motor/analizador.dart';
import '../../motor/especificacion.dart';
import '../../motor/metricas.dart';
import '../../motor/puntos.dart';
import '../../motor/repeticiones.dart';
import '../../servicios/voz_servicio.dart';
import 'camara_pose.dart';

enum EtapaSesion { encuadre, cuentaRegresiva, activa, serieCompleta, finalizando }

class AvisoEnVivo {
  final String titulo;
  final String? detalle;

  /// null = mensaje positivo.
  final Severidad? severidad;
  final DateTime hora;

  AvisoEnVivo(this.titulo, {this.detalle, this.severidad}) : hora = DateTime.now();
}

/// Resultado de una serie: análisis, esqueleto grabado y conteo final.
class ResultadoSerie {
  final ResultadoAnalisis resultado;
  final EsqueletoGrabado? esqueleto;

  /// Repeticiones según la regla de las pruebas funcionales: cuenta también la
  /// última si al terminar el tiempo ya se había pasado la mitad del movimiento.
  final int conteoFinal;
  final Duration duracion;

  const ResultadoSerie({
    required this.resultado,
    required this.esqueleto,
    required this.conteoFinal,
    required this.duracion,
  });
}

/// Lógica de una serie en tiempo real sobre una [CamaraPose]: encuadre, cuenta
/// regresiva, análisis con el motor local, avisos y fin de la serie (por
/// objetivo de repeticiones, por tiempo o a mano).
class ControladorTiempoReal extends ChangeNotifier {
  final CamaraPose camara;
  final Especificacion spec;
  final VozServicio voz;
  bool vozActiva;
  final bool vibracion;
  final int segundosCuentaRegresiva;

  EjercicioSpec ejercicio;
  int objetivo;

  /// Termina la serie sola al llegar al objetivo (rutinas guiadas).
  bool autoFinalizar;

  /// Duración fija (prueba de 30 s). null = sin límite.
  Duration? limite;

  ControladorTiempoReal({
    required this.camara,
    required this.spec,
    required this.ejercicio,
    required this.voz,
    required this.vozActiva,
    this.vibracion = true,
    this.segundosCuentaRegresiva = 3,
    int? objetivo,
    this.autoFinalizar = false,
    this.limite,
  }) : objetivo = objetivo ?? ejercicio.objetivoRepeticiones {
    camara.alFotograma = _alFotograma;
    camara.addListener(_reenviar);
  }

  EtapaSesion etapa = EtapaSesion.encuadre;
  List<String> faltantes = const [];
  EstadoFotograma? estado;
  int cuenta = 3;
  AvisoEnVivo? aviso;
  RepeticionEvaluada? ultimaRep;
  DateTime _horaUltimaRep = DateTime.fromMillisecondsSinceEpoch(0);
  final Stopwatch reloj = Stopwatch();

  Analizador? _analizador;
  final GrabadorEsqueleto _grabador = GrabadorEsqueleto();
  int _cuadrosEncuadrados = 0;
  Timer? _temporizador;
  DateTime _ultimoAvisoFaltantes = DateTime.fromMillisecondsSinceEpoch(0);
  bool _cerrado = false;

  int get repeticiones => _analizador?.repeticiones.length ?? 0;
  bool get hayRepeticiones => repeticiones > 0;

  /// Avance del movimiento actual (0 = reposo, 1 = rango mínimo alcanzado).
  double get progresoMovimiento => _analizador?.detector.progreso(estado?.valorSenal) ?? 0;

  Duration? get tiempoRestante {
    final l = limite;
    if (l == null) return null;
    final r = l - reloj.elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  String get textoFase => switch (estado?.fase) {
    Fase.ida => ejercicio.faseIda,
    Fase.vuelta => ejercicio.faseVuelta,
    _ => 'Listo',
  };

  /// Zonas del cuerpo con error en la última repetición (se pintan en el esqueleto).
  Set<String> get zonasConAlerta {
    final rep = ultimaRep;
    if (rep == null || DateTime.now().difference(_horaUltimaRep) > const Duration(milliseconds: 2500)) return const {};
    return {
      for (final codigo in rep.fallos)
        if (_analizador?.verificacion(codigo) case final v?) v.zona,
    };
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  void _reenviar() => _notificar();

  /// Prepara una nueva serie (otro ejercicio u objetivo) sin cerrar la cámara.
  void prepararSerie({EjercicioSpec? ejercicio, int? objetivo, Duration? limite}) {
    _temporizador?.cancel();
    if (ejercicio != null) this.ejercicio = ejercicio;
    this.objetivo = objetivo ?? this.ejercicio.objetivoRepeticiones;
    if (limite != null) this.limite = limite;
    _analizador = null;
    _grabador.reiniciar();
    estado = null;
    ultimaRep = null;
    aviso = null;
    faltantes = const [];
    _cuadrosEncuadrados = 0;
    reloj
      ..stop()
      ..reset();
    etapa = EtapaSesion.encuadre;
    _notificar();
  }

  // ------------------------------------------------------- lógica de sesión
  void _alFotograma(Fotograma f) {
    final vmin = spec.globales.visibilidadMinima;
    switch (etapa) {
      case EtapaSesion.encuadre:
        faltantes = gruposFaltantes(f, vmin, ejercicio.puntosRequeridos);
        if (faltantes.isEmpty) {
          _cuadrosEncuadrados++;
          if (_cuadrosEncuadrados >= 8) _iniciarCuentaRegresiva();
        } else {
          _cuadrosEncuadrados = 0;
        }
      case EtapaSesion.cuentaRegresiva:
        faltantes = gruposFaltantes(f, vmin, ejercicio.puntosRequeridos);
      case EtapaSesion.activa:
        final e = _analizador!.procesar(f);
        estado = e;
        faltantes = e.faltantes;
        _grabador
          ..aspecto = camara.aspecto
          ..agregar(f.tMs, camara.puntosNormalizados(indicesEsqueleto));
        final rep = e.nuevaRepeticion;
        if (rep != null) _alRepeticion(rep);
        if (e.repeticionIncompleta) {
          _avisar(
            AvisoEnVivo(
              'Repetición incompleta',
              detalle: 'Completa todo el rango de movimiento.',
              severidad: Severidad.leve,
            ),
          );
          _hablar('Completa el movimiento');
        }
        if (!e.valido && faltantes.isNotEmpty) _avisarFaltantes();
        final l = limite;
        if (l != null && reloj.elapsed >= l) {
          _completarSerie('¡Tiempo!');
        } else if (autoFinalizar && repeticiones >= objetivo) {
          _completarSerie('¡Serie completada!');
        }
      default:
        break;
    }
  }

  void _iniciarCuentaRegresiva() {
    etapa = EtapaSesion.cuentaRegresiva;
    cuenta = segundosCuentaRegresiva;
    _hablar('Prepárate', prioritario: true);
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      cuenta--;
      if (cuenta <= 0) {
        t.cancel();
        _comenzar();
      } else if (cuenta <= 3) {
        _hablar('$cuenta', prioritario: true);
      }
      _notificar();
    });
    _notificar();
  }

  /// Omite la espera de encuadre y empieza de inmediato.
  void comenzarAhora() {
    _temporizador?.cancel();
    _comenzar();
  }

  void _comenzar() {
    _analizador = Analizador(spec, ejercicio.id);
    _grabador.reiniciar();
    etapa = EtapaSesion.activa;
    reloj
      ..reset()
      ..start();
    final l = limite;
    if (l != null) {
      // Revisa el tiempo aunque no lleguen cuadros (persona fuera de cuadro).
      _temporizador?.cancel();
      _temporizador = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (etapa != EtapaSesion.activa) {
          t.cancel();
        } else if (reloj.elapsed >= l) {
          t.cancel();
          _completarSerie('¡Tiempo!');
        } else {
          _notificar();
        }
      });
    }
    _avisar(
      AvisoEnVivo(
        '¡Comienza!',
        detalle: l != null ? '${l.inSeconds} segundos: todas las que puedas' : '$objetivo repeticiones como objetivo',
      ),
    );
    _hablar('Comienza', prioritario: true);
    _notificar();
  }

  void _completarSerie(String mensaje) {
    if (etapa != EtapaSesion.activa) return;
    etapa = EtapaSesion.serieCompleta;
    reloj.stop();
    _temporizador?.cancel();
    if (vibracion) HapticFeedback.heavyImpact();
    _avisar(AvisoEnVivo(mensaje));
    _hablar(mensaje, prioritario: true);
    _notificar();
  }

  /// Termina la serie a mano (botón).
  void terminarSerie() => _completarSerie('Serie terminada');

  void _alRepeticion(RepeticionEvaluada rep) {
    ultimaRep = rep;
    _horaUltimaRep = DateTime.now();
    if (vibracion) HapticFeedback.mediumImpact();
    if (rep.fallos.isEmpty) {
      _avisar(AvisoEnVivo('Repetición ${rep.numero} correcta'));
      _hablar('${rep.numero}', prioritario: true);
      return;
    }
    const orden = {'alta': 0, 'moderada': 1, 'leve': 2, 'info': 3};
    final fallos = [for (final c in rep.fallos) ?_analizador!.verificacion(c)]
      ..sort((a, b) => (orden[a.severidad] ?? 9).compareTo(orden[b.severidad] ?? 9));
    final principal = fallos.first;
    _avisar(AvisoEnVivo(principal.titulo, detalle: principal.mensaje, severidad: Severidad.desde(principal.severidad)));
    _hablar('${rep.numero}. ${fraseCorta(principal.mensaje)}', prioritario: true);
  }

  void _avisarFaltantes() {
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoAvisoFaltantes) < const Duration(seconds: 6)) return;
    _ultimoAvisoFaltantes = ahora;
    _hablar('Aléjate un poco de la cámara');
  }

  void _avisar(AvisoEnVivo a) => aviso = a;

  void _hablar(String texto, {bool prioritario = false}) {
    if (vozActiva) voz.decir(texto, prioritario: prioritario);
  }

  void alternarVoz() {
    vozActiva = !vozActiva;
    if (!vozActiva) voz.detener();
    _notificar();
  }

  /// Resultado de la serie actual (sin cerrar la cámara). null si no empezó.
  ResultadoSerie? tomarResultado() {
    final a = _analizador;
    if (a == null) return null;
    final d = a.detector;
    final extra = d.enMovimiento && (d.picoValido || d.progreso(estado?.valorSenal) >= 0.5) ? 1 : 0;
    return ResultadoSerie(
      resultado: ResultadoAnalisis.fromJson(a.resultado()),
      esqueleto: _grabador.resultado(),
      conteoFinal: a.repeticiones.length + extra,
      duracion: reloj.elapsed,
    );
  }

  /// Termina la sesión: detiene la cámara y entrega el resultado.
  Future<ResultadoSerie?> finalizar() async {
    if (etapa == EtapaSesion.activa) reloj.stop();
    etapa = EtapaSesion.finalizando;
    _temporizador?.cancel();
    _notificar();
    final r = tomarResultado();
    await camara.pausar();
    return r;
  }

  @override
  void dispose() {
    _cerrado = true;
    _temporizador?.cancel();
    camara.removeListener(_reenviar);
    if (camara.alFotograma == _alFotograma) camara.alFotograma = null;
    voz.detener();
    super.dispose();
  }
}

/// Primera frase de un mensaje, para indicaciones por voz breves.
String fraseCorta(String mensaje) {
  final corte = mensaje.indexOf(RegExp(r'[:;.]'));
  return corte > 0 ? mensaje.substring(0, corte) : mensaje;
}
