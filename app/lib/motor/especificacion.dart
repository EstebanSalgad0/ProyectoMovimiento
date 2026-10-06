// Especificación compartida de ejercicios (assets/especificacion/ejercicios.json).
// Es una copia exacta de compartido/ejercicios.json: el servidor usa la misma,
// así el análisis en tiempo real y el de video aplican las mismas reglas.

class EspecificacionInvalida implements Exception {
  final String mensaje;
  const EspecificacionInvalida(this.mensaje);
  @override
  String toString() => 'EspecificacionInvalida: $mensaje';
}

const tiposVerificacion = {
  'pico_max',
  'pico_min',
  'rep_max',
  'rep_rango_max',
  'reposo_min',
  'reposo_max',
  'asimetria_pico',
  'duracion_min',
};
const _tiposQueFallanPorMenor = {'pico_min', 'reposo_min', 'duracion_min'};
const severidades = ['info', 'leve', 'moderada', 'alta'];
const gruposValidos = {'cara', 'hombros', 'codos', 'munecas', 'caderas', 'rodillas', 'tobillos'};

double _num(dynamic v) => (v as num).toDouble();

class Senal {
  final String metrica;
  final String nombre;
  final String unidad;
  final String direccion;
  final double inicio;
  final double fin;
  final double minimoRep;

  const Senal({
    required this.metrica,
    required this.nombre,
    required this.unidad,
    required this.direccion,
    required this.inicio,
    required this.fin,
    required this.minimoRep,
  });

  int get signo => direccion == 'ascendente' ? 1 : -1;
  bool get esDescendente => direccion == 'descendente';

  factory Senal.fromJson(Map<String, dynamic> j) => Senal(
    metrica: j['metrica'] as String,
    nombre: j['nombre'] as String,
    unidad: (j['unidad'] ?? '') as String,
    direccion: j['direccion'] as String,
    inicio: _num(j['inicio']),
    fin: _num(j['fin']),
    minimoRep: _num(j['minimo_rep']),
  );
}

class Verificacion {
  final String codigo;
  final String tipo;
  final double umbral;
  final String severidad;
  final String zona;
  final String titulo;
  final String mensaje;
  final String? metrica;
  final List<String>? metricas;
  final String? fase;
  final List<String>? vistas;
  final String? mensajeOk;

  const Verificacion({
    required this.codigo,
    required this.tipo,
    required this.umbral,
    required this.severidad,
    required this.zona,
    required this.titulo,
    required this.mensaje,
    this.metrica,
    this.metricas,
    this.fase,
    this.vistas,
    this.mensajeOk,
  });

  bool get fallaPorMenor => _tiposQueFallanPorMenor.contains(tipo);

  Verificacion conUmbral(double nuevo) => Verificacion(
    codigo: codigo,
    tipo: tipo,
    umbral: nuevo,
    severidad: severidad,
    zona: zona,
    titulo: titulo,
    mensaje: mensaje,
    metrica: metrica,
    metricas: metricas,
    fase: fase,
    vistas: vistas,
    mensajeOk: mensajeOk,
  );

  /// Rango razonable para ajustar el umbral desde la app.
  RangoAjuste get rangoAjuste {
    final m = metrica ?? '';
    if (tipo == 'duracion_min') return const RangoAjuste(0.2, 4, 0.1, 's');
    if (m.startsWith('valgo')) return const RangoAjuste(0.05, 0.5, 0.01, '');
    if (m.startsWith('munecas')) return const RangoAjuste(-0.2, 1, 0.05, '');
    final min = (umbral - 40).clamp(0, 180).toDouble();
    final max = (umbral + 40).clamp(0, 180).toDouble();
    return RangoAjuste(min, max, 1, '°');
  }

  factory Verificacion.fromJson(String ejercicioId, Map<String, dynamic> j) {
    final tipo = j['tipo'] as String?;
    if (!tiposVerificacion.contains(tipo)) {
      throw EspecificacionInvalida('$ejercicioId: tipo de verificación desconocido "$tipo"');
    }
    if (!severidades.contains(j['severidad'])) {
      throw EspecificacionInvalida('$ejercicioId/${j['codigo']}: severidad inválida');
    }
    final metricas = (j['metricas'] as List?)?.cast<String>();
    if (tipo == 'asimetria_pico' && (metricas == null || metricas.length != 2)) {
      throw EspecificacionInvalida('$ejercicioId/${j['codigo']}: asimetria_pico requiere 2 métricas');
    }
    if (tipo == 'duracion_min' && !const {'excentrica', 'concentrica', 'total'}.contains(j['fase'])) {
      throw EspecificacionInvalida('$ejercicioId/${j['codigo']}: fase de duración inválida');
    }
    if (tipo != 'asimetria_pico' && tipo != 'duracion_min' && j['metrica'] == null) {
      throw EspecificacionInvalida('$ejercicioId/${j['codigo']}: falta "metrica"');
    }
    return Verificacion(
      codigo: j['codigo'] as String,
      tipo: tipo!,
      umbral: _num(j['umbral']),
      severidad: j['severidad'] as String,
      zona: (j['zona'] ?? 'general') as String,
      titulo: j['titulo'] as String,
      mensaje: j['mensaje'] as String,
      metrica: j['metrica'] as String?,
      metricas: metricas,
      fase: j['fase'] as String?,
      vistas: (j['vistas'] as List?)?.cast<String>(),
      mensajeOk: j['mensaje_ok'] as String?,
    );
  }
}

