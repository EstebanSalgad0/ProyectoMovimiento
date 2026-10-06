import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/proveedores.dart';
import '../../rutas.dart';
import '../tema/colores.dart';

/// Avisa con una animación cuando se desbloquea un logro, en cualquier
/// pantalla. Los logros que ya estaban desbloqueados al abrir la app no se
/// anuncian.
class CelebradorLogros extends ConsumerStatefulWidget {
  final Widget child;
  const CelebradorLogros({super.key, required this.child});

  @override
  ConsumerState<CelebradorLogros> createState() => _CelebradorLogrosState();
}

class _CelebradorLogrosState extends ConsumerState<CelebradorLogros> {
  Set<String>? _conocidos;
  String? _usuario;

  void _revisar() {
    final usuario = ref.read(authProvider)?.usuario;
    if (usuario != _usuario) {
      _usuario = usuario;
      _conocidos = null;
    }
    // Se espera a que el historial y las evaluaciones estén cargados.
    if (usuario == null || !ref.read(historialProvider).hasValue || !ref.read(evaluacionesProvider).hasValue) {
      return;
    }
    final desbloqueados = ref.read(logrosProvider).where((l) => l.desbloqueado).toList();
    final conocidos = _conocidos;
    if (conocidos == null) {
      _conocidos = {for (final l in desbloqueados) l.id};
      return;
    }
    final nuevos = desbloqueados.where((l) => !conocidos.contains(l.id)).toList();
    if (nuevos.isEmpty) return;
    conocidos.addAll(nuevos.map((l) => l.id));
    final logro = nuevos.first;
    final mensajero = ScaffoldMessenger.maybeOf(context);
    if (mensajero == null) return;
    final p = context.paleta;
    mensajero.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.2, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, e, child) => Transform.scale(scale: e, child: child),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(gradient: p.gradiente, shape: BoxShape.circle),
                child: Icon(logro.icono, color: AppColores.blanco, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('¡Logro desbloqueado!', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(nuevos.length == 1 ? logro.titulo : '${logro.titulo} y ${nuevos.length - 1} más'),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(label: 'Ver', onPressed: () => ref.read(routerProvider).push(Rutas.logros)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(logrosProvider, (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) => _revisar()));
    ref.listen(historialProvider, (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) => _revisar()));
    return widget.child;
  }
}
