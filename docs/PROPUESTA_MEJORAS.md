# Propuesta de mejoras — Proyecto Movimiento (hacia TRL 3–4)

Este documento resume (1) qué problemas tenía el prototipo original, (2) qué se resolvió en la rama
`claude/determined-gauss-b67w19` y (3) qué mejoras se proponen a continuación, ordenadas por impacto.
El paso a paso para ejecutarlas está en [`PLAN_IMPLEMENTACION.md`](PLAN_IMPLEMENTACION.md).

> Los umbrales del análisis son valores iniciales razonables, **no validados clínicamente**. Antes de un
> piloto deben revisarse con kinesiólogos y validarse en laboratorio (ver Fase 4 del plan).

---

## 1. Diagnóstico del prototipo original

Las referencias `archivo:línea` corresponden a la versión original (commit `31e5570`, rama `main`).

### 1.1 Modelo de análisis (servidor)

| # | Problema | Dónde estaba | Consecuencia |
|---|----------|--------------|--------------|
| M1 | Los ángulos se calculaban con `x, y` **normalizados** (escalas distintas: ancho vs alto) y con la `z` normalizada, que es ruidosa. | `servidor.py:28-29` (`lm_to_np`) | Ángulos deformados según la relación de aspecto del video (un video 16:9 vertical y uno horizontal dan ángulos distintos para la misma postura). |
| M2 | No se revisaba la **visibilidad** de los puntos. | `analizar_frame` | Se evaluaban rodillas o tobillos fuera de cuadro como si fueran reales. |
| M3 | Evaluación **cuadro a cuadro**, sin repeticiones. | `analizar_frame` | Los momentos de reposo cuentan como errores (de pie en una sentadilla siempre generaba "baje un poco más"). No había conteo, rango de movimiento ni ritmo. |
| M4 | El **puntaje** se calculaba buscando palabras ("mejore", "alinee", …) en el texto del feedback. | `servidor.py:182` | Frágil: cambiar una frase cambia el puntaje; "controle el descenso" no penalizaba; los mensajes positivos repetidos inflaban el denominador. |
| M5 | Las métricas devueltas eran solo las del **último cuadro**. | `servidor.py:235` | El resultado mostrado no representaba la sesión. |
| M6 | Umbrales en unidades de imagen (p. ej. `0.10` del ancho). | constantes | Dependían de la distancia a la cámara. |
| M7 | Sin **suavizado** temporal. | — | Temblor de la detección → mensajes que cambian de un cuadro a otro. |
| M8 | Sin considerar la **vista** de la cámara. | — | El valgo de rodilla solo se ve de frente; la profundidad y el tronco, de costado. Se evaluaba todo siempre. |
| M9 | Regla de zancada "rodilla trasera > 130°". | `servidor.py:42` | Contradice la técnica estándar (ambas rodillas cerca de 90°). |
| M10 | Lógica duplicada y divergente entre `servidor.py` y `pose_feedback_webcam.py`; variables calculadas sin uso (`left_wrist_above`). | ambos archivos | Calibrar en la webcam no se reflejaba en la API. |

### 1.2 Servidor

- Endpoint `async` con trabajo pesado de CPU (`servidor.py:192`): un análisis bloqueaba **todas** las demás peticiones.
- El video completo se cargaba en memoria (`servidor.py:201`), sin límite de tamaño ni validación.
- Sin CORS, autenticación, versionado de API ni control de concurrencia.
- La ruta del modelo era relativa al directorio de trabajo (`MODEL_PATH`): fallaba si se ejecutaba desde otra carpeta.

### 1.3 App Flutter

- URL del servidor fija en el código (`servicio_ia.dart:10`, `10.0.2.2`): en un teléfono físico había que recompilar.
- "Tiempo real" era solo una pantalla informativa (sin cámara).
- Usuarios y contraseñas en el código; la sesión no persistía.
- Si no llegaba resultado, la pantalla mostraba **100/100 por defecto** (`resultado_pantalla.dart:76`).
- El nombre del video se obtenía con `split('\\')` (solo funciona en Windows) (`analizando_pantalla.dart:78`).
- Sin gestión de estado ni rutas tipadas (argumentos como `Map` dinámico); errores de red mostrados como excepción cruda.
- Faltaban permisos de cámara en iOS e `INTERNET` en el manifiesto de release de Android.
- `google_fonts` descargaba la fuente en tiempo de ejecución (sin internet → otra fuente).

