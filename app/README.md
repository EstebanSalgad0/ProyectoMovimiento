# App Flutter — Proyecto Movimiento

App para Android e iOS. La guía general del proyecto está en el [README principal](../README.md).

## Requisitos

- Flutter 3.44+ (probado con 3.47.6) · Dart 3.12+
- Android 7.0 (API 24)+ · iOS 15.5+ (requisito de ML Kit)
- Para el tiempo real: dispositivo con cámara (en iOS se recomienda un iPhone real)

```bash
flutter pub get
flutter run                                              # servidor por defecto: 10.0.2.2 / localhost
flutter run --dart-define=API_URL=http://192.168.1.50:8000
```

En iOS, la primera vez: `cd ios && pod install` (el `Podfile` ya fija iOS 15.5).

## Arquitectura

```
lib/
├── main.dart, app.dart        Arranque: preferencias + especificación + ProviderScope
├── rutas.dart                 go_router: barra inferior (inicio, ejercicios, progreso, cuenta) y redirecciones
├── core/
│   ├── config/                AppConfig (nombre, URL por defecto, aviso)
│   ├── tema/                  Paleta clara/oscura (PaletaApp), tipografía y ThemeData
│   ├── utils/                 Formatos en español y presentación (íconos, colores por severidad)
│   └── widgets/               Componentes: Tarjeta, BotonPrincipal, AnilloPuntaje, IlustracionEjercicio…
├── estado/proveedores.dart    Riverpod: ajustes, sesión, historial, servicios
├── modelos/                   Usuario, Sesion, ResultadoAnalisis (formato v2 y compatibilidad v1)
├── motor/                     Motor de análisis (port 1:1 de servidor/motor, Dart puro)
├── servicios/                 Auth (demo local), historial (archivo), API (dio), voz (TTS)
└── pantallas/                 Una carpeta por pantalla
```

- **Estado:** Riverpod 3 (`Notifier`/`AsyncNotifier`), sin generación de código.
- **Datos:** `RepositorioAuth` y `HistorialServicio` son interfaces; hoy hay implementaciones locales y
  luego se agregan las remotas sin cambiar pantallas.
- **Tiempo real:** `pantallas/tiempo_real/controlador_tiempo_real.dart` une cámara (`camera`), detección
  (`google_mlkit_pose_detection`) y el motor (`motor/analizador.dart`). El resultado tiene el mismo formato
  que la API, así la pantalla de resultados es una sola.
- **Especificación:** `assets/especificacion/ejercicios.json` es copia exacta de
  `../compartido/ejercicios.json` (un test verifica que sean iguales). Si cambias umbrales, edita la
  compartida y cópiala:

  ```bash
  cp ../compartido/ejercicios.json assets/especificacion/ejercicios.json
  ```

## Pruebas

```bash
flutter analyze
flutter test                                  # motor, modelos y flujos de pantallas
flutter test test_capturas --update-goldens   # regenera ../docs/capturas
```

`test/motor/motor_test.dart` ejecuta el motor sobre `../compartido/fixtures/` y exige el mismo resultado
que el motor del servidor.

## Pendiente de verificar en dispositivo

El código compila y pasa el análisis estático y las pruebas, pero la integración nativa (cámara, ML Kit,
permisos, voz) debe probarse en teléfonos reales: ver la Fase 1 en
[`../docs/PLAN_IMPLEMENTACION.md`](../docs/PLAN_IMPLEMENTACION.md).
