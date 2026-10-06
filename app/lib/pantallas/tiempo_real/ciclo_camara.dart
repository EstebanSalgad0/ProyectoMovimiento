import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camara_pose.dart';

/// Comportamiento común de las pantallas con cámara: vertical fijo, pantalla
/// siempre encendida y liberar la cámara cuando la app pasa a segundo plano.
mixin CicloCamara<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  CamaraPose? get camaraDelCiclo;

  /// Falso cuando la pantalla ya terminó y no debe volver a abrir la cámara.
  bool get reanudarCamara => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = camaraDelCiclo;
    if (c == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      c.pausar();
    } else if (state == AppLifecycleState.resumed && reanudarCamara) {
      c.reanudar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}
