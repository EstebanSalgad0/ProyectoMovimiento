// Orquestador del análisis (port 1:1 de servidor/motor/analizador.py):
// métricas → suavizado → repeticiones → evaluación → resultado.
//
// El resultado tiene exactamente el mismo formato JSON que entrega la API, así
// la pantalla de resultados muestra igual un análisis en vivo o de video.

import 'dart:math' as math;

import 'especificacion.dart';
import 'filtro_one_euro.dart';
import 'geometria.dart';
import 'metricas.dart';
import 'puntos.dart';
import 'repeticiones.dart';

const versionResultado = '2.0';
const _ordenSeveridad = {'alta': 0, 'moderada': 1, 'leve': 2, 'info': 3};
const nombresGrupo = {
  'cara': 'la cara',
  'hombros': 'los hombros',
  'codos': 'los codos',
  'munecas': 'las muñecas',
  'caderas': 'las caderas',
  'rodillas': 'las rodillas',
  'tobillos': 'los tobillos',
};
const _nombresVista = {'frontal': 'de frente', 'lateral': 'de costado', 'oblicua': 'en diagonal'};

/// Valor más frecuente; en empate gana el primero que apareció (igual que en Python).
String? mayoria(Iterable<String> valores) {
  final conteo = <String, int>{};
  for (final v in valores) {
    conteo[v] = (conteo[v] ?? 0) + 1;
  }
  String? mejor;
  var mejorN = 0;
  conteo.forEach((v, n) {
    if (n > mejorN) {
      mejor = v;
      mejorN = n;
    }
  });
  return mejor;
}

double? _r(double? x, [int dec = 1]) {
  if (x == null) return null;
  final f = math.pow(10, dec);
  return (x * f).roundToDouble() / f;
}

class FotogramaProcesado {
  final int tMs;
  final Map<String, double?> metricas;
  final String? vista;
  final bool valido;
  final List<String> faltantes;

  const FotogramaProcesado(this.tMs, this.metricas, this.vista, this.valido, this.faltantes);
}

class Evaluacion {
  final String codigo;
  final double valor;
  final bool falla;

  const Evaluacion(this.codigo, this.valor, this.falla);
}

class RepeticionEvaluada {
  final int numero;
  final int inicioMs;
  final int picoMs;
  final int finMs;
  final double excentricaS;
  final double concentricaS;
  final double valorPico;
  final double valorReposo;
  final String? vista;
  final int puntaje;
  final List<Evaluacion> evaluaciones;
  final List<String> omitidasPorVista;

  const RepeticionEvaluada({
    required this.numero,
    required this.inicioMs,
    required this.picoMs,
    required this.finMs,
    required this.excentricaS,
    required this.concentricaS,
    required this.valorPico,
    required this.valorReposo,
    required this.vista,
    required this.puntaje,
    required this.evaluaciones,
    required this.omitidasPorVista,
  });

  double get duracionS => (finMs - inicioMs) / 1000.0;
  double get rango => (valorReposo - valorPico).abs();
  List<String> get fallos => [
    for (final e in evaluaciones)
      if (e.falla) e.codigo,
  ];

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'inicio_ms': inicioMs,
    'pico_ms': picoMs,
    'fin_ms': finMs,
    'duracion_s': _r(duracionS, 2),
    'excentrica_s': _r(excentricaS, 2),
    'concentrica_s': _r(concentricaS, 2),
    'valor_pico': _r(valorPico),
    'valor_reposo': _r(valorReposo),
    'rango': _r(rango),
    'vista': vista,
    'puntaje': puntaje,
    'fallos': fallos,
    'valores': {for (final e in evaluaciones) e.codigo: _r(e.valor, 2)},
  };
}

/// Estado tras procesar un fotograma: alimenta la interfaz en tiempo real.
class EstadoFotograma {
  final bool valido;
  final double? valorSenal;
  final Fase fase;
  final int repeticiones;
  final int incompletas;
  final List<String> faltantes;
  final RepeticionEvaluada? nuevaRepeticion;
  final bool repeticionIncompleta;

  const EstadoFotograma({
    required this.valido,
    required this.valorSenal,
    required this.fase,
    required this.repeticiones,
    required this.incompletas,
    required this.faltantes,
    this.nuevaRepeticion,
    this.repeticionIncompleta = false,
  });
}

