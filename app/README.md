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
├── rutas.dart                 go_router: barra inferior (inicio, entrenar, progreso, cuenta) y redirecciones
│                              (bienvenida, sesión y configuración inicial del perfil)
├── core/
│   ├── config/                AppConfig (nombre, URL por defecto, aviso)
│   ├── tema/                  Paleta clara/oscura (PaletaApp), tipografía y ThemeData
│   ├── utils/                 Formatos en español y presentación (íconos, colores por severidad)
│   └── widgets/               Componentes: Tarjeta, BotonPrincipal, AnilloPuntaje, IlustracionEjercicio,
│                              LogoMovimiento, AvatarUsuario, hoja de sensaciones, aviso de logros…
├── estado/proveedores.dart    Riverpod: ajustes, sesión, historial, evaluaciones, rutinas, objetivos, logros
├── modelos/                   Usuario (perfil completo), Sesion (+sensaciones, rutina), Rutina y
│                              PlanSesionGuiada, EvaluacionFuncional (STS 30 s, rango articular),
│                              EsqueletoGrabado, logros y recomendaciones (reglas puras, con pruebas)
├── motor/                     Motor de análisis (port 1:1 de servidor/motor, Dart puro) + objetivos personales
├── servicios/                 Auth (demo local), historial, evaluaciones y adjuntos (archivos), API (dio),
│                              voz (TTS), exportación JSON y reporte PDF
└── pantallas/
    ├── inicio, entrenar, progreso, cuenta   pestañas
    ├── tiempo_real/           CamaraPose (cámara + ML Kit, reutilizable), ControladorTiempoReal (serie),
    │                          componentes de la vista de cámara y la pantalla de entrenamiento libre
    ├── rutinas/               lista, detalle, editor, sesión guiada y resumen
    ├── evaluaciones/          prueba de 30 s, goniómetro (controlador + pantalla) y panel
    ├── revision/              repetición del esqueleto o video con el esqueleto encima
    └── cuenta/                perfil (y configuración inicial), logros, datos y privacidad
```

- **Estado:** Riverpod 3 (`Notifier`/`AsyncNotifier`), sin generación de código.
- **Datos:** `RepositorioAuth` y `HistorialServicio` son interfaces; hoy hay implementaciones locales y
  luego se agregan las remotas sin cambiar pantallas.
- **Tiempo real:** `CamaraPose` abre la cámara y entrega cada cuadro con los 33 puntos de ML Kit;
  `ControladorTiempoReal` maneja una serie (encuadre, cuenta regresiva, motor, avisos, fin por objetivo o
  por tiempo) y graba el esqueleto. La misma cámara se reutiliza entre series (rutinas) y en la prueba de
  30 s; el goniómetro usa su propio controlador. El resultado tiene el mismo formato que la API, así la
  pantalla de resultados es una sola.
- **Objetivos personales:** `Especificacion.conAjustes` aplica los umbrales del usuario en vivo; para
  video se envían al servidor en el campo `ajustes` (mismo formato y misma prueba de equivalencia).
- **Especificación:** `assets/especificacion/ejercicios.json` es copia exacta de
  `../compartido/ejercicios.json` (un test verifica que sean iguales). Si cambias umbrales, edita la
  compartida y cópiala:

  ```bash
  cp ../compartido/ejercicios.json assets/especificacion/ejercicios.json
  ```

## Ícono

El ícono es el mismo logo que se dibuja en la app (`core/widgets/logo.dart`). Para regenerarlo:

```bash
flutter test test_capturas/icono_test.dart --update-goldens   # tool/icono/*.png a 1024 px
python tool/generar_iconos.py                                 # Android (adaptable) e iOS; requiere Pillow
```

## Pruebas

```bash
flutter analyze
flutter test                                  # motor, modelos, servicios y flujos de pantallas (89)
flutter test test_capturas --update-goldens   # regenera ../docs/capturas
```

`test/motor/controlador_test.dart` alimenta el controlador de tiempo real con los fotogramas de los
fixtures (sin cámara) y verifica encuadre, conteo y fin de serie.

`test/motor/motor_test.dart` ejecuta el motor sobre `../compartido/fixtures/` y exige el mismo resultado
que el motor del servidor.

## Pendiente de verificar en dispositivo

El código compila y pasa el análisis estático y las pruebas, pero la integración nativa (cámara, ML Kit,
permisos, voz) debe probarse en teléfonos reales: ver la Fase 1 en
[`../docs/PLAN_IMPLEMENTACION.md`](../docs/PLAN_IMPLEMENTACION.md).