---

## 2. Lo que ya se implementó en esta rama

### 2.1 Motor de análisis v2 (Python + Dart, mismas reglas)

```
compartido/ejercicios.json  ← fuente única: ejercicios, señal de repeticiones, verificaciones, umbrales, mensajes
        │
        ├── servidor/motor/   (Python)  → análisis de video con MediaPipe
        └── app/lib/motor/    (Dart)    → análisis en vivo en el teléfono con ML Kit
```

| Mejora | Cómo |
|--------|------|
| Ángulos correctos (M1) | Puntos convertidos a píxeles; ángulos articulares en 3D con los *world landmarks* de MediaPipe. |
| Visibilidad (M2) | Punto con visibilidad < 0,5 = ausente; si un lado no se ve (vista lateral) se usa el otro. |
| Repeticiones (M3) | Máquina de estados con histéresis sobre una señal principal por ejercicio; repeticiones completas, incompletas y descartadas por ruido. |
| Evaluación por repetición | Cada verificación se evalúa en el momento correcto: en el punto más profundo (`pico_*`), en todo el recorrido (`rep_max`, `rep_rango_max`), en reposo (`reposo_*`), simetría (`asimetria_pico`) y ritmo (`duracion_min`). |
| Puntaje (M4) | Por severidad (`alta` −30, `moderada` −15, `leve` −5) por repetición; promedio de la sesión; castigo acotado por repeticiones incompletas. |
| Resultado rico (M5) | Repeticiones (pico, rango, tiempos, fallos), hallazgos agregados ("en 2 de 5 repeticiones"), aciertos, serie temporal para gráficos y calidad del registro. |
| Normalización (M6) | Alineaciones relativas al ancho de cadera o al largo del tronco. |
| Suavizado (M7) | Filtro One Euro por métrica. |
| Vista (M8) | Detección frontal/lateral/oblicua; cada regla declara en qué vista aplica; se sugiere grabar de otra forma si faltó evaluar algo. |
| Zancada (M9) | Reglas corregidas: flexión de ambas rodillas, tronco erguido, rodilla delantera alineada. |
| Un solo motor (M10) | La webcam, la API y la app usan las mismas reglas. |
| Más movimientos | 6 ejercicios: sentadilla, zancada, curl de bíceps, press de hombros, **elevación lateral** y **sentarse y pararse** (base de la prueba funcional de 30 s). |
| Equivalencia probada | 9 escenarios sintéticos con resultado conocido (`compartido/fixtures/`) que **ambos** motores deben reproducir exactamente. |

### 2.2 Servidor (API v2, compatible con la app anterior)

- `GET /salud`, `GET /v1/ejercicios`, `POST /v1/analisis/video`, `POST /v1/analisis/puntos` (puntos detectados en el teléfono, sin enviar video) y `/analizar` (alias compatible con la v1).
- Endpoints síncronos en pool de hilos, límite de análisis simultáneos, subida por bloques con límite de tamaño, validación de entrada, CORS configurable y variables de entorno.
- Reducción de resolución antes de MediaPipe (más rápido, misma precisión).
- 32 tests (`pytest`), incluido un video real procesado por MediaPipe.

### 2.3 App (rediseño completo)

