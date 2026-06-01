# Servidor de Análisis de Movimiento - Proyecto Movimiento

Este módulo contiene la parte en Python del prototipo Proyecto Movimiento. Usa MediaPipe Pose Landmarker para detectar la pose del cuerpo y generar retroalimentación sobre la ejecución de ciertos movimientos a partir de video.

Su función principal es servir como base de análisis para la aplicación Flutter del repositorio y, al mismo tiempo, permitir pruebas directas con webcam desde este directorio.

## Alcance

- Es un prototipo funcional, no una solución final.
- El análisis está orientado a retroalimentación visual y validación básica de movimiento.
- El código puede ejecutarse como backend para la app o como prueba local con webcam.

## Requisitos

- Python 3.10+ (recomendado 3.12)
- Webcam funcional
- Sistema operativo: Windows, Linux o macOS

## Instalación paso a paso

1. **Abre una terminal en este directorio.**
   Esto te coloca dentro del módulo de análisis donde están el script, el modelo y las dependencias.

2. **Crea un entorno virtual.**
   Aísla las librerías del proyecto para evitar conflictos con otros entornos de Python.

   - En Windows (PowerShell o CMD):
   ```
   python -m venv venv
   ```
   - En Linux/macOS:
   ```
   python3 -m venv venv
   ```

3. **Activa el entorno virtual.**
   Con esto, Python y pip usarán las dependencias de este proyecto.

   - En Windows:
   ```
   venv\Scripts\activate
   ```
   - En Linux/macOS:
   ```
   source venv/bin/activate
   ```

4. **Instala las dependencias.**
   MediaPipe, OpenCV y NumPy son las librerías base para la captura y el análisis del movimiento.

   ```
   pip install mediapipe opencv-python numpy
   ```

   Si aparece un problema con NumPy en una versión específica de Python, puedes probar:

   ```
   pip install "numpy<2.3"
   ```

5. **Verifica la instalación, si lo necesitas.**
   Esto confirma que los módulos principales quedaron disponibles en el entorno.

   ```
   python -c "import cv2; import mediapipe; import numpy as np; print('Instalacion exitosa')"
   ```

## Uso

1. **Ejecuta el script principal.**
   Este comando abre la webcam y comienza el análisis del movimiento en tiempo real.

   ```
   python pose_feedback_webcam.py
   ```

2. **Interacción.**
   - Se abrirá una ventana con la webcam y la visualización de la pose.
   - Las métricas aparecen sobre la imagen para facilitar la lectura del movimiento.
   - El feedback se muestra en pantalla para orientar la ejecución.
   - Presiona **1** para modo **sentadilla**.
   - Presiona **2** para modo **zancada**.
   - Presiona **3** para modo **curl de biceps sentado**.
   - Presiona **4** para modo **press de hombros sentado**.
   - Presiona **ESC** para salir.

3. **Pruebas.**
   - Inclina el tronco lateralmente.
   - Flexiona los codos.
   - Sube un hombro.
   - En sentadilla: baja y sube, verifica profundidad y simetría de rodillas.
   - En zancada: adelanta una pierna, verifica flexión delantera y separación de pies.
   - En curl sentado: mantente sentado, flexiona y extiende codos de forma controlada.
   - En press sentado: eleva brazos sobre hombros y vuelve a la posición inicial.
   - Observa cómo cambian las métricas y el feedback.

## Solución de Problemas

- **La ventana no se abre o se cierra inmediatamente:**
  - Asegúrate de que no haya otras aplicaciones usando la webcam (cierra Zoom, Discord, etc.).
  - Ejecuta en PowerShell externo (no en VS Code integrado).
  - Si persiste, usa un archivo de video: cambia `cap = cv2.VideoCapture(0)` por `cap = cv2.VideoCapture("tu_video.mp4")`.

- **Errores de codificación en texto:**
  - El script usa texto sin acentos para evitar problemas.

- **Problemas con la webcam:**
  - Verifica permisos en Configuración > Privacidad > Cámara.
  - Actualiza drivers de la webcam.
   - Si toma otra camara (virtual), fuerza el indice con variable de entorno:
     - PowerShell: `$env:CAMERA_INDEX=1` y luego `python pose_feedback_webcam.py`
     - CMD: `set CAMERA_INDEX=1` y luego `python pose_feedback_webcam.py`

## Archivos Incluidos

- `pose_feedback_webcam.py`: Script principal.
- `pose_landmarker_lite.task`: Modelo rápido (recomendado).
- `pose_landmarker_full.task`: Modelo preciso (más lento).
- `.gitignore`: Ignora entornos virtuales.
- `README.md`: Esta documentación.

## Notas

- El proyecto se enfoca en métricas del tren superior.
- Tambien incluye reglas basicas de tren inferior para sentadilla y zancada.
- Incluye ejercicios de tren superior para test sentado: curl de biceps y press de hombros.
- Los umbrales se pueden ajustar en el código para personalizar el feedback.
- Para desarrollo, usa el modelo lite; para producción, el full.