class RangoAjuste {
  final double min;
  final double max;
  final double paso;
  final String unidad;
  const RangoAjuste(this.min, this.max, this.paso, this.unidad);
}

/// Ajuste personal de una verificación: otro umbral y/o desactivarla.
class AjusteVerificacion {
  final double? umbral;
  final bool activa;

  const AjusteVerificacion({this.umbral, this.activa = true});

  factory AjusteVerificacion.fromJson(Map<String, dynamic> j) =>
      AjusteVerificacion(umbral: (j['umbral'] as num?)?.toDouble(), activa: (j['activa'] ?? true) as bool);

  Map<String, dynamic> toJson() => {if (umbral != null) 'umbral': umbral, 'activa': activa};
}

/// ejercicioId → código de verificación → ajuste. Mismo formato que acepta el
/// servidor en el campo `ajustes`.
typedef AjustesEjercicios = Map<String, Map<String, AjusteVerificacion>>;

AjustesEjercicios ajustesDesdeJson(Map<String, dynamic> j) => {
  for (final e in j.entries)
    if (e.value is Map)
      e.key: {
        for (final v in (e.value as Map).entries)
          if (v.value is Map) v.key as String: AjusteVerificacion.fromJson(Map<String, dynamic>.from(v.value as Map)),
      },
};

Map<String, dynamic> ajustesAJson(AjustesEjercicios a) => {
  for (final e in a.entries)
    if (e.value.isNotEmpty) e.key: {for (final v in e.value.entries) v.key: v.value.toJson()},
};

/// Definición de un ejercicio: datos para la interfaz + reglas del motor.
class EjercicioSpec {
  final String id;
  final String nombre;
  final String categoria;
  final String posicion;
  final String dificultad;
  final String vistaRecomendada;
  final int objetivoRepeticiones;
  final String descripcion;
  final List<String> musculos;
  final String camara;
  final List<String> pasos;
  final List<String> puntosRequeridos;
  final Map<String, String> fases;
  final Senal senal;
  final List<Verificacion> verificaciones;

  const EjercicioSpec({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.posicion,
    required this.dificultad,
    required this.vistaRecomendada,
    required this.objetivoRepeticiones,
    required this.descripcion,
    required this.musculos,
    required this.camara,
    required this.pasos,
    required this.puntosRequeridos,
    required this.fases,
    required this.senal,
    required this.verificaciones,
  });

  String get faseIda => fases['ida'] ?? 'Ida';
  String get faseVuelta => fases['vuelta'] ?? 'Vuelta';

  /// Copia con umbrales personalizados y sin las verificaciones desactivadas.
  EjercicioSpec conAjustes(Map<String, AjusteVerificacion> ajustes) {
    if (ajustes.isEmpty) return this;
    final nuevas = <Verificacion>[];
    for (final v in verificaciones) {
      final a = ajustes[v.codigo];
      if (a == null) {
        nuevas.add(v);
      } else if (a.activa) {
        nuevas.add(a.umbral == null ? v : v.conUmbral(a.umbral!));
      }
    }
    return EjercicioSpec(
      id: id,
      nombre: nombre,
      categoria: categoria,
      posicion: posicion,
      dificultad: dificultad,
      vistaRecomendada: vistaRecomendada,
      objetivoRepeticiones: objetivoRepeticiones,
      descripcion: descripcion,
      musculos: musculos,
      camara: camara,
      pasos: pasos,
      puntosRequeridos: puntosRequeridos,
      fases: fases,
      senal: senal,
      verificaciones: nuevas,
    );
  }