class Analizador {
  final Especificacion spec;
  final EjercicioSpec ej;
  final ParametrosGlobales g;
  final DetectorRepeticiones detector;
  final Map<String, FiltroOneEuro> _filtros = {};
  final List<FotogramaProcesado> fotogramas = [];
  final List<RepeticionEvaluada> repeticiones = [];
  int incompletas = 0;

  Analizador(this.spec, String ejercicioId)
    : ej = spec.ejercicio(ejercicioId),
      g = spec.globales,
      detector = DetectorRepeticiones(spec.ejercicio(ejercicioId).senal, spec.globales.duracionMinimaRepS);

  Map<String, double?> _suavizar(Map<String, double?> metricas, double tS) {
    final salida = <String, double?>{};
    metricas.forEach((nombre, valor) {
      if (valor == null) {
        salida[nombre] = null;
        return;
      }
      var filtro = _filtros[nombre];
      if (filtro == null) {
        filtro = FiltroOneEuro(minCutoff: g.minCutoff, beta: g.beta, dCutoff: g.dCutoff);
        _filtros[nombre] = filtro;
      } else {
        final ultimo = filtro.ultimoT;
        if (ultimo != null && tS - ultimo > g.reinicioFiltroS) filtro.reiniciar();
      }
      salida[nombre] = filtro.filtrar(valor, tS);
    });
    return salida;
  }

  EstadoFotograma procesar(Fotograma f) {
    final tS = f.tMs / 1000.0;
    final vmin = g.visibilidadMinima;
    final metricas = _suavizar(calcularMetricas(f, vmin), tS);
    final vista = detectarVista(f, vmin, g.umbralFrontal, g.umbralLateral);
    final senal = metricas[ej.senal.metrica];
    final valido = senal != null;
    final faltantes = valido ? const <String>[] : gruposFaltantes(f, vmin, ej.puntosRequeridos);
    final idx = fotogramas.length;
    fotogramas.add(FotogramaProcesado(f.tMs, metricas, vista, valido, faltantes));

    final evento = detector.actualizar(idx, tS, senal);
    RepeticionEvaluada? nueva;
    var incompleta = false;
    if (evento != null) {
      if (evento.valida) {
        nueva = _evaluar(evento);
        repeticiones.add(nueva);
      } else {
        incompletas++;
        incompleta = true;
      }
    }
    return EstadoFotograma(
      valido: valido,
      valorSenal: senal,
      fase: detector.fase,
      repeticiones: repeticiones.length,
      incompletas: incompletas,
      faltantes: faltantes,
      nuevaRepeticion: nueva,
      repeticionIncompleta: incompleta,
    );
  }

  double? _valor(
    Verificacion v,
    List<FotogramaProcesado> ventana,
    FotogramaProcesado pico,
    FotogramaProcesado reposo,
    EventoRepeticion ev,
  ) {
    switch (v.tipo) {
      case 'pico_max':
      case 'pico_min':
        return pico.metricas[v.metrica];
      case 'reposo_min':
      case 'reposo_max':
        return reposo.metricas[v.metrica];
      case 'rep_max':
      case 'rep_rango_max':
        final valores = ventana.map((fr) => fr.metricas[v.metrica]).whereType<double>().toList();
        if (valores.isEmpty) return null;
        final maximo = valores.reduce(math.max);
        if (v.tipo == 'rep_max') return maximo;
        return valores.length >= 2 ? maximo - valores.reduce(math.min) : null;
      case 'asimetria_pico':
        final a = pico.metricas[v.metricas![0]];
        final b = pico.metricas[v.metricas![1]];
        return a != null && b != null ? (a - b).abs() : null;
      case 'duracion_min':
        if (v.fase == 'excentrica') return ev.tPicoS - ev.tInicioS;
        if (v.fase == 'concentrica') return ev.tFinS - ev.tPicoS;
        return ev.tFinS - ev.tInicioS;
    }
    return null;
  }

