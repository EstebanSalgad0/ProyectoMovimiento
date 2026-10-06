import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'estado/proveedores.dart';
import 'modelos/evaluacion.dart';
import 'modelos/sesion.dart';
import 'pantallas/analizando/analizando_pantalla.dart';
import 'pantallas/bienvenida/bienvenida_pantalla.dart';
import 'pantallas/cuenta/cuenta_pantalla.dart';
import 'pantallas/cuenta/datos_pantalla.dart';
import 'pantallas/cuenta/logros_pantalla.dart';
import 'pantallas/cuenta/perfil_pantalla.dart';
import 'pantallas/ejercicios/detalle_ejercicio_pantalla.dart';
import 'pantallas/entrenar/entrenar_pantalla.dart';
import 'pantallas/evaluaciones/goniometro_pantalla.dart';
import 'pantallas/evaluaciones/prueba_sts_pantalla.dart';
import 'pantallas/inicio/inicio_pantalla.dart';
import 'pantallas/login/login_pantalla.dart';
import 'pantallas/preparacion/preparacion_pantalla.dart';
import 'pantallas/progreso/progreso_pantalla.dart';
import 'pantallas/registro/registro_pantalla.dart';
import 'pantallas/resultado/resultado_pantalla.dart';
import 'pantallas/revision/revision_pantalla.dart';
import 'pantallas/rutinas/detalle_rutina_pantalla.dart';
import 'pantallas/rutinas/editor_rutina_pantalla.dart';
import 'pantallas/rutinas/resumen_rutina_pantalla.dart';
import 'pantallas/rutinas/sesion_guiada_pantalla.dart';
import 'pantallas/shell/shell_pantalla.dart';
import 'pantallas/tiempo_real/tiempo_real_pantalla.dart';

class Rutas {
  static const bienvenida = '/bienvenida';
  static const login = '/login';
  static const registro = '/registro';
  static const configuracion = '/configuracion';

  // Pestañas
  static const inicio = '/inicio';
  static const entrenar = '/entrenar';
  static const progreso = '/progreso';
  static const cuenta = '/cuenta';

  static const preparacion = '/preparacion';
  static const analizando = '/analizando';
  static const tiempoReal = '/tiempo-real';
  static const perfil = '/perfil';
  static const logros = '/logros';
  static const datos = '/datos';
  static const rutinaNueva = '/rutinas/nueva';
  static const pruebaSts = '/evaluaciones/sts30';
  static const goniometro = '/evaluaciones/goniometro';

  /// Pestaña de Entrenar: ejercicios, rutinas o evaluaciones.
  static String entrenarEn(String seccion) => '$entrenar?seccion=$seccion';
  static String ejercicio(String id) => '/ejercicios/$id';
  static String rutina(String id) => '/rutinas/$id';
  static String editarRutina(String id) => '/rutinas/$id/editar';
  static String sesionGuiada(String id) => '/rutinas/$id/guiada';
  static String ejecucion(String id) => '/ejecucion/$id';
  static String sesion(String id, {bool nueva = false}) => '/sesion/$id${nueva ? '?nueva=1' : ''}';
  static String revision(String id) => '/sesion/$id/revision';
  static String goniometroDe(Articulacion a) => '$goniometro?articulacion=${a.name}';
  static String preparacionDe(String? ejercicio) =>
      ejercicio == null ? preparacion : '$preparacion?ejercicio=$ejercicio';
  static String tiempoRealDe(String ejercicio) => '$tiempoReal?ejercicio=$ejercicio';
}

final _llaveRaiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');

final routerProvider = Provider<GoRouter>((ref) {
  // Notifica al router cuando cambia la sesión, la bienvenida o la configuración inicial.
  final refresco = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresco.value++);
  ref.listen(ajustesProvider.select((a) => a.bienvenidaVista), (_, _) => refresco.value++);
  ref.listen(configuracionInicialProvider, (_, _) => refresco.value++);
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
      final pendiente = ref.read(configuracionInicialProvider);
      if (pendiente) return ruta == Rutas.configuracion ? null : Rutas.configuracion;
      if (publica || ruta == Rutas.bienvenida || ruta == Rutas.configuracion) return Rutas.inicio;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Rutas.inicio),
      GoRoute(path: Rutas.bienvenida, builder: (_, _) => const BienvenidaPantalla()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPantalla()),
      GoRoute(path: Rutas.registro, builder: (_, _) => const RegistroPantalla()),
      GoRoute(path: Rutas.configuracion, builder: (_, _) => const PerfilPantalla(configuracionInicial: true)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellPantalla(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Rutas.inicio, builder: (_, _) => const InicioPantalla())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.entrenar,
                builder: (_, state) => EntrenarPantalla(seccion: state.uri.queryParameters['seccion']),
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
        path: '/ejercicios/:id',
        builder: (_, state) => DetalleEjercicioPantalla(ejercicioId: state.pathParameters['id']!),
      ),
      GoRoute(path: Rutas.rutinaNueva, builder: (_, _) => const EditorRutinaPantalla()),
      GoRoute(
        path: '/rutinas/:id',
        builder: (_, state) => DetalleRutinaPantalla(rutinaId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'editar',
            builder: (_, state) => EditorRutinaPantalla(rutinaId: state.pathParameters['id']),
          ),
          GoRoute(
            path: 'guiada',
            builder: (_, state) => SesionGuiadaPantalla(rutinaId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/ejecucion/:id',
        builder: (_, state) => ResumenRutinaPantalla(ejecucionId: state.pathParameters['id']!),
      ),
      GoRoute(path: Rutas.pruebaSts, builder: (_, _) => const PruebaStsPantalla()),
      GoRoute(
        path: Rutas.goniometro,
        builder: (_, state) {
          final a = state.uri.queryParameters['articulacion'];
          return GoniometroPantalla(articulacionInicial: a == null ? null : Articulacion.desde(a));
        },
      ),
      GoRoute(path: Rutas.perfil, builder: (_, _) => const PerfilPantalla()),
      GoRoute(path: Rutas.logros, builder: (_, _) => const LogrosPantalla()),
      GoRoute(path: Rutas.datos, builder: (_, _) => const DatosPantalla()),
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
        routes: [
          GoRoute(
            path: 'revision',
            builder: (_, state) => RevisionPantalla(sesionId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