  factory EjercicioSpec.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final senal = Senal.fromJson(Map<String, dynamic>.from(j['senal'] as Map));
    final s = senal.signo;
    if (senal.direccion != 'ascendente' && senal.direccion != 'descendente') {
      throw EspecificacionInvalida('$id: dirección inválida "${senal.direccion}"');
    }
    if (!(s * senal.fin < s * senal.inicio && s * senal.inicio < s * senal.minimoRep)) {
      throw EspecificacionInvalida('$id: umbrales de señal incoherentes');
    }
    final grupos = ((j['puntos_requeridos'] ?? const []) as List).cast<String>();
    if (grupos.any((g) => !gruposValidos.contains(g))) {
      throw EspecificacionInvalida('$id: grupos de puntos desconocidos');
    }
    final verificaciones = (j['verificaciones'] as List)
        .map((v) => Verificacion.fromJson(id, Map<String, dynamic>.from(v as Map)))
        .toList();
    final codigos = verificaciones.map((v) => v.codigo).toSet();
    if (codigos.length != verificaciones.length) {
      throw EspecificacionInvalida('$id: códigos de verificación duplicados');
    }
    return EjercicioSpec(
      id: id,
      nombre: j['nombre'] as String,
      categoria: (j['categoria'] ?? 'general') as String,
      posicion: (j['posicion'] ?? 'de_pie') as String,
      dificultad: (j['dificultad'] ?? 'basica') as String,
      vistaRecomendada: (j['vista_recomendada'] ?? 'frontal') as String,
      objetivoRepeticiones: (j['objetivo_repeticiones'] ?? 10) as int,
      descripcion: (j['descripcion'] ?? '') as String,
      musculos: ((j['musculos'] ?? const []) as List).cast<String>(),
      camara: (j['camara'] ?? '') as String,
      pasos: ((j['pasos'] ?? const []) as List).cast<String>(),
      puntosRequeridos: grupos,
      fases: Map<String, String>.from((j['fases'] ?? const {'ida': 'Ida', 'vuelta': 'Vuelta'}) as Map),
      senal: senal,
      verificaciones: verificaciones,
    );
  }
}

class ParametrosGlobales {
  final double visibilidadMinima;
  final double fpsAnalisis;
  final double minCutoff;
  final double beta;
  final double dCutoff;
  final double reinicioFiltroS;
  final double umbralFrontal;
  final double umbralLateral;
  final Map<String, double> penalizacion;
  final double penalizacionIncompleta;
  final double penalizacionIncompletaMax;
  final double porcentajeValidosMinimo;
  final double duracionMinimaRepS;
  final int puntosSerieMax;

  const ParametrosGlobales({
    required this.visibilidadMinima,
    required this.fpsAnalisis,
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
    required this.reinicioFiltroS,
    required this.umbralFrontal,
    required this.umbralLateral,
    required this.penalizacion,
    required this.penalizacionIncompleta,
    required this.penalizacionIncompletaMax,
    required this.porcentajeValidosMinimo,
    required this.duracionMinimaRepS,
    required this.puntosSerieMax,
  });

  factory ParametrosGlobales.fromJson(Map<String, dynamic> g) {
    final suav = Map<String, dynamic>.from(g['suavizado'] as Map);
    final vista = Map<String, dynamic>.from(g['vista'] as Map);
    return ParametrosGlobales(
      visibilidadMinima: _num(g['visibilidad_minima']),
      fpsAnalisis: _num(g['fps_analisis']),
      minCutoff: _num(suav['min_cutoff']),
      beta: _num(suav['beta']),
      dCutoff: _num(suav['d_cutoff']),
      reinicioFiltroS: _num(g['reinicio_filtro_s']),
      umbralFrontal: _num(vista['umbral_frontal']),
      umbralLateral: _num(vista['umbral_lateral']),
      penalizacion: (g['penalizacion'] as Map).map((k, v) => MapEntry(k as String, _num(v))),
      penalizacionIncompleta: _num(g['penalizacion_incompleta']),
      penalizacionIncompletaMax: _num(g['penalizacion_incompleta_max']),
      porcentajeValidosMinimo: _num(g['porcentaje_validos_minimo']),
      duracionMinimaRepS: _num(g['duracion_minima_rep_s']),
      puntosSerieMax: g['puntos_serie_max'] as int,
    );
  }
}

class Especificacion {
  final String version;
  final ParametrosGlobales globales;
  final List<EjercicioSpec> ejercicios;

  const Especificacion({required this.version, required this.globales, required this.ejercicios});

  factory Especificacion.fromJson(Map<String, dynamic> j) => Especificacion(
    version: j['version'] as String,
    globales: ParametrosGlobales.fromJson(Map<String, dynamic>.from(j['parametros_globales'] as Map)),
    ejercicios: (j['ejercicios'] as List)
        .map((e) => EjercicioSpec.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  EjercicioSpec ejercicio(String id) =>
      ejercicios.firstWhere((e) => e.id == id, orElse: () => throw ArgumentError('Ejercicio no soportado: $id'));

  /// Especificación con los objetivos personales del usuario aplicados.
  Especificacion conAjustes(AjustesEjercicios ajustes) {
    if (ajustes.values.every((m) => m.isEmpty)) return this;
    return Especificacion(
      version: version,
      globales: globales,
      ejercicios: [for (final e in ejercicios) e.conAjustes(ajustes[e.id] ?? const {})],
    );
  }

  EjercicioSpec? buscar(String id) {
    for (final e in ejercicios) {
      if (e.id == id) return e;
    }
    return null;
  }
}