- **Arquitectura:** Riverpod (estado), go_router (navegación con barra inferior y redirecciones por sesión), repositorios con interfaces (auth, historial, API) listos para cambiar a backend real.
- **Tiempo real en el teléfono:** cámara + ML Kit + motor local: guía de encuadre, cuenta regresiva, esqueleto con zonas en rojo al fallar, contador de repeticiones, medidor del movimiento, avisos visuales, voz y vibración. No necesita servidor ni internet.
- **Pantallas:** bienvenida, login, registro, inicio (resumen semanal, racha, ejercicios, actividad), catálogo con búsqueda y filtros, detalle con ilustración animada, preparación de video (grabar/galería con vista previa), análisis con progreso real de subida y cancelación, resultado (puntaje, comparación con la sesión anterior, gráfico del ángulo con repeticiones y objetivo, detalle por repetición, correcciones, aciertos, calidad), progreso (evolución, correcciones frecuentes, historial agrupado) y cuenta (tema claro/oscuro, voz, cámara, servidor con prueba de conexión, borrar historial, licencias).
- **Diseño:** sistema de diseño propio (paleta semántica clara/oscura, tipografía Plus Jakarta Sans incluida en la app, componentes reutilizables), ilustraciones de ejercicios dibujadas por código.
- **Datos:** historial compatible con el formato v1 (no se pierden sesiones), escritura atómica; contraseñas con sal + SHA-256 (modo demo).
- **Calidad:** `flutter analyze` sin observaciones; 42 tests (motor, modelos, flujos de pantallas); capturas generadas automáticamente en `docs/capturas/`.

---

## 3. Mejoras propuestas (siguientes pasos)

Prioridad: 🔴 imprescindible para TRL 4 · 🟠 alto impacto · 🟢 deseable.

### 3.1 Modelo de análisis

1. 🔴 **Validación de exactitud en laboratorio** (lo que define TRL 4). Protocolo con 20–30 personas, 6 ejercicios, vista frontal y lateral. Comparar contra goniómetro o software de referencia (Kinovea) o, idealmente, captura de movimiento con marcadores. Métricas:
   - Error absoluto medio del ángulo por articulación (meta: < 8°).
   - Exactitud del conteo de repeticiones (meta: > 95 %).
   - Sensibilidad y especificidad de cada error vs. etiquetas de 2 kinesiólogos (meta: > 80 %), con concordancia entre evaluadores (kappa).
2. 🔴 **Calibración de umbrales con profesionales.** Usar `pose_feedback_webcam.py` (mismo motor) para ajustar en vivo `compartido/ejercicios.json` y versionar los cambios.
3. 🟠 **Objetivos personalizados por persona** (p. ej. post-operatorio con rango limitado): el profesional define rangos objetivo por paciente; el motor ya trabaja con umbrales parametrizables, falta guardarlos por usuario.
4. 🟠 **Calibración inicial**: pose neutra de 2 s al comenzar para medir el rango propio y detectar compensaciones basales.
5. 🟠 **Más tipos de ejercicio**: alternados (curl alternado: un contador por brazo), unilaterales (por lado), isométricos y de equilibrio (plancha, apoyo unipodal: tiempo y oscilación), y **pruebas funcionales estandarizadas** (30 s sentarse-pararse con valores de referencia por edad, Timed Up and Go, rango de hombro).
6. 🟠 **Comparación con referencia**: el profesional graba la ejecución ideal y se compara por *Dynamic Time Warping* (puntaje de similitud por fase).
7. 🟢 **Modelo aprendido** sobre secuencias de puntos (TCN/GRU/Transformer liviano) para errores difíciles de expresar con reglas y reconocimiento automático del ejercicio; entrenar en servidor y exportar a TensorFlow Lite para el teléfono. Requiere el dataset del punto 1.
8. 🟢 **Mejores estimadores de pose** para video en servidor (MediaPipe *heavy*, RTMPose) y *lifting* 3D (p. ej. MotionBERT) para ángulos fuera del plano de la cámara.
9. 🟢 **Indicadores de confianza** más finos (visibilidad media, temblor, oclusiones) para rechazar registros no evaluables en vez de dar un puntaje dudoso.

### 3.2 App

