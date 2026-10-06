import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/core/widgets/item_sesion.dart';
import 'package:medicina_app/rutas.dart';

import '../ayudantes.dart';

/// Lista vertical principal de la pantalla visible (hay listas horizontales anidadas).
Finder get _listaPrincipal =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

const _sesionIniciada = {'ajustes.bienvenida_vista': true, 'auth.sesion': 'usuario.prueba'};

void main() {
  testWidgets('primera vez: bienvenida → saltar → login', (tester) async {
    await montarApp(tester);
    expect(find.textContaining('analizado con IA'), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await avanzar(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('login con credenciales de demo lleva al inicio', (tester) async {
    await montarApp(tester, preferencias: {'ajustes.bienvenida_vista': true});
    await tester.tap(find.text('Usar'));
    await avanzar(tester, 2);
    await tester.tap(find.text('Ingresar'));
    await avanzar(tester);

    expect(find.text('Usuario'), findsOneWidget); // primer nombre de "Usuario Prueba"
    await tester.scrollUntilVisible(find.text('Aún no tienes sesiones'), 300, scrollable: _listaPrincipal);
    expect(find.text('Aún no tienes sesiones'), findsOneWidget);
  });

  testWidgets('login con contraseña incorrecta muestra error', (tester) async {
    await montarApp(tester, preferencias: {'ajustes.bienvenida_vista': true});
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), 'usuario.prueba');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'mala');
    await tester.tap(find.text('Ingresar'));
    await avanzar(tester);
    expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('registro crea la cuenta e inicia sesión', (tester) async {
    await montarApp(tester, preferencias: {'ajustes.bienvenida_vista': true});
    await tester.tap(find.text('Crear cuenta'));
    await avanzar(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana Pérez');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de usuario'), 'ana.perez');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@correo.cl');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'secreta1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'secreta1');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await avanzar(tester);

    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('inicio muestra la actividad reciente y abre el resultado', (tester) async {
    final spec = cargarEspecificacion();
    final r = resultadoDeFixture(spec, 'sentadilla_lateral_poco_profunda');
    final sesion = sesionDePrueba(r, fecha: DateTime.now().subtract(const Duration(hours: 1)));
    await montarApp(tester, preferencias: _sesionIniciada, sesiones: [sesion]);

    await tester.scrollUntilVisible(find.text('Actividad reciente'), 300, scrollable: _listaPrincipal);
    await tester.drag(_listaPrincipal, const Offset(0, -250));
    await avanzar(tester, 2);
    expect(find.byType(ItemSesion), findsOneWidget);
    expect(find.descendant(of: find.byType(ItemSesion), matching: find.text('70')), findsOneWidget);

    await tester.tap(find.byType(ItemSesion));
    await avanzar(tester, 12);
    expect(find.text('Detalle de sesión'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tronco muy inclinado'), 300, scrollable: _listaPrincipal);
    expect(find.text('Profundidad insuficiente'), findsOneWidget);
    expect(find.text('Tronco muy inclinado'), findsOneWidget);
  });

  testWidgets('catálogo lista los 6 ejercicios y abre el detalle', (tester) async {
    await montarApp(tester, preferencias: _sesionIniciada);
    await tester.tap(find.text('Ejercicios').last);
    await avanzar(tester);

    expect(find.text('6 movimientos con análisis de técnica'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'press');
    await avanzar(tester, 2);
    expect(find.text('Press de hombros sentado'), findsOneWidget);
    expect(find.text('Sentadilla'), findsNothing);

    await tester.tap(find.text('Press de hombros sentado'));
    await avanzar(tester, 12);
    await tester.scrollUntilVisible(find.text('Qué detecta la IA'), 300, scrollable: _listaPrincipal);
    expect(find.text('Extensión incompleta arriba'), findsOneWidget);
    expect(find.text('Tiempo real'), findsOneWidget);
  });

  testWidgets('resultado nuevo de una sesión en vivo', (tester) async {
    final spec = cargarEspecificacion();
    final r = resultadoDeFixture(spec, 'sentadilla_frontal_valgo');
    final sesion = sesionDePrueba(r, fecha: DateTime.now());
    final contenedor = await montarApp(tester, preferencias: _sesionIniciada, sesiones: [sesion]);

    contenedor.read(routerProvider).push(Rutas.sesion(sesion.id, nueva: true), extra: sesion);
    await avanzar(tester, 14);
    expect(find.text('Tu resultado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rodillas hacia adentro'), 300, scrollable: _listaPrincipal);
    expect(find.text('Rodillas hacia adentro'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sugerencias'), 400, scrollable: _listaPrincipal);
    expect(find.textContaining('Grábate de costado'), findsOneWidget);
  });

  testWidgets('cuenta permite cambiar tema y cerrar sesión', (tester) async {
    await montarApp(tester, preferencias: _sesionIniciada);
    await tester.tap(find.text('Cuenta').last);
    await avanzar(tester);
    expect(find.text('Usuario Prueba'), findsOneWidget);

    await tester.tap(find.text('Oscuro'));
    await avanzar(tester, 4);
    expect(Theme.of(tester.element(find.text('Usuario Prueba'))).brightness, Brightness.dark);

    // Al final de la lista, para que la barra de navegación no tape el botón.
    await tester.drag(_listaPrincipal, const Offset(0, -3000));
    await avanzar(tester, 3);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await avanzar(tester, 4);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await avanzar(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
