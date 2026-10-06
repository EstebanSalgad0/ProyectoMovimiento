import 'dart:math';

import 'usuario.dart';

class ItemRutina {
  final String ejercicioId;
  final int series;
  final int repeticiones;
  final int descansoS;

  const ItemRutina({required this.ejercicioId, this.series = 2, this.repeticiones = 10, this.descansoS = 60});

  ItemRutina copyWith({String? ejercicioId, int? series, int? repeticiones, int? descansoS}) => ItemRutina(
    ejercicioId: ejercicioId ?? this.ejercicioId,
    series: series ?? this.series,
    repeticiones: repeticiones ?? this.repeticiones,
    descansoS: descansoS ?? this.descansoS,
  );

  factory ItemRutina.fromJson(Map<String, dynamic> j) => ItemRutina(
    ejercicioId: j['ejercicio'] as String,
    series: (j['series'] as num? ?? 2).toInt(),
    repeticiones: (j['repeticiones'] as num? ?? 10).toInt(),
    descansoS: (j['descanso_s'] as num? ?? 60).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'ejercicio': ejercicioId,
    'series': series,
    'repeticiones': repeticiones,
    'descanso_s': descansoS,
  };
}

class Rutina {
  final String id;
  final String nombre;
  final String descripcion;
  final List<ItemRutina> items;
  final bool predefinida;
  final String nivel;

  const Rutina({
    required this.id,
    required this.nombre,
    required this.items,
    this.descripcion = '',
    this.predefinida = false,
    this.nivel = 'basica',
  });

  int get totalSeries => items.fold(0, (t, i) => t + i.series);
  int get totalRepeticiones => items.fold(0, (t, i) => t + i.series * i.repeticiones);

  /// Estimación: ~3,5 s por repetición, descansos entre series y 20 s para
  /// acomodarse entre ejercicios.
  int get minutosEstimados {
    var s = 0.0;
    for (final i in items) {
      s += i.series * i.repeticiones * 3.5 + (i.series - 1) * i.descansoS + 20;
    }
    return max(1, (s / 60).round());
  }

  static String nuevoId() => 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  Rutina copyWith({String? nombre, String? descripcion, List<ItemRutina>? items, String? nivel}) => Rutina(
    id: id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    items: items ?? this.items,
    predefinida: predefinida,
    nivel: nivel ?? this.nivel,
  );

  factory Rutina.fromJson(Map<String, dynamic> j) => Rutina(
    id: j['id'] as String,
    nombre: (j['nombre'] ?? 'Rutina') as String,
    descripcion: (j['descripcion'] ?? '') as String,
    items: ((j['items'] ?? const []) as List)
        .map((e) => ItemRutina.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    nivel: (j['nivel'] ?? 'basica') as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'items': [for (final i in items) i.toJson()],
    'nivel': nivel,
  };
}

/// Rutinas incluidas en la app. Son un punto de partida razonable; los
/// profesionales pueden crear las suyas desde la app.
const rutinasPredefinidas = <Rutina>[
  Rutina(
    id: 'activacion_diaria',
    nombre: 'Activación diaria',
    descripcion: 'Rutina corta para activar piernas y hombros. Ideal para empezar el día.',
    predefinida: true,
    items: [
      ItemRutina(ejercicioId: 'sentadilla', series: 2, repeticiones: 8, descansoS: 45),
      ItemRutina(ejercicioId: 'elevacion_lateral', series: 2, repeticiones: 10, descansoS: 45),
      ItemRutina(ejercicioId: 'sentarse_pararse', series: 2, repeticiones: 8, descansoS: 60),
    ],
  ),
  Rutina(
    id: 'fuerza_piernas',
    nombre: 'Fuerza de piernas',
    descripcion: 'Sentadillas y zancadas para ganar fuerza y control en el tren inferior.',
    predefinida: true,
    nivel: 'intermedia',
    items: [
      ItemRutina(ejercicioId: 'sentadilla', series: 3, repeticiones: 10, descansoS: 60),
      ItemRutina(ejercicioId: 'zancada', series: 3, repeticiones: 8, descansoS: 60),
      ItemRutina(ejercicioId: 'sentarse_pararse', series: 2, repeticiones: 12, descansoS: 60),
    ],
  ),
  Rutina(
    id: 'superior_sentado',
    nombre: 'Tren superior sentado',
    descripcion: 'Brazos y hombros sin ponerte de pie. Solo necesitas una silla y pesas livianas.',
    predefinida: true,
    items: [
      ItemRutina(ejercicioId: 'curl_biceps_sentado', series: 3, repeticiones: 12, descansoS: 45),
      ItemRutina(ejercicioId: 'press_hombros_sentado', series: 3, repeticiones: 10, descansoS: 60),
      ItemRutina(ejercicioId: 'elevacion_lateral', series: 2, repeticiones: 12, descansoS: 45),
    ],
  ),
  Rutina(
    id: 'movilidad_autonomia',
    nombre: 'Movilidad y autonomía',
    descripcion: 'Pensada para adultos mayores: levantarse de la silla, brazos y control del cuerpo.',
    predefinida: true,
    items: [
      ItemRutina(ejercicioId: 'sentarse_pararse', series: 3, repeticiones: 8, descansoS: 90),
      ItemRutina(ejercicioId: 'elevacion_lateral', series: 2, repeticiones: 8, descansoS: 60),
      ItemRutina(ejercicioId: 'curl_biceps_sentado', series: 2, repeticiones: 10, descansoS: 60),
    ],
  ),
];

/// Rutina predefinida que mejor encaja con el objetivo y la edad del usuario.
String idRutinaSugerida(Objetivo? objetivo, int? edad) {
  return switch (objetivo) {
    Objetivo.fuerza => 'fuerza_piernas',
    Objetivo.prevencionCaidas || Objetivo.movilidad => 'movilidad_autonomia',
    _ => (edad ?? 0) >= 65 ? 'movilidad_autonomia' : 'activacion_diaria',
  };
}

/// Una serie concreta dentro de la ejecución de una rutina.
class PasoRutina {
  final int indiceItem;
  final ItemRutina item;
  final int serie;

