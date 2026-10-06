# Proyecto Movimiento — Análisis de movimiento con IA (Flutter + Python)

Aplicación móvil para **Android e iOS** que analiza la técnica de ejercicios a partir de la cámara del
teléfono. Detecta 33 puntos del cuerpo, cuenta repeticiones, evalúa cada una y entrega correcciones
claras, en tiempo real o a partir de un video.

> Prototipo en desarrollo (TRL 3–4). Es un apoyo para la práctica de ejercicio y **no reemplaza la
> evaluación de un profesional de la salud**. Los umbrales del análisis aún deben validarse clínicamente.

<p align="center">
  <img src="docs/capturas/03_inicio.png" width="23%" alt="Inicio con meta semanal">
  <img src="docs/capturas/15_rutinas.png" width="23%" alt="Rutinas guiadas">
  <img src="docs/capturas/19_evaluaciones.png" width="23%" alt="Evaluaciones funcionales">
  <img src="docs/capturas/08_resultado.png" width="23%" alt="Resultado">
</p>
<p align="center">
  <img src="docs/capturas/25_revision.png" width="23%" alt="Revisión del movimiento">
  <img src="docs/capturas/26_progreso_calendario.png" width="23%" alt="Progreso">
  <img src="docs/capturas/21_perfil.png" width="23%" alt="Perfil">
  <img src="docs/capturas/12_inicio_oscuro.png" width="23%" alt="Modo oscuro">
</p>

## Qué hace

- **Tiempo real en el teléfono** (sin servidor ni internet): guía de encuadre, cuenta regresiva,
  esqueleto sobre la cámara, contador de repeticiones, avisos visuales y por voz.
- **Rutinas guiadas:** 4 rutinas recomendadas y rutinas propias (editor de ejercicios, series,
  repeticiones y descansos). La cámara sigue abierta, cada serie termina sola, los descansos tienen
  cuenta regresiva y al final hay un resumen.
- **Evaluaciones funcionales:** prueba de sentarse y pararse en 30 s con referencias del CDC (STEADI)
  por edad y sexo, y goniómetro con la cámara (hombro, codo, cadera y rodilla).
- **Análisis de video** en el servidor (grabar o elegir de la galería), con el esqueleto dibujado sobre
  el video al revisarlo.
- **Resultado detallado:** puntaje, gráfico del movimiento, detalle por repetición, correcciones
  priorizadas, esfuerzo y dolor percibidos, y **revisión del movimiento** (repetición del esqueleto con
  marcas de cada repetición).
- **Objetivos personalizados:** ajustar umbrales o desactivar revisiones por ejercicio (por ejemplo, menos
  profundidad tras una cirugía); se aplican en vivo y en el servidor.
- **Progreso y motivación:** meta semanal, calendario de 12 semanas, tendencias de puntaje, dolor y
  esfuerzo, evaluaciones, logros y recomendaciones "Para ti".
- **Cuenta:** perfil completo con configuración inicial, cambio de contraseña, reporte PDF para el
  profesional, exportación de datos (JSON) y eliminación de la cuenta.
- **6 ejercicios:** sentadilla, zancada, curl de bíceps sentado, press de hombros sentado, elevación
  lateral y sentarse-pararse.

Detalle de cada función, estado y próximos pasos: [plan de funciones](docs/PLAN_FUNCIONES.md).

## Cómo funciona

```
compartido/ejercicios.json   ← reglas únicas: ejercicios, umbrales, códigos y mensajes
        │
        ├── app/lib/motor/      motor en Dart  → tiempo real con ML Kit en el teléfono
        └── servidor/motor/     motor en Python → análisis de video con MediaPipe
```

Ambos motores aplican las mismas reglas y se verifican con los mismos escenarios de prueba
(`compartido/fixtures/`), por lo que un ejercicio se evalúa igual en vivo que por video.

