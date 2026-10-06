import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/core/utils/formato.dart';
import 'package:medicina_app/estado/proveedores.dart';
import 'package:medicina_app/modelos/resultado_analisis.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';
import 'package:medicina_app/pantallas/tiempo_real/controlador_tiempo_real.dart' show fraseCorta;

import '../ayudantes.dart';

void main() {
  group('Sesion', () {
    test('lee el historial guardado por la app v1', () {
      final v1 = {
        'usuario': 'usuario.prueba',
        'ejercicio': 'sentadilla',
        'puntaje': 67,
        'feedback': ['Cadera: pelvis estable.', 'Rodillas: baje un poco mas para activar piernas.'],
        'metricas': {'rodilla_izq': 120.5},
        'fecha': '2026-09-01T10:00:00.000',
        'videoNombre': 'video.mp4',
      };
      final s = Sesion.fromJson(v1);
      expect(s.puntaje, 67);
      expect(s.estado, EstadoAnalisis.advertencia);
      expect(s.resultado.esV2, isFalse);
      expect(s.resultado.hallazgos.single.titulo, 'Rodillas');
      expect(s.resultado.aciertos.single.mensaje, 'Cadera: pelvis estable.');
    });

    test('ida y vuelta JSON sin pérdida', () {
      final spec = cargarEspecificacion();
      final r = resultadoDeFixture(spec, 'curl_frontal_correcto');
      final s = Sesion.nueva(usuario: 'ana', origen: OrigenSesion.tiempoReal, resultado: r);
      final copia = Sesion.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(copia.id, s.id);
      expect(copia.origen, OrigenSesion.tiempoReal);
      expect(copia.resultado.repeticiones.length, 3);
      expect(copia.resultado.serie?.tieneDatos, isTrue);
      expect(copia.resultado.calidad?.vista, 'frontal');
    });
  });

  test('ResultadoAnalisis interpreta la respuesta v2', () {
    final r = resultadoDeFixture(cargarEspecificacion(), 'sentadilla_rep_incompleta');
    expect(r.esV2, isTrue);
    expect(r.numeroRepeticiones, 2);
    final h = r.hallazgos.single;
    expect(h.codigo, 'REPETICIONES_INCOMPLETAS');
    expect(h.severidad, Severidad.leve);
  });

  test('Hallazgo.frecuencia', () {
    const h = Hallazgo(
      codigo: 'X',
      severidad: Severidad.moderada,
      zona: 'rodillas',
      titulo: 't',
      mensaje: 'm',
      repeticiones: [1, 3],
      totalEvaluadas: 5,
    );
    expect(h.frecuencia, 'En 2 de 5 repeticiones');
  });

  test('Usuario.iniciales', () {
    final u = Usuario(
      usuario: 'ana',
      nombre: 'Ana María Pérez',
      email: '',
      rol: RolUsuario.paciente,
      creadoEn: DateTime(2026),
    );
    expect(u.iniciales, 'AM');
    expect(u.primerNombre, 'Ana');
  });

  group('Resumen', () {
    final spec = cargarEspecificacion();
    final r = resultadoDeFixture(spec, 'sentadilla_lateral_correcta');
    final hoy = DateTime(2026, 10, 6, 18);

    test('racha y sesiones de la semana', () {
      final sesiones = [
        sesionDePrueba(r, fecha: hoy, id: 'a'),
        sesionDePrueba(r, fecha: hoy.subtract(const Duration(days: 1)), id: 'b'),
        sesionDePrueba(r, fecha: hoy.subtract(const Duration(days: 2)), id: 'c'),
        sesionDePrueba(r, fecha: hoy.subtract(const Duration(days: 5)), id: 'd'),
      ];
      final res = Resumen.desde(sesiones, hoy: hoy);
      expect(res.racha, 3);
      expect(res.sesionesSemana, 4);
      expect(res.sesionesPorDia.last, 1);
      expect(res.promedio, 100);
      expect(res.repeticiones, 12);
    });

    test('sin sesiones', () {
      final res = Resumen.desde(const [], hoy: hoy);
      expect(res.racha, 0);
      expect(res.promedio, isNull);
    });
  });

  group('Formato', () {
    final ahora = DateTime(2026, 10, 6, 18, 30);
    test('fechas relativas', () {
      expect(Formato.fechaRelativa(DateTime(2026, 10, 6, 9, 5), ahora: ahora), 'Hoy, 09:05');
      expect(Formato.fechaRelativa(DateTime(2026, 10, 5, 20, 0), ahora: ahora), 'Ayer, 20:00');
      expect(Formato.fechaRelativa(DateTime(2026, 9, 28, 7, 0), ahora: ahora), 'lun 28 sep, 07:00');
    });
    test('números y duraciones', () {
      expect(Formato.numero(1.25), '1,3');
      expect(Formato.segundos(2.5), '2,5 s');
      expect(Formato.segundos(75), '1:15 min');
    });
  });

  test('fraseCorta toma la primera indicación', () {
    expect(fraseCorta('Baja un poco más: intenta llegar a 90°.'), 'Baja un poco más');
    expect(fraseCorta('Sin separadores'), 'Sin separadores');
  });
}
