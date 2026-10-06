import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/core/widgets/item_sesion.dart';
import 'package:medicina_app/estado/proveedores.dart';
import 'package:medicina_app/modelos/esqueleto.dart';
import 'package:medicina_app/modelos/sesion.dart';
import 'package:medicina_app/modelos/usuario.dart';
import 'package:medicina_app/rutas.dart';
import 'package:medicina_app/servicios/adjuntos_servicio.dart';

import '../ayudantes.dart';

/// Lista vertical principal de la pantalla visible.
Finder get _lista => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

const _sesionIniciada = {'ajustes.bienvenida_vista': true, 'auth.sesion': 'usuario.prueba'};

Sesion _sesion({String id = 's1', String fixture = 'sentadilla_lateral_poco_profunda', bool esqueleto = false}) {
  final r = resultadoDeFixture(cargarEspecificacion(), fixture);
  return Sesion(
    id: id,
    usuario: 'usuario.prueba',
    fecha: DateTime.now().subtract(const Duration(hours: 2)),
    origen: OrigenSesion.tiempoReal,
    resultado: r,
    tieneEsqueleto: esqueleto,
  );
}

void main() {
  testWidgets('Entrenar → Rutinas → detalle de una rutina recomendada', (t) async {
    await montarApp(t, preferencias: _sesionIniciada);
    await t.tap(find.text('Entrenar').last);
    await avanzar(t);
    await t.tap(find.text('Rutinas'));
    await avanzar(t);
    expect(find.text('Crear rutina'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Activación diaria'), 300, scrollable: _lista);
    await t.tap(find.text('Activación diaria'));
    await avanzar(t, 12);
    expect(find.text('Rutina recomendada'), findsOneWidget);
    expect(find.text('Comenzar rutina'), findsOneWidget);
    expect(find.textContaining('2 × 8 reps.'), findsWidgets);
  });

  testWidgets('crear una rutina propia', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    c.read(routerProvider).push(Rutas.rutinaNueva);
    await avanzar(t);
    expect(find.text('Nueva rutina'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Nombre'), 'Piernas del lunes');
    await t.tap(find.text('Agregar ejercicio'));
    await avanzar(t);
    await t.tap(find.text('Zancada'));
    await avanzar(t);
    expect(find.text('Zancada'), findsOneWidget);
    await t.tap(find.byTooltip('Más Series'));
    await avanzar(t, 2);
    await t.scrollUntilVisible(find.text('Guardar rutina'), 300, scrollable: _lista);
    await t.tap(find.text('Guardar rutina'));
    await avanzar(t, 12);

    final rutinas = c.read(rutinasPropiasProvider);
    expect(rutinas, hasLength(1));
    expect(rutinas.first.items.single.series, 3);
    expect(find.text('Mi rutina'), findsOneWidget);
    expect(find.text('Piernas del lunes'), findsOneWidget);
  });

  testWidgets('Entrenar → Evaluaciones → instrucciones de la prueba de 30 s', (t) async {
    await montarApp(t, preferencias: _sesionIniciada);
    await t.tap(find.text('Entrenar').last);
    await avanzar(t);
    await t.tap(find.text('Evaluaciones'));
    await avanzar(t);
    expect(find.text('Sentarse y pararse 30 s'), findsOneWidget);
    expect(find.text('Goniómetro'), findsOneWidget);
    await t.tap(find.text('Hacer la prueba'));
    await avanzar(t, 12);
    expect(find.text('Cómo se hace'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Comenzar prueba'), 400, scrollable: _lista);
    expect(find.text('Comenzar prueba'), findsOneWidget);
  });

  testWidgets('editar el perfil guarda los datos', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    c.read(routerProvider).push(Rutas.perfil);
    await avanzar(t);
    await t.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'Masculino'), 300, scrollable: _lista);
    await t.tap(find.widgetWithText(ChoiceChip, 'Masculino'));
    await t.scrollUntilVisible(find.text('Equilibrio y autonomía'), 300, scrollable: _lista);
    await t.tap(find.text('Equilibrio y autonomía'));
    await t.scrollUntilVisible(find.text('Guardar cambios'), 400, scrollable: _lista);
    await t.tap(find.text('Guardar cambios'));
    await avanzar(t);
    final u = c.read(authProvider)!;
    expect(u.sexo, Sexo.masculino);
    expect(u.objetivo, Objetivo.prevencionCaidas);
    expect(find.text('Perfil actualizado'), findsOneWidget);
  });

  testWidgets('registrar cómo se sintió después de una sesión', (t) async {
    final s = _sesion();
    final c = await montarApp(t, preferencias: _sesionIniciada, sesiones: [s]);
    c.read(routerProvider).push(Rutas.sesion(s.id), extra: s);
    await avanzar(t, 12);
    await t.scrollUntilVisible(find.text('¿Cómo te sentiste?'), 300, scrollable: _lista);
    await t.tap(find.text('¿Cómo te sentiste?'));
    await avanzar(t);
    expect(find.text('Esfuerzo'), findsOneWidget);
    await t.tap(find.text('Guardar'));
    await avanzar(t);
    expect(c.read(historialProvider).value!.single.sensaciones?.esfuerzo, 5);
    expect(find.text('Cómo te sentiste'), findsOneWidget);
  });

  testWidgets('revisar el movimiento reproduce el esqueleto grabado', (t) async {
    final s = _sesion(esqueleto: true);
    final grabador = GrabadorEsqueleto();
    for (var i = 0; i < 30; i++) {
      grabador.agregar(i * 100, {for (final j in indicesEsqueleto) j: (Offset(0.3 + i / 100, 0.5), 0.9)});
    }
    final adjuntos = AdjuntosMemoria();
    await adjuntos.guardarEsqueleto(s.id, grabador.resultado()!);
    final c = await montarApp(t, preferencias: _sesionIniciada, sesiones: [s], adjuntos: adjuntos);
    c.read(routerProvider).push(Rutas.revision(s.id));
    await avanzar(t);
    expect(find.text('Revisar movimiento'), findsOneWidget);
    await t.tap(find.byTooltip('Reproducir'));
    await avanzar(t, 4);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await t.tap(find.byTooltip('Pausar'));
    await avanzar(t, 2);
    expect(find.byTooltip('Reproducir'), findsOneWidget);
  });

  testWidgets('borrar una sesión desde Progreso y deshacer', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada, sesiones: [_sesion()]);
    await t.tap(find.text('Progreso').last);
    await avanzar(t);
    await t.scrollUntilVisible(find.byType(ItemSesion), 300, scrollable: _lista);
    await t.drag(_lista, const Offset(0, -300));
    await avanzar(t, 2);
    await t.drag(find.byType(ItemSesion), const Offset(-500, 0));
    await avanzar(t);
    expect(find.text('Sesión eliminada'), findsOneWidget);
    expect(c.read(historialProvider).value, isEmpty);
    await t.tap(find.text('Deshacer'));
    await avanzar(t);
    expect(c.read(historialProvider).value, hasLength(1));
  });

  testWidgets('logros e inicio con meta semanal y recomendaciones', (t) async {
    final c = await montarApp(
      t,
      preferencias: _sesionIniciada,
      sesiones: [
        _sesion(),
        _sesion(id: 's2'),
      ],
    );
    expect(find.text('META SEMANAL'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Para ti'), 300, scrollable: _lista);
    expect(find.textContaining('Trabaja en'), findsOneWidget);

    c.read(routerProvider).push(Rutas.logros);
    await avanzar(t);
    expect(find.text('Primer paso'), findsOneWidget);
    expect(find.text('Desbloqueado'), findsWidgets);
  });

  testWidgets('se celebra un logro nuevo', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada);
    final r = resultadoDeFixture(cargarEspecificacion(), 'sentadilla_lateral_correcta');
    await c.read(historialProvider.notifier).registrar(r, OrigenSesion.tiempoReal);
    await avanzar(t);
    expect(find.text('¡Logro desbloqueado!'), findsOneWidget);
  });

  testWidgets('cambiar la contraseña desde Cuenta', (t) async {
    await montarApp(t, preferencias: _sesionIniciada);
    await t.tap(find.text('Cuenta').last);
    await avanzar(t);
    await t.scrollUntilVisible(find.text('Cambiar contraseña'), 300, scrollable: _lista);
    await t.tap(find.text('Cambiar contraseña'));
    await avanzar(t);
    await t.enterText(find.widgetWithText(TextField, 'Contraseña actual'), '1234');
    await t.enterText(find.widgetWithText(TextField, 'Nueva contraseña'), 'nueva123');
    await t.enterText(find.widgetWithText(TextField, 'Repite la nueva contraseña'), 'otra123');
    await t.tap(find.text('Guardar'));
    await avanzar(t);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Repite la nueva contraseña'), 'nueva123');
    await t.tap(find.text('Guardar'));
    await avanzar(t);
    expect(find.text('Contraseña actualizada'), findsOneWidget);
  });

  testWidgets('eliminar la cuenta pide la contraseña y vuelve al inicio de sesión', (t) async {
    final c = await montarApp(t, preferencias: _sesionIniciada, sesiones: [_sesion()]);
    c.read(routerProvider).push(Rutas.datos);
    await avanzar(t);
    expect(find.text('Reporte en PDF'), findsOneWidget);
    expect(find.text('Exportar mis datos'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Eliminar cuenta'), 300, scrollable: _lista);
    await t.tap(find.text('Eliminar cuenta'));
    await avanzar(t);
    await t.enterText(find.widgetWithText(TextField, 'Contraseña'), 'mala');
    await t.tap(find.text('Eliminar'));
    await avanzar(t);
    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Contraseña'), '1234');
    await t.tap(find.text('Eliminar'));
    await avanzar(t, 12);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(c.read(authProvider), isNull);
  });
}
