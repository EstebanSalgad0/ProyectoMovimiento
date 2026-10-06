import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/tema.dart';
import '../../core/tema/tipografia.dart';
import '../../core/widgets/tarjeta.dart';
import '../../estado/proveedores.dart';
import '../../modelos/logros.dart';
import '../../modelos/sesion.dart';

class LogrosPantalla extends ConsumerWidget {
  const LogrosPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.paleta;
    final logros = ref.watch(logrosProvider);
    final desbloqueados = logros.where((l) => l.desbloqueado).length;
    final sesiones = ref.watch(historialProvider).value ?? const <Sesion>[];
    final evaluaciones = ref.watch(evaluacionesProvider).value ?? const [];
    final fechas = [...sesiones.map((s) => s.fecha), ...evaluaciones.map((e) => e.fecha)];
    final ordenados = [...logros]
      ..sort((a, b) {
        if (a.desbloqueado != b.desbloqueado) return a.desbloqueado ? -1 : 1;
        return b.avance.compareTo(a.avance);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Logros')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Medidas.margen, 4, Medidas.margen, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: p.gradiente, borderRadius: BorderRadius.circular(Medidas.radioXL)),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: logros.isEmpty ? 0 : desbloqueados / logros.length,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          color: AppColores.blanco,
                          backgroundColor: AppColores.blanco.withValues(alpha: 0.2),
                        ),
                      ),
                      Text('$desbloqueados', style: AppTipo.numero(30, AppColores.blanco)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$desbloqueados de ${logros.length} logros',
                        style: context.textos.titleLarge?.copyWith(color: AppColores.blanco),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Racha actual: ${rachaDias(fechas)} días\nMejor racha: ${mejorRacha(fechas)} días',
                        style: context.textos.bodyMedium?.copyWith(color: AppColores.blanco.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ordenados.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 186,
            ),
            itemBuilder: (context, i) => TarjetaLogro(logro: ordenados[i]),
          ),
        ],
      ),
    );
  }
}

class TarjetaLogro extends StatelessWidget {
  final Logro logro;
  const TarjetaLogro({super.key, required this.logro});

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final ok = logro.desbloqueado;
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      color: ok ? null : p.superficieAlta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ok ? p.gradiente : null,
              color: ok ? null : p.borde,
            ),
            child: Icon(logro.icono, color: ok ? AppColores.blanco : p.textoTerciario, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            logro.titulo,
            style: context.textos.titleSmall?.copyWith(color: ok ? null : p.textoSecundario),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              logro.descripcion,
              style: context.textos.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ok)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: p.exito),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Desbloqueado',
                    style: context.textos.labelSmall?.copyWith(color: p.exito),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: logro.avance,
                minHeight: 6,
                color: p.primario,
                backgroundColor: p.borde,
              ),
            ),
            if (logro.detalleAvance != null) ...[
              const SizedBox(height: 4),
              Text(logro.detalleAvance!, style: context.textos.labelSmall),
            ],
          ],
        ],
      ),
    );
  }
}