1. 🔴 **Prueba en dispositivos reales** (al menos 3 Android de distinta gama y 2 iPhone): rendimiento de detección (meta ≥ 15 cuadros/s en gama media), rotación y espejo de cámara, permisos, voz.
2. 🔴 **Identidad de la app**: `applicationId`/bundle id definitivos (hoy `com.example.medicina_app`), ícono, pantalla de inicio, firma de release.
3. 🟠 **Backend de cuentas y sincronización** (offline-first: base local SQLite/Drift + cola de sincronización). Las interfaces `RepositorioAuth` y `HistorialServicio` ya permiten cambiar la implementación sin tocar pantallas.
4. 🟠 **Rol profesional**: lista de pacientes, asignación de rutinas, objetivos, revisión de sesiones y comentarios; para el paciente, plan del día y recordatorios (notificaciones).
5. 🟠 **Grabadora propia** con guía de encuadre y verificación de pose antes de grabar (evita videos inútiles) y **reproducción del video con el esqueleto** y marcas de repeticiones.
6. 🟢 Reporte PDF para el profesional; exportación de datos.
7. 🟢 Accesibilidad completa (lectores de pantalla, contraste, letra grande — la interfaz ya soporta textos largos sin desbordes) e internacionalización (`intl` + ARB).
8. 🟢 Telemetría de errores (Sentry/Crashlytics) y analítica de uso con consentimiento.
9. 🟢 Pruebas de integración en dispositivo (`integration_test`) en CI.

### 3.3 Plataforma, escala y cumplimiento

1. 🟠 **Procesar en el teléfono y enviar solo puntos** (no video): ~1000 veces menos datos, mejor privacidad y servidor mucho más barato. El endpoint `/v1/analisis/puntos` ya existe.
2. 🟠 **Análisis de video asíncrono**: cola de trabajos (Redis + Celery/RQ/Arq), estado y progreso consultables, *workers* escalables; almacenamiento de objetos (S3/MinIO) solo si se necesita guardar video.
3. 🟠 **Infraestructura**: Docker, CI/CD (GitHub Actions: análisis + tests de app y servidor), entornos dev/staging/prod, HTTPS obligatorio, base de datos PostgreSQL, observabilidad (logs estructurados, métricas, alertas).
4. 🔴 **Datos de salud**: son datos sensibles. Consentimiento informado, cifrado en tránsito y en reposo, minimización (no guardar video si no es necesario), plazos de retención y derecho a eliminación. En Chile aplican la Ley 19.628 y la nueva Ley 21.719 de protección de datos personales (cuya entrada en vigencia está prevista para diciembre de 2026); si se usa en un contexto clínico, también la Ley 20.584. Validar con asesoría legal.
5. 🟢 **Regulatorio a futuro**: si la app pasa a orientar decisiones clínicas podría considerarse *software como dispositivo médico*; conviene trabajar desde ya con buenas prácticas (control de versiones de la especificación, trazabilidad de requisitos, gestión de riesgos tipo ISO 14971, ciclo de vida IEC 62304).
6. 🟢 **Especificación remota**: descargar `ejercicios.json` desde `/v1/ejercicios` (con versión y respaldo local) para ajustar umbrales sin publicar una nueva versión de la app.

---

## 4. Arquitectura objetivo

```
┌──────────────────────── Teléfono (Flutter) ─────────────────────────┐
│ Cámara → ML Kit (33 puntos) → Motor local (reglas compartidas)       │
│        → feedback en vivo (visual + voz) → resultado → base local    │
│                         │ sincroniza resultados (y puntos opcionales) │
└─────────────────────────┼────────────────────────────────────────────┘
                          ▼ HTTPS + JWT
┌──────────────────────── Backend ────────────────────────────────────┐
│ API FastAPI (/v1)  ── PostgreSQL (usuarios, planes, sesiones)        │
│      │             ── Almacenamiento de objetos (videos, opcional)   │
│      └── Cola de trabajos ──► Workers MediaPipe (análisis de video)  │
│ Observabilidad · CI/CD · Respaldos                                   │
└──────────────────────────────────────────────────────────────────────┘
          ▲
          │ Portal del profesional (Flutter web): pacientes, planes, reportes
```

Con el análisis en el teléfono, el backend solo guarda y sirve datos: escala a miles de usuarios con una
infraestructura pequeña. El análisis de video en el servidor queda como complemento (videos subidos,
segunda opinión, investigación).