  const PasoRutina({required this.indiceItem, required this.item, required this.serie});

  bool get esPrimeraSerie => serie == 1;
  bool get esUltimaSerie => serie == item.series;
}

enum EstadoGuiado { preparando, serie, descanso, terminado }

/// Máquina de estados de una sesión guiada (sin dependencias de interfaz,
/// para poder probarla aislada).
class PlanSesionGuiada {
  final Rutina rutina;
  final List<PasoRutina> pasos;
  final String ejecucionId;
  int _indice = 0;
  EstadoGuiado estado = EstadoGuiado.preparando;
  final List<String> sesionesCompletadas = [];

  PlanSesionGuiada(this.rutina, {String? ejecucionId})
    : pasos = [
        for (var i = 0; i < rutina.items.length; i++)
          for (var s = 1; s <= rutina.items[i].series; s++) PasoRutina(indiceItem: i, item: rutina.items[i], serie: s),
      ],
      ejecucionId = ejecucionId ?? 'e${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  int get indice => _indice;
  PasoRutina get actual => pasos[_indice];
  PasoRutina? get siguiente => _indice + 1 < pasos.length ? pasos[_indice + 1] : null;
  double get avance => pasos.isEmpty ? 1 : (_indice + (estado == EstadoGuiado.terminado ? 1 : 0)) / pasos.length;

  /// ¿El próximo paso cambia de ejercicio? (requiere reacomodar la cámara).
  bool get siguienteCambiaEjercicio {
    final s = siguiente;
    return s != null && s.item.ejercicioId != actual.item.ejercicioId;
  }

  void comenzarSerie() {
    if (estado == EstadoGuiado.terminado) return;
    estado = EstadoGuiado.serie;
  }

  /// Registra la serie terminada y pasa a descanso o al final.
  void completarSerie({String? sesionId}) {
    if (estado == EstadoGuiado.terminado) return;
    if (sesionId != null) sesionesCompletadas.add(sesionId);
    if (siguiente == null) {
      estado = EstadoGuiado.terminado;
    } else {
      estado = EstadoGuiado.descanso;
    }
  }

  /// Termina el descanso y prepara la siguiente serie.
  void avanzar() {
    if (estado == EstadoGuiado.terminado) return;
    if (siguiente == null) {
      estado = EstadoGuiado.terminado;
      return;
    }
    _indice++;
    estado = EstadoGuiado.preparando;
  }

  void terminar() => estado = EstadoGuiado.terminado;
}