Por cada ejercicio, el motor: (1) calcula ángulos y alineaciones (normalizados por tamaño corporal),
(2) los suaviza (filtro One Euro), (3) detecta repeticiones con una máquina de estados y (4) evalúa cada
repetición con reglas por severidad, considerando la vista de la cámara (frente o costado).

## Estructura

| Carpeta | Contenido |
|---------|-----------|
| `app/` | App Flutter (Riverpod, go_router, cámara + ML Kit, gráficos). Ver [app/README.md](app/README.md). |
| `servidor/` | API FastAPI + motor Python + herramienta de webcam. Ver [servidor/README.md](servidor/README.md). |
| `compartido/` | Especificación de ejercicios y escenarios de prueba comunes. |
| `docs/` | [Plan de funciones](docs/PLAN_FUNCIONES.md), [propuesta de mejoras](docs/PROPUESTA_MEJORAS.md), [plan de implementación](docs/PLAN_IMPLEMENTACION.md) y capturas. |

## Inicio rápido

### 1. Servidor (solo necesario para analizar videos)

Requiere Python 3.10+ (recomendado 3.12).

```bash
cd servidor
python -m venv venv
# Windows: venv\Scripts\activate   ·   Linux/macOS: source venv/bin/activate
pip install -r requirements.txt
uvicorn servidor:app --reload --host 0.0.0.0 --port 8000
```

Comprueba que responde en <http://localhost:8000/salud>.

### 2. App

Requiere Flutter 3.44 o superior (probado con 3.47). iOS 15.5+ y Android 7.0 (API 24)+.

```bash
cd app
flutter pub get
flutter run
```

Credenciales de demostración: `usuario.prueba` / `1234` (botón **Usar** en la pantalla de login).

### Conexión app → servidor

La dirección se cambia en la app: **Cuenta → Servidor de análisis de video → Cambiar** (con botón
**Probar**). También puede fijarse al compilar: `flutter run --dart-define=API_URL=http://192.168.1.50:8000`.

- Emulador de Android: `http://10.0.2.2:8000` (valor por defecto).
- Simulador de iOS: `http://localhost:8000`.
- Teléfono físico: la IP local del computador, en la misma red Wi-Fi.

> El modo **tiempo real** funciona sin servidor. La detección de pose en vivo usa ML Kit, que requiere un
> dispositivo físico o un emulador con cámara; en iOS conviene probar en un iPhone real.

## Pruebas

```bash
cd servidor && pip install -r requirements-dev.txt && pytest      # 37 tests
cd app && flutter analyze && flutter test                         # 89 tests
cd app && flutter test test_capturas --update-goldens             # regenera docs/capturas (30 pantallas)
```

## Cómo probar en un teléfono

1. Entra con `usuario.prueba` / `1234` (o crea una cuenta y completa la configuración inicial).
2. **Entrenar → Rutinas →** "Activación diaria" → **Comenzar rutina**: apoya el teléfono donde se vea
   todo tu cuerpo y sigue las series; al final verás el resumen y podrás registrar cómo te sentiste.
3. **Entrenar → Evaluaciones →** prueba de 30 segundos y goniómetro.
4. En un resultado, toca **Revisar movimiento** para ver el esqueleto grabado.
5. **Progreso** (calendario, tendencias, logros) y **Cuenta → Datos y privacidad** (reporte PDF).

## Documentación

- [Plan de funciones](docs/PLAN_FUNCIONES.md): catálogo de funciones nuevas (implementadas y planificadas)
  y cómo probarlas.
- [Propuesta de mejoras](docs/PROPUESTA_MEJORAS.md): diagnóstico del prototipo original, qué se
  implementó y qué falta (modelo, app, escala y cumplimiento).
- [Plan de implementación](docs/PLAN_IMPLEMENTACION.md): fases hacia TRL 4–5 con tareas y criterios de
  aceptación.

## Autores

- **Esteban Salgado** — Responsable del desarrollo del modelo de IA, el backend y la integración del análisis de movimiento.
- **Martín Ulloa (MartinUlloaG)** — Responsable del apartado visual y del desarrollo de la aplicación móvil en Flutter.
