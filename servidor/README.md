# Servidor de análisis — Proyecto Movimiento

API FastAPI y motor de análisis en Python. Usa MediaPipe Pose Landmarker para detectar 33 puntos del
cuerpo en videos y el mismo motor de reglas que la app (`../compartido/ejercicios.json`).

## Instalación

Requiere Python 3.10+ (recomendado 3.12).

```bash
python -m venv venv
# Windows: venv\Scripts\activate   ·   Linux/macOS: source venv/bin/activate
pip install -r requirements.txt          # producción
pip install -r requirements-dev.txt      # + pytest
```

En Linux sin entorno gráfico (servidores, Docker) MediaPipe necesita `libegl1` y `libgles2`
(`apt-get install libegl1 libgles2`).

## Ejecutar la API

```bash
uvicorn servidor:app --reload --host 0.0.0.0 --port 8000
```

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/` | Estado (compatible con la app v1) |
| GET | `/salud` | Estado, versión, especificación y ejercicios |
| GET | `/v1/ejercicios` | Especificación completa (catálogo + umbrales) |
| POST | `/v1/analisis/video` | `multipart/form-data`: `video`, `ejercicio` |
| POST | `/v1/analisis/puntos` | JSON con puntos ya detectados (`{ejercicio, fotogramas:[{t_ms, puntos, mundo?}]}`) |
| POST | `/analizar` | Alias de `/v1/analisis/video` (compatibilidad v1) |

Documentación interactiva en <http://localhost:8000/docs>.

### Respuesta

Mantiene los campos de la v1 (`ejercicio`, `puntaje`, `feedback`, `metricas`) y agrega:
`repeticiones` (pico, rango, tiempos, fallos y puntaje por repetición), `hallazgos` (correcciones con
severidad, zona y repeticiones afectadas), `aciertos`, `serie` (señal principal para graficar) y
`calidad` (cuadros válidos, vista detectada, confianza).

### Variables de entorno

| Variable | Por defecto | Uso |
|----------|-------------|-----|
| `MODELO_POSE` | `pose_landmarker_full.task` | Modelo de MediaPipe (`_lite` es más rápido) |
| `MAX_MB_VIDEO` | `200` | Tamaño máximo del video |
| `MAX_ANALISIS_CONCURRENTES` | `2` | Análisis simultáneos (MediaPipe usa mucha CPU) |
| `ESPERA_COLA_S` | `120` | Espera máxima por un cupo antes de responder 503 |
| `ORIGENES_CORS` | `*` | Orígenes permitidos, separados por coma |
| `RUTA_ESPECIFICACION` | `../compartido/ejercicios.json` | Especificación de ejercicios |

## Motor (`motor/`)

| Archivo | Función |
|---------|---------|
| `especificacion.py` | Carga y valida `ejercicios.json` |
| `puntos.py` | Fotograma con 33 puntos (convierte MediaPipe normalizado → píxeles) |
| `metricas.py` | Ángulos 3D, alineaciones 2D normalizadas, vista de cámara, partes no visibles |
| `filtros.py` | Filtro One Euro |
| `repeticiones.py` | Máquina de estados con histéresis |
| `analizador.py` | Orquesta todo, evalúa cada repetición y arma el resultado |
| `video.py` | Lee el video y ejecuta MediaPipe |

Tipos de verificación disponibles en la especificación: `pico_max`, `pico_min`, `rep_max`,
`rep_rango_max`, `reposo_min`, `reposo_max`, `asimetria_pico`, `duracion_min`. Agregar un ejercicio o
ajustar un umbral se hace editando el JSON (y copiándolo a la app).

## Prueba en vivo con webcam (calibración)

```bash
python pose_feedback_webcam.py
```

Usa el mismo motor que la API: muestra el esqueleto, las repeticiones, la fase, el ángulo principal y
las correcciones de la última repetición. Teclas `1`–`6` cambian de ejercicio, `R` reinicia, `ESC` sale
(imprime el resultado completo en JSON). Si toma otra cámara: `CAMERA_INDEX=0` (PowerShell:
`$env:CAMERA_INDEX=0`).

## Pruebas

```bash
pytest
```

Incluye los escenarios sintéticos de `../compartido/fixtures/` (regenerables con
`python ../compartido/fixtures/generar_fixtures.py`), que la app también debe reproducir.