  RepeticionEvaluada _evaluar(EventoRepeticion ev) {
    final ventana = fotogramas.sublist(ev.idxInicio, ev.idxFin + 1);
    final pico = fotogramas[ev.idxPico];
    final reposo = fotogramas[ev.idxReposo];
    final vista = mayoria(ventana.map((fr) => fr.vista).whereType<String>());
    final evaluaciones = <Evaluacion>[];
    final omitidas = <String>[];
    var penalizacion = 0.0;
    for (final v in ej.verificaciones) {
      final vistas = v.vistas;
      if (vistas != null && !vistas.contains(vista)) {
        omitidas.add(v.codigo);
        continue;
      }
      final valor = _valor(v, ventana, pico, reposo, ev);
      if (valor == null || valor.isNaN) continue;
      final falla = v.fallaPorMenor ? valor < v.umbral : valor > v.umbral;
      evaluaciones.add(Evaluacion(v.codigo, valor, falla));
      if (falla) penalizacion += g.penalizacion[v.severidad] ?? 0;
    }
    final metrica = ej.senal.metrica;
    return RepeticionEvaluada(
      numero: repeticiones.length + 1,
      inicioMs: fotogramas[ev.idxInicio].tMs,
      picoMs: pico.tMs,
      finMs: fotogramas[ev.idxFin].tMs,
      excentricaS: ev.tPicoS - ev.tInicioS,
      concentricaS: ev.tFinS - ev.tPicoS,
      valorPico: pico.metricas[metrica]!,
      valorReposo: reposo.metricas[metrica]!,
      vista: vista,
      puntaje: math.max(0, redondear(100.0 - penalizacion)),
      evaluaciones: evaluaciones,
      omitidasPorVista: omitidas,
    );
  }

  int puntaje() {
    if (repeticiones.isEmpty) return 0;
    final base = repeticiones.map((r) => r.puntaje).reduce((a, b) => a + b) / repeticiones.length;
    final castigo = math.min(g.penalizacionIncompletaMax, incompletas * g.penalizacionIncompleta);
    return redondear(base - castigo).clamp(0, 100);
  }

