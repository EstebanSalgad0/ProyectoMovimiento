import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'estado/proveedores.dart';
import 'modelos/sesion.dart';
import 'pantallas/analizando/analizando_pantalla.dart';
import 'pantallas/bienvenida/bienvenida_pantalla.dart';
import 'pantallas/cuenta/cuenta_pantalla.dart';
import 'pantallas/ejercicios/catalogo_pantalla.dart';
import 'pantallas/ejercicios/detalle_ejercicio_pantalla.dart';
import 'pantallas/inicio/inicio_pantalla.dart';
import 'pantallas/login/login_pantalla.dart';
import 'pantallas/preparacion/preparacion_pantalla.dart';
import 'pantallas/progreso/progreso_pantalla.dart';
import 'pantallas/registro/registro_pantalla.dart';
import 'pantallas/resultado/resultado_pantalla.dart';
import 'pantallas/shell/shell_pantalla.dart';
import 'pantallas/tiempo_real/tiempo_real_pantalla.dart';

class Rutas {
  static const bienvenida = '/bienvenida';
  static const login = '/login';
  static const registro = '/registro';
  static const inicio = '/inicio';
  static const ejercicios = '/ejercicios';
  static const progreso = '/progreso';
  static const cuenta = '/cuenta';
  static const preparacion = '/preparacion';
  static const analizando = '/analizando';
  static const tiempoReal = '/tiempo-real';

  static String ejercicio(String id) => '$ejercicios/$id';
  static String sesion(String id, {bool nueva = false}) => '/sesion/$id${nueva ? '?nueva=1' : ''}';
  static String preparacionDe(String? ejercicio) =>
      ejercicio == null ? preparacion : '$preparacion?ejercicio=$ejercicio';
  static String tiempoRealDe(String ejercicio) => '$tiempoReal?ejercicio=$ejercicio';
}

final _llaveRaiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');

final routerProvider = Provider<GoRouter>((ref) {
  // Notifica al router cuando cambia la sesión o se completa la bienvenida.
  final refresco = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresco.value++);
  ref.listen(ajustesProvider.select((a) => a.bienvenidaVista), (_, _) => refresco.value++);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    navigatorKey: _llaveRaiz,
    initialLocation: Rutas.inicio,
    refreshListenable: refresco,
    redirect: (context, state) {
      final bienvenida = ref.read(ajustesProvider).bienvenidaVista;
      final usuario = ref.read(authProvider);
      final ruta = state.matchedLocation;
      if (!bienvenida) return ruta == Rutas.bienvenida ? null : Rutas.bienvenida;
      final publica = ruta == Rutas.login || ruta == Rutas.registro;
      if (usuario == null) return publica ? null : Rutas.login;
      if (publica || ruta == Rutas.bienvenida) return Rutas.inicio;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Rutas.inicio),
      GoRoute(path: Rutas.bienvenida, builder: (_, _) => const BienvenidaPantalla()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPantalla()),
      GoRoute(path: Rutas.registro, builder: (_, _) => const RegistroPantalla()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellPantalla(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Rutas.inicio, builder: (_, _) => const InicioPantalla())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.ejercicios,
                builder: (_, _) => const CatalogoPantalla(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _llaveRaiz,
                    builder: (_, state) => DetalleEjercicioPantalla(ejercicioId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Rutas.progreso, builder: (_, _) => const ProgresoPantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Rutas.cuenta, builder: (_, _) => const CuentaPantalla())],
          ),
        ],
      ),
      GoRoute(
        path: Rutas.preparacion,
        builder: (_, state) => PreparacionPantalla(ejercicioInicial: state.uri.queryParameters['ejercicio']),
      ),
      GoRoute(
        path: Rutas.analizando,
        redirect: (_, state) => state.extra is SolicitudAnalisis ? null : Rutas.preparacion,
        builder: (_, state) => AnalizandoPantalla(solicitud: state.extra! as SolicitudAnalisis),
      ),
      GoRoute(
        path: Rutas.tiempoReal,
        builder: (_, state) => TiempoRealPantalla(ejercicioId: state.uri.queryParameters['ejercicio']),
      ),
      GoRoute(
        path: '/sesion/:id',
        builder: (_, state) => ResultadoPantalla(
          sesionId: state.pathParameters['id']!,
          sesionInicial: state.extra is Sesion ? state.extra! as Sesion : null,
          esNueva: state.uri.queryParameters['nueva'] == '1',
        ),
      ),
    ],
  );
});
