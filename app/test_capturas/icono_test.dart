// Dibuja el ícono de la app a 1024 px en tool/icono/. Luego
// tool/generar_iconos.py genera los tamaños de Android e iOS.
//
//   flutter test test_capturas/icono_test.dart --update-goldens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicina_app/core/widgets/logo.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1024, 1024)
      ..devicePixelRatio = 1;
  });

  Future<void> dibujar(WidgetTester t, String nombre, {bool conFondo = true, bool redondeado = true}) async {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: const ValueKey('icono'),
            child: LogoMovimiento(tamano: 1024, conFondo: conFondo, redondeado: redondeado),
          ),
        ),
      ),
    );
    await expectLater(find.byKey(const ValueKey('icono')), matchesGoldenFile('../tool/icono/$nombre.png'));
  }

  testWidgets('ícono con esquinas (Android heredado)', (t) => dibujar(t, 'icono_redondeado'));
  testWidgets('ícono cuadrado (iOS)', (t) => dibujar(t, 'icono_cuadrado', redondeado: false));
  testWidgets('capa frontal (Android adaptable)', (t) => dibujar(t, 'icono_frente', conFondo: false));
}
