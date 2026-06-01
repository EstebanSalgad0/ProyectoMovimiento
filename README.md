# Proyecto Movimiento App (IA + Flutter)

Este repositorio contiene un prototipo de aplicación móvil en Flutter junto con un servidor backend en Python que ejecuta un modelo de Inteligencia Artificial (MediaPipe) para analizar movimientos corporales a partir de video.

El proyecto está pensado como una guía de apoyo para actividad física y ejercicios. Su objetivo es ofrecer retroalimentación visual sobre la ejecución del movimiento para ayudar a identificar detalles de técnica, postura y ejecución durante una práctica. En esta etapa, la idea es servir como una referencia inicial para entrenamiento, orientación corporal y validación de movimientos básicos a través de video.

Como prototipo, el sistema está orientado principalmente a pruebas funcionales y demostraciones del flujo completo entre la captura de video, el análisis del movimiento y la visualización de resultados. No pretende reemplazar la evaluación profesional ni ofrecer diagnósticos médicos; su función es acompañar al usuario con información útil para mejorar la comprensión de su movimiento.

## ¿Para qué sirve?

- Dar una referencia visual sobre cómo se está ejecutando un movimiento.
- Apoyar rutinas de ejercicio o actividades físicas con retroalimentación básica.
- Probar un flujo de análisis de movimiento en tiempo real o casi en tiempo real.
- Servir como base para futuras mejoras en precisión, cobertura de ejercicios y experiencia de usuario.

## Guía de uso rápida

1. Levanta el servidor de análisis en tu computadora.
2. Abre la aplicación móvil en un emulador o en un dispositivo físico.
3. Concede los permisos necesarios para usar la cámara, si la app los solicita.
4. Inicia la captura o el flujo de análisis desde la pantalla principal.
5. Realiza el movimiento o ejercicio frente a la cámara.
6. Revisa la retroalimentación generada por el sistema para observar cómo se está ejecutando el gesto o postura.

## Alcance actual

- Es un prototipo funcional, no una versión final.
- El análisis se centra en la lectura de movimiento desde video.
- La utilidad principal es informativa y de apoyo, no clínica.
- El proyecto puede extenderse después con más ejercicios, métricas y validaciones.

---

# Estructura del Proyecto

- `/app`: Código fuente de la aplicación móvil (Flutter).
- `/servidor`: Código fuente del modelo de IA y la API (Python/FastAPI).

---

# 1. Configuración y Ejecución del Servidor (IA)

## Requisitos

- Python 3.10+ (recomendado 3.12): se usa para ejecutar el servidor y las librerías de análisis.
- Webcam funcional: necesaria para capturar el movimiento que luego será procesado por el modelo de IA.

## Instalación

1. Abre una terminal y navega a la carpeta del servidor. Esto te coloca dentro del módulo que contiene el modelo y la API:

```bash
cd servidor
```

2. Crea un entorno virtual. Esto aísla las dependencias del proyecto para evitar conflictos con otros entornos de Python:

### Windows

```bash
python -m venv venv
```

### Linux/macOS

```bash
python3 -m venv venv
```

3. Activa el entorno virtual. Al hacerlo, los comandos de Python y pip quedarán apuntando al entorno del proyecto:

### Windows

```bash
venv\Scripts\activate
```

### Linux/macOS

```bash
source venv/bin/activate
```

4. Instala las dependencias. Con este comando se descargan todas las librerías necesarias para el servidor y el modelo:

```bash
pip install -r requirements.txt
```

---

## Ejecución del Servidor

Levanta la API con Uvicorn para recibir peticiones desde la App. Este proceso deja el servidor escuchando solicitudes desde Flutter:

```bash
uvicorn servidor:app --reload --host 0.0.0.0 --port 8000
```

Verifica que el servidor responde entrando en tu navegador a esta dirección. Si ves una respuesta, significa que el backend quedó levantado correctamente:

```text
http://localhost:8000
```

---

# 2. Configuración y Ejecución de la App (Flutter)

## Requisitos

- Flutter SDK instalado: necesario para compilar y ejecutar la app móvil.
- Android Studio (Emulador) o dispositivo físico configurado para depuración: sirve para probar la interfaz y el flujo de análisis.

## Instalación y Ejecución

1. Abre una nueva terminal y navega a la carpeta de la app. Aquí se encuentra la interfaz móvil del proyecto:

```bash
cd app
```

2. Descarga las dependencias de Flutter. Este paso instala los paquetes usados por la aplicación para construir la interfaz y comunicarla con el servidor:

```bash
flutter pub get
```

3. Ejecuta la aplicación. Flutter compilará la app y la abrirá en el dispositivo o emulador seleccionado:

```bash
flutter run
```

---

# ⚠️ Importante — Conexión App → Servidor

- Si pruebas en un **Emulador de Android**, la IP para conectarse al servidor local (tu PC) no es `localhost`, debes usar:

```text
10.0.2.2:8000
```

- Si pruebas en un **Teléfono Físico**, asegúrate de que el teléfono y el PC estén en la misma red Wi-Fi y usa la IP local de tu computadora:

```text
192.168.1.X:8000
```

---

# 3. Flujo recomendado de prueba

1. Inicia primero el servidor para asegurarte de que el modelo de análisis esté disponible.
2. Luego abre la app Flutter en el emulador o teléfono.
3. Comprueba que la app pueda comunicarse con la dirección correcta del backend.
4. Haz una prueba simple con un movimiento claro y visible frente a la cámara.
5. Revisa el resultado y ajusta la postura o el gesto para observar cambios en la retroalimentación.

## Notas del prototipo

- Este proyecto está en fase de prototipo, así que la prioridad actual es validar la idea y el flujo general.
- La salida del sistema debe interpretarse como apoyo visual, no como evaluación definitiva.
- El objetivo es sentar una base para mejorar después el análisis, la interfaz y los tipos de ejercicios soportados.