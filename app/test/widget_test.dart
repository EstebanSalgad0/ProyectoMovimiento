// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:medicina_app/main.dart';

void main() {
  testWidgets('muestra la pantalla inicial de login', (WidgetTester tester) async {
    await tester.pumpWidget(const MiApp());
    await tester.pumpAndSettle();

    expect(find.text('Medicina'), findsOneWidget);
    expect(find.text('Análisis de movimiento'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
