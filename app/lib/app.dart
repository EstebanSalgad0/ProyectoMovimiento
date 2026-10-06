import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/tema/tema.dart';
import 'estado/proveedores.dart';
import 'rutas.dart';

class MiApp extends ConsumerWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(ajustesProvider.select((a) => a.tema));
    return MaterialApp.router(
      title: AppConfig.nombreCompleto,
      debugShowCheckedModeBanner: false,
      theme: AppTema.claro,
      darkTheme: AppTema.oscuro,
      themeMode: tema,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es', 'CL'),
      supportedLocales: const [Locale('es', 'CL'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
