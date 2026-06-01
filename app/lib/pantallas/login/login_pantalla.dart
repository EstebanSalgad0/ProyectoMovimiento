import 'package:flutter/material.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/boton_principal.dart';
import '../../rutas.dart';
import '../../servicios/auth_servicios.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _usuarioCtrl    = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _verContrasena   = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColores.azulPrincipal,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.monitor_heart_outlined,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),

                Text('Medicina', style: AppTipo.appName()
                    .copyWith(color: AppColores.textoPrincipal)),
                const SizedBox(height: 4),
                Text('Análisis de movimiento', style: AppTipo.caption()
                    .copyWith(color: AppColores.textoSecundario)),
                const SizedBox(height: 40),

                // Card formulario
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColores.fondoCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColores.bordeDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Campo usuario
                      Text('USUARIO', style: AppTipo.captionCaps()
                          .copyWith(color: AppColores.textoSecundario)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 46,
                        child: TextField(
                          controller: _usuarioCtrl,
                          style: AppTipo.body().copyWith(color: AppColores.textoPrincipal),
                          decoration: const InputDecoration(
                            hintText: 'USUARIO.LOGIN',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo contraseña
                      Text('CONTRASEÑA', style: AppTipo.captionCaps()
                          .copyWith(color: AppColores.textoSecundario)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 46,
                        child: TextField(
                          controller: _contrasenaCtrl,
                          obscureText: !_verContrasena,
                          style: AppTipo.body().copyWith(color: AppColores.textoPrincipal),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _verContrasena ? Icons.visibility_off : Icons.visibility,
                                color: AppColores.textoSecundario, size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _verContrasena = !_verContrasena),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón iniciar sesión. Luego lo tengo que cambiar con las llamadas a servicio xd
                      BotonPrincipal(
                        texto: 'Iniciar sesión',
                        onPressed: () {
                          final ok = AuthServicio.login(
                            _usuarioCtrl.text,
                            _contrasenaCtrl.text,
                          );
                          if (ok) {
                            Navigator.pushReplacementNamed(context, Rutas.inicio);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Usuario o contraseña incorrectos')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // ¿Olvidaste tu contraseña?
                      Center(
                        child: GestureDetector(
                          onTap: () {},
                          child: Text('¿Olvidaste tu contraseña?',
                              style: AppTipo.caption()
                                  .copyWith(color: AppColores.azulPrincipal)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}