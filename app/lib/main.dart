import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'estado/proveedores.dart';
import 'motor/especificacion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencias = await SharedPreferences.getInstance();
  final especificacion = Especificacion.fromJson(
    jsonDecode(await rootBundle.loadString('assets/especificacion/ejercicios.json')) as Map<String, dynamic>,
  );

  runApp(
    ProviderScope(
      overrides: [
        preferenciasProvider.overrideWithValue(preferencias),
        especificacionProvider.overrideWithValue(especificacion),
      ],
      child: const MiApp(),
    ),
  );
}
