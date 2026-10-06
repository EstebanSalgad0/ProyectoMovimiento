import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/motor/analizador.dart';
import 'package:medicina_app/motor/especificacion.dart';
import 'package:medicina_app/motor/filtro_one_euro.dart';
import 'package:medicina_app/motor/geometria.dart';
import 'package:medicina_app/motor/puntos.dart';
import 'package:medicina_app/motor/repeticiones.dart';

// Los tests se ejecutan con el directorio app/ como raíz.
final _dirCompartido = Directory('../compartido');

Map<String, dynamic> _leerJson(String ruta) => jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final spec = Especificacion.fromJson(_leerJson('assets/especificacion/ejercicios.json'));

  group('geometría', () {
    test('ángulo recto y extendido', () {
      const b = Punto(0, 0, 0);
      expect(anguloArticular(const Punto(0, 1, 0), b, const Punto(1, 0, 0)), closeTo(90, 1e-9));
      expect(anguloArticular(const Punto(0, 1, 0), b, const Punto(0, -1, 0)), closeTo(180, 1e-9));
    });

    test('inclinaciones en coordenadas de imagen', () {
      expect(inclinacionDesdeVertical(const Punto(0, 100, 0), const Punto(0, 0, 0)), closeTo(0, 1e-9));
      expect(inclinacionDesdeVertical(const Punto(0, 100, 0), const Punto(100, 0, 0)), closeTo(45, 1e-9));
      expect(inclinacionDesdeHorizontal(const Punto(0, 0, 0), const Punto(-100, 100, 0)), closeTo(45, 1e-9));
    });

    test('redondeo igual al del servidor', () {
      expect(redondear(92.5), 93);
      expect(redondear(91.49), 91);
    });
  });

  group('filtro One Euro', () {
    test('entrada constante no cambia', () {
      final f = FiltroOneEuro(minCutoff: 1.2, beta: 0.04);
      for (var k = 0; k < 30; k++) {
        expect(f.filtrar(50, k / 30), closeTo(50, 1e-9));
      }
    });

    test('converge tras un escalón', () {
      final f = FiltroOneEuro(minCutoff: 1.2, beta: 0.04);
      for (var k = 0; k < 10; k++) {
        f.filtrar(0, k / 30);
      }
      var ultimo = 0.0;
      for (var k = 10; k < 70; k++) {
        ultimo = f.filtrar(100, k / 30);
      }
      expect(ultimo, closeTo(100, 0.5));
    });
  });

  group('detector de repeticiones', () {
    const senal = Senal(
      metrica: 'x',
      nombre: 'x',
      unidad: '°',
      direccion: 'descendente',
      inicio: 145,
      fin: 155,
      minimoRep: 125,
    );

    test('cuenta una válida y una incompleta', () {
      final d = DetectorRepeticiones(senal, 0.4);
      final valores = [170, 160, 140, 120, 100, 120, 150, 160, 170, 150, 140, 135, 140, 158, 170];
      final eventos = <EventoRepeticion>[];
      for (var i = 0; i < valores.length; i++) {
        final e = d.actualizar(i, i * 0.25, valores[i].toDouble());
        if (e != null) eventos.add(e);
      }
      expect(eventos.map((e) => e.valida), [true, false]);
      expect(eventos.first.idxPico, 4);
    });

    test('reporta la fase del movimiento', () {
      final d = DetectorRepeticiones(senal, 0);
      d.actualizar(0, 0, 170);
      expect(d.fase, Fase.reposo);
      d.actualizar(1, 0.1, 130);
      expect(d.fase, Fase.ida);
      d.actualizar(2, 0.2, 140);
      expect(d.fase, Fase.vuelta);
    });
  });

  group('especificación', () {
    test('copia de la app idéntica a compartido/ejercicios.json', () {
      final compartida = _leerJson('${_dirCompartido.path}/ejercicios.json');
      final app = _leerJson('assets/especificacion/ejercicios.json');
      expect(app, equals(compartida));
    });

    test('rechaza umbrales incoherentes', () {
      final crudo = _leerJson('assets/especificacion/ejercicios.json');
      ((crudo['ejercicios'] as List).first as Map)['senal']['minimo_rep'] = 150;
      expect(() => Especificacion.fromJson(crudo), throwsA(isA<EspecificacionInvalida>()));
    });
  });

  group('fixtures compartidos (mismo resultado que el servidor)', () {
    final archivos =
        Directory(
            '${_dirCompartido.path}/fixtures',
          ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('existen fixtures', () => expect(archivos, isNotEmpty));

    for (final archivo in archivos) {
      final fx = _leerJson(archivo.path);
      test(fx['nombre'] as String, () {
        final analizador = Analizador(spec, fx['ejercicio'] as String);
        for (final f in fx['fotogramas'] as List) {
          final m = f as Map<String, dynamic>;
          analizador.procesar(Fotograma.desdeListas(m['t_ms'] as int, m['puntos'] as List?, m['mundo'] as List?));
        }
        final r = analizador.resultado();
        final esperado = fx['esperado'] as Map<String, dynamic>;
        final codigos = [for (final h in r['hallazgos'] as List) (h as Map)['codigo'] as String]..sort();
        final codigosEsperados = (esperado['codigos'] as List).cast<String>().toList()..sort();

        expect((r['repeticiones'] as List).length, esperado['repeticiones']);
        expect((r['metricas'] as Map)['repeticiones_incompletas'], (esperado['incompletas'] as num).toDouble());
        expect(codigos, codigosEsperados);
        expect(r['puntaje'], esperado['puntaje']);
        expect((r['calidad'] as Map)['vista'], esperado['vista']);
        expect(() => jsonEncode(r), returnsNormally);
      });
    }
  });
}
