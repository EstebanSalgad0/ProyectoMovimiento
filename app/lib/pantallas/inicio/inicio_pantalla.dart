import 'package:flutter/material.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/encabezado.dart';
import '../../rutas.dart';
import '../../core/widgets/item_sesion.dart';
import '../../servicios/auth_servicios.dart';
import '../../modelos/sesion.dart';
import '../../servicios/historial_servicio.dart';



class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  late Future<List<Sesion>> _historialFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _historialFuture = _cargarHistorial();
    });
  }

  Future<List<Sesion>> _cargarHistorial() async {
    final usuario = AuthServicio.usuarioActual;
    if (usuario.isEmpty) return [];
    return HistorialServicio.obtenerHistorial(usuario);
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechaSesion = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = hoy.difference(fechaSesion).inDays;

    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    if (diferencia == 0) return 'Hoy, $hora';
    if (diferencia == 1) return 'Ayer, $hora';

    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[(fecha.weekday - 1) % 7]}, $hora';
  }

  IconData _iconoParaEjercicio(String ejercicio) {
    switch (ejercicio) {
      case 'sentadilla':
        return Icons.accessibility_new;
      case 'zancada':
        return Icons.directions_walk;
      case 'curl_biceps_sentado':
        return Icons.fitness_center;
      case 'press_hombros_sentado':
        return Icons.sports_gymnastics;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthServicio.usuarioActual.isNotEmpty
        ? AuthServicio.usuarioActual
        : 'Invitado';

    return Scaffold(
      backgroundColor: AppColores.fondoApp,
      appBar: Encabezado(
        titulo: usuario,
        saludo: '¡Bienvenido de vuelta!',
        nombreUsuario: usuario,
        onAvatarTap: () => Navigator.pushNamed(context, Rutas.cuenta),
      ),
      body: FutureBuilder<List<Sesion>>(
        future: _historialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final historial = snapshot.data ?? const <Sesion>[];
          final recientes = historial.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, Rutas.preparacion),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColores.fondoCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColores.bordeDefault),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColores.azulLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: AppColores.azulPrincipal, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Iniciar análisis', style: AppTipo.cardTitle()
                              .copyWith(color: AppColores.textoPrincipal)),
                          const SizedBox(height: 2),
                          Text('Comenzar evaluación', style: AppTipo.caption()
                              .copyWith(color: AppColores.textoSecundario)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColores.bordeDefault,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColores.bordeDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${historial.length}', style: AppTipo.statNumber()
                          .copyWith(color: AppColores.textoPrincipal)),
                      Text('Sesiones totales', style: AppTipo.caption()
                          .copyWith(color: AppColores.textoSecundario)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Recientes', style: AppTipo.sectionTitle()
                    .copyWith(color: AppColores.textoSecundario)),
              ),
              const SizedBox(height: 16),
              if (recientes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColores.fondoCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColores.bordeDefault),
                  ),
                  child: Text(
                    'Todavía no hay sesiones guardadas para este usuario.',
                    style: AppTipo.body().copyWith(color: AppColores.textoSecundario),
                  ),
                )
              else
                ...recientes.map(
                  (sesion) => ItemSesion(
                    nombre: sesion.ejercicioFormateado,
                    fecha: _formatearFecha(sesion.fecha),
                    estado: sesion.estado,
                    icono: _iconoParaEjercicio(sesion.ejercicio),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