  /// Título de una verificación por su código (para mensajes en vivo).
  Verificacion? verificacion(String codigo) {
    for (final v in ej.verificaciones) {
      if (v.codigo == codigo) return v;
    }
    return null;
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _hallazgosYAciertos(
    double porcentajeValidos,
    String? vistaDominante,
  ) {
    final hallazgos = <Map<String, dynamic>>[];
    final aciertos = <Map<String, dynamic>>[];
    final evaluadasAlgunaVez = <String>{};
    for (final v in ej.verificaciones) {
      final evaluadas = [
        for (final r in repeticiones)
          for (final e in r.evaluaciones)
            if (e.codigo == v.codigo) (r.numero, e),
      ];
      if (evaluadas.isEmpty) continue;
      evaluadasAlgunaVez.add(v.codigo);
      final fallidas = evaluadas.where((x) => x.$2.falla).toList();
      if (fallidas.isNotEmpty) {
        final valores = fallidas.map((x) => x.$2.valor);
        final peor = v.fallaPorMenor ? valores.reduce(math.min) : valores.reduce(math.max);
        hallazgos.add({
          'codigo': v.codigo,
          'severidad': v.severidad,
          'zona': v.zona,
          'titulo': v.titulo,
          'mensaje': v.mensaje,
          'repeticiones': [for (final x in fallidas) x.$1],
          'total_evaluadas': evaluadas.length,
          'valor': _r(peor, 2),
          'umbral': v.umbral,
        });
      } else if (v.mensajeOk != null) {
        aciertos.add({'codigo': v.codigo, 'zona': v.zona, 'mensaje': v.mensajeOk});
      }
    }

    if (incompletas > 0) {
      final n = incompletas;
      hallazgos.add({
        'codigo': 'REPETICIONES_INCOMPLETAS',
        'severidad': 'leve',
        'zona': 'general',
        'titulo': n == 1 ? '$n repetición incompleta' : '$n repeticiones incompletas',
        'mensaje': 'Algunas repeticiones no alcanzaron el rango mínimo de movimiento.',
        'repeticiones': <int>[],
        'total_evaluadas': repeticiones.length + n,
      });
    }
    if (repeticiones.isEmpty) {
      hallazgos.add({
        'codigo': 'SIN_REPETICIONES',
        'severidad': 'info',
        'zona': 'general',
        'titulo': 'No se detectaron repeticiones completas',
        'mensaje': 'Haz el movimiento completo y verifica que todo tu cuerpo se vea en la cámara.',
        'repeticiones': <int>[],
      });
    }
    if (porcentajeValidos < g.porcentajeValidosMinimo) {
      final grupo = mayoria([for (final fr in fotogramas) ...fr.faltantes]);
      final detalle = grupo != null ? ' En la mayor parte no se ven ${nombresGrupo[grupo] ?? grupo}.' : '';
      hallazgos.add({
        'codigo': 'CALIDAD_BAJA',
        'severidad': 'info',
        'zona': 'general',
        'titulo': 'Cuerpo poco visible',
        'mensaje': 'Gran parte del registro no se pudo evaluar.$detalle Aléjate de la cámara y mejora la iluminación.',
        'repeticiones': <int>[],
      });
    }
    if (repeticiones.isNotEmpty && vistaDominante != null && vistaDominante != ej.vistaRecomendada) {
      final nunca = [
        for (final v in ej.verificaciones)
          if (!evaluadasAlgunaVez.contains(v.codigo) && (v.vistas?.contains(ej.vistaRecomendada) ?? false))
            v.titulo.toLowerCase(),
      ];
      if (nunca.isNotEmpty) {
        hallazgos.add({
          'codigo': 'VISTA_RECOMENDADA',
          'severidad': 'info',
          'zona': 'general',
          'titulo': 'Grábate ${_nombresVista[ej.vistaRecomendada] ?? ''} para un análisis completo',
          'mensaje': 'Con esta vista no se pudo evaluar: ${nunca.join(', ')}.',
          'repeticiones': <int>[],
        });
      }
    }
    // Orden estable por severidad (List.sort de Dart no garantiza estabilidad).
    final indexados = hallazgos.asMap().entries.toList()
      ..sort((a, b) {
        final c = (_ordenSeveridad[a.value['severidad']] ?? 9).compareTo(_ordenSeveridad[b.value['severidad']] ?? 9);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return ([for (final e in indexados) e.value], aciertos);
  }

  Map<String, dynamic> _serie() {
    final s = ej.senal;
    final total = fotogramas.length;
    final paso = total == 0 ? 1 : math.max(1, (total / g.puntosSerieMax).ceil());
    final muestra = [for (var i = 0; i < total; i += paso) fotogramas[i]];
    return {
      'metrica': s.metrica,
      'nombre': s.nombre,
      'unidad': s.unidad,
      't_ms': [for (final fr in muestra) fr.tMs],
      'valores': [for (final fr in muestra) _r(fr.metricas[s.metrica])],
    };
  }

  Map<String, dynamic> resultado() {
    final total = fotogramas.length;
    final validos = fotogramas.where((fr) => fr.valido).length;
    final porcentaje = total == 0 ? 0.0 : validos / total;
    final vista = mayoria([
      for (final fr in fotogramas)
        if (fr.valido && fr.vista != null) fr.vista!,
    ]);
    final (hallazgos, aciertos) = _hallazgosYAciertos(porcentaje, vista);
    final reps = repeticiones;
    final duracion = total > 1 ? (fotogramas.last.tMs - fotogramas.first.tMs) / 1000.0 : 0.0;

    double promedio(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    final metricas = <String, double>{
      'repeticiones': reps.length.toDouble(),
      'repeticiones_incompletas': incompletas.toDouble(),
      'duracion_s': _r(duracion)!,
      'porcentaje_validos': _r(porcentaje * 100)!,
    };
    if (reps.isNotEmpty) {
      final picos = reps.map((r) => r.valorPico);
      metricas.addAll({
        'pico_promedio': _r(promedio(picos))!,
        'pico_mejor': _r(ej.senal.esDescendente ? picos.reduce(math.min) : picos.reduce(math.max))!,
        'rango_promedio': _r(promedio(reps.map((r) => r.rango)))!,
        'duracion_rep_promedio_s': _r(promedio(reps.map((r) => r.duracionS)), 2)!,
        'excentrica_promedio_s': _r(promedio(reps.map((r) => r.excentricaS)), 2)!,
        'concentrica_promedio_s': _r(promedio(reps.map((r) => r.concentricaS)), 2)!,
      });
    }

    return {
      'version': versionResultado,
      'especificacion': spec.version,
      'ejercicio': ej.id,
      'nombre_ejercicio': ej.nombre,
      'puntaje': puntaje(),
      'feedback': [
        for (final h in hallazgos) '${h['titulo']}: ${h['mensaje']}',
        for (final a in aciertos) a['mensaje'] as String,
      ],
      'metricas': metricas,
      'repeticiones': [for (final r in reps) r.toJson()],
      'hallazgos': hallazgos,
      'aciertos': aciertos,
      'serie': _serie(),
      'calidad': {
        'fotogramas': total,
        'fotogramas_validos': validos,
        'porcentaje_validos': _r(porcentaje * 100),
        'vista': vista,
        'confianza': _r(porcentaje, 2),
      },
      'duracion_s': _r(duracion),
    };
  }
}
