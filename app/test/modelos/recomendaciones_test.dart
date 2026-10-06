import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/modelos/evaluacion.dart';
import 'package:medicina_app/modelos/recomendaciones.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';

import '../ayudantes.dart';

void main() {
  final hoy = DateTime(2025, 10, 8, 18); // miércoles
  final spec = cargarEspecificacion();
  final pocoProfunda = resultadoDeFixture(spec, 'sentadilla_lateral_poco_profunda');

  Usuario usuario({DateTime? nacimiento, Objetivo? objetivo, int meta = 3}) => Usuario(
    usuario: 'u',
    nombre: 'U',
    email: '',
    rol: RolUsuario.paciente,
    creadoEn: DateTime(2025),
    fechaNacimiento: nacimiento,
    objetivo: objetivo,
    metaSemanal: meta,
  );

  Sesion sesion(DateTime f, String id, {Sensaciones? sensaciones}) => Sesion(
    id: id,
    usuario: 'u',
    fecha: f,
    origen: OrigenSesion.tiempoReal,
    resultado: pocoProfunda,
    sensaciones: sensaciones,
  );

  test('el dolor intenso reciente va primero', () {
    final r = generarRecomendaciones(
      usuario: usuario(),
      sesiones: [
        sesion(
          DateTime(2025, 10, 8, 9),
          'a',
          sensaciones: const Sensaciones(esfuerzo: 6, dolor: 8, zonaDolor: 'rodillas'),
        ),
      ],
      evaluaciones: const [],
      hoy: hoy,
    );
    expect(r.first.tipo, TipoRecomendacion.dolorIntenso);
    expect(r.first.titulo, contains('rodillas'));
  });

  test('sugiere trabajar la corrección más repetida', () {
    final r = generarRecomendaciones(
      usuario: usuario(),
      sesiones: [sesion(DateTime(2025, 10, 8, 9), 'a'), sesion(DateTime(2025, 10, 6, 9), 'b')],
      evaluaciones: const [],
      nombreEjercicio: (id) => spec.buscar(id)!.nombre,
      hoy: hoy,
    );
    final c = r.firstWhere((x) => x.tipo == TipoRecomendacion.correccion);
    expect(c.ejercicioId, 'sentadilla');
    expect(c.detalle, contains('2 sesiones recientes de sentadilla'));
  });

  test('propone la prueba de 30 s a mayores de 60 sin una reciente', () {
    final mayor = usuario(nacimiento: DateTime(1955, 3, 1));
    final r = generarRecomendaciones(usuario: mayor, sesiones: const [], evaluaciones: const [], hoy: hoy);
    expect(r.map((x) => x.tipo), contains(TipoRecomendacion.evaluacion));

    final reciente = EvaluacionFuncional(
      id: 'v',
      usuario: 'u',
      fecha: DateTime(2025, 10, 1),
      tipo: TipoEvaluacion.sentarsePararse30s,
      repeticiones: 12,
    );
    final r2 = generarRecomendaciones(usuario: mayor, sesiones: const [], evaluaciones: [reciente], hoy: hoy);
    expect(r2.map((x) => x.tipo), isNot(contains(TipoRecomendacion.evaluacion)));
  });

  test('meta semanal: cuánto falta o felicitación', () {
    final r = generarRecomendaciones(
      usuario: usuario(meta: 3),
      sesiones: [sesion(DateTime(2025, 10, 6, 9), 'a')],
      evaluaciones: const [],
      hoy: hoy,
    );
    expect(r.map((x) => x.titulo), contains('Te faltan 2 días para tu meta'));

    final cumplida = generarRecomendaciones(
      usuario: usuario(meta: 2),
      sesiones: [sesion(DateTime(2025, 10, 6, 9), 'a'), sesion(DateTime(2025, 10, 7, 9), 'b')],
      evaluaciones: const [],
      hoy: hoy,
    );
    expect(cumplida.map((x) => x.tipo), contains(TipoRecomendacion.metaCumplida));
  });

  test('como máximo tres sugerencias', () {
    final r = generarRecomendaciones(
      usuario: usuario(nacimiento: DateTime(1950), meta: 5),
      sesiones: [
        sesion(DateTime(2025, 10, 8, 9), 'a', sensaciones: const Sensaciones(esfuerzo: 5, dolor: 5)),
        sesion(DateTime(2025, 10, 7, 9), 'b'),
      ],
      evaluaciones: const [],
      hoy: hoy,
    );
    expect(r, hasLength(3));
    expect(r.first.tipo, TipoRecomendacion.dolorModerado);
  });
}
