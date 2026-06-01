import 'package:flutter/material.dart';
import 'pantallas/login/login_pantalla.dart';
import 'pantallas/inicio/inicio_pantalla.dart';
import 'pantallas/preparacion/preparacion_pantalla.dart';
import 'pantallas/analizando/analizando_pantalla.dart';
import 'pantallas/resultado/resultado_pantalla.dart';
import 'pantallas/cuenta/cuenta_pantalla.dart';
import 'pantallas/tiempo_real/tiempo_real_pantalla.dart';

class Rutas {
  static const String login       = '/';
  // Acá levanto la ruta de inicio, que la estoy llamando en login con el OnPressed.
  // Clase rutas que tiene una constante estatica tipo string que llama a inicio.
  static const String inicio      = '/inicio';
  static const String preparacion = '/preparacion';
  static const String analizando  = '/analizando';
  static const String resultado   = '/resultado';
  static const String cuenta      = '/cuenta';
  static const String tiempoReal = '/tiempo_real';


  static Map<String, WidgetBuilder> get rutas => {
    login:       (_) => const LoginPantalla(),
    inicio:      (_) => const InicioPantalla(),
    preparacion: (_) => const PreparacionPantalla(),
    analizando:  (_) => const AnalizandoPantalla(),
    resultado:   (_) => const ResultadoPantalla(),
    cuenta:      (_) => const CuentaPantalla(),
    tiempoReal: (_) => const TiempoRealPantalla(),

  };
}
