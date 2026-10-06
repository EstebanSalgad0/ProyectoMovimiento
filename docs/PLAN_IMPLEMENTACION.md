# Plan de implementación — Proyecto Movimiento

Plan por fases para llevar el prototipo a **TRL 4** (validado en laboratorio) y dejarlo preparado para un
piloto con usuarios (TRL 5). Cada fase termina con algo demostrable y criterios de aceptación medibles.
Las mejoras detalladas y su justificación están en [`PROPUESTA_MEJORAS.md`](PROPUESTA_MEJORAS.md).

**Forma de trabajo sugerida:** una rama y un *pull request* por bloque de tareas, con la casilla del
checklist marcada al cerrarlo. Los tests (`flutter test`, `pytest`) deben pasar antes de unir a `main`.

| Fase | Objetivo | Duración estimada | Estado |
|------|----------|-------------------|--------|
| 0 | Fundaciones: motor compartido, API v2, app rediseñada con tiempo real | — | ✅ esta rama |
| 1 | Prueba en dispositivos y calibración con profesionales | 2–3 semanas | ⏭️ siguiente |
| 2 | Backend de cuentas y sincronización | 3–4 semanas | |
| 3 | Rol profesional, planes y reportes | 3–4 semanas | |
| 4 | Validación de laboratorio (TRL 4) | 4–6 semanas (en paralelo a 2–3) | |
| 5 | Modelo aprendido y nuevos ejercicios | 6–8 semanas | |
| 6 | Escala, seguridad y piloto (TRL 5) | 4–6 semanas | |

---

## Fase 0 — Fundaciones ✅ (implementado en esta rama)

- [x] Especificación compartida de ejercicios (`compartido/ejercicios.json`) con 6 ejercicios.
- [x] Motor v2 en Python (servidor) y Dart (app) con resultados idénticos, probado con escenarios sintéticos.
- [x] API v2 (`/v1/...`) compatible con la app anterior; límites, validaciones, concurrencia.
- [x] App rediseñada: arquitectura (Riverpod + go_router), 12 pantallas, modo claro/oscuro.
- [x] Tiempo real en el teléfono (cámara + ML Kit + motor local), con voz y guía de encuadre.
- [x] Tests: 32 del servidor, 42 de la app; capturas automáticas de pantallas.

---

## Fase 1 — Prueba en dispositivos y calibración (siguiente)

**Objetivo:** confirmar que la app funciona bien en teléfonos reales y que las correcciones tienen sentido
para un profesional.

### Tareas
- [ ] Compilar y probar en ≥ 3 Android (gama baja, media y alta) y ≥ 2 iPhone (iOS 15.5+).
      `flutter build apk --debug` · `flutter run --release`.
- [ ] Medir cuadros por segundo de la detección y latencia del aviso (agregar un indicador de depuración).
- [ ] Verificar orientación y espejo del esqueleto en cámara frontal y trasera (Android e iOS).
- [ ] Revisar textos de voz con usuarios (claridad, frecuencia, que no sature).
- [ ] Sesión de calibración con 1–2 kinesiólogos usando `servidor/pose_feedback_webcam.py`:
      ajustar umbrales en `compartido/ejercicios.json` (y su copia en `app/assets/especificacion/`).
- [ ] Grabar 5–10 videos por ejercicio (correctos y con errores típicos) para pruebas de regresión.
- [ ] Definir identidad: nombre, `applicationId`/bundle id, ícono y pantalla de inicio.
- [x] Agregar CI (GitHub Actions): `flutter analyze`, `flutter test`, `pytest` en cada PR (`.github/workflows/ci.yml`).

### Criterios de aceptación
- ≥ 15 cuadros/s de detección en un Android de gama media; aviso de corrección < 300 ms después de terminar la repetición.
- Conteo de repeticiones correcto en ≥ 9 de 10 series de prueba por ejercicio.
- Los profesionales están de acuerdo con ≥ 80 % de las correcciones mostradas en los videos de prueba.

---

## Fase 2 — Backend de cuentas y sincronización

**Objetivo:** usuarios reales, datos sincronizados entre dispositivos y despliegue en la nube.

### Tareas (servidor)
- [ ] PostgreSQL + migraciones (SQLAlchemy + Alembic): usuarios, sesiones, resultados.
- [ ] Autenticación JWT (registro, login, refresco, recuperación de contraseña) o un proveedor gestionado.
- [ ] Endpoints: `POST/GET /v1/sesiones`, `GET /v1/progreso`, paginación y filtros.
- [ ] Docker + `docker-compose` (API, base de datos); despliegue en staging con HTTPS.
- [ ] Logs estructurados, manejo de errores y respaldos.

### Tareas (app)
- [ ] `AuthRemoto` implementando `RepositorioAuth`; tokens en `flutter_secure_storage`.
- [ ] Base local (Drift/SQLite) + cola de sincronización (funciona sin conexión).
- [ ] Migración del historial local existente a la cuenta.

### Criterios de aceptación
- Una sesión hecha sin internet aparece en el servidor al recuperar la conexión.
- Tests de API con base de datos de prueba; CI verde.

---

## Fase 3 — Rol profesional, planes y reportes

**Objetivo:** que un profesional pueda guiar y seguir a sus pacientes.

### Tareas
- [ ] Roles y permisos (paciente / profesional) en API y app.
- [ ] Profesional: lista de pacientes, asignación de rutinas (ejercicio, series, repeticiones, frecuencia).
- [ ] Objetivos personalizados por paciente (rangos objetivo que sobrescriben los umbrales generales).
- [ ] Paciente: "plan de hoy", recordatorios (notificaciones locales) y adherencia.
- [ ] Reporte PDF por paciente/período.
- [ ] (Opcional) Portal web del profesional con Flutter web reutilizando componentes.

### Criterios de aceptación
- Un profesional crea un plan, el paciente lo ejecuta en tiempo real y el profesional ve el resultado con sus objetivos.

---

## Fase 4 — Validación de laboratorio (TRL 4) — en paralelo a las fases 2–3

**Objetivo:** demostrar con datos que el sistema mide y detecta correctamente.

### Tareas
- [ ] Protocolo (consentimiento informado, criterios de inclusión, ejercicios, vistas, distancias, iluminación).
- [ ] Captura: 20–30 participantes × 6 ejercicios × 2 vistas, con referencia (goniómetro/Kinovea o captura con marcadores).
- [ ] Etiquetado de errores por 2 kinesiólogos (herramienta simple de anotación por repetición).
- [ ] Script de evaluación que corra el motor sobre el dataset y calcule las métricas.
- [ ] Ajuste final de umbrales (sin sobreajustar: separar datos de ajuste y de prueba).
- [ ] Informe técnico de validación.

### Criterios de aceptación (propuestos)
| Métrica | Meta |
|---------|------|
| Error absoluto medio del ángulo principal | < 8° |
| Exactitud del conteo de repeticiones | > 95 % |
| Sensibilidad / especificidad por error | > 80 % / > 80 % |
| Concordancia entre evaluadores (kappa) | > 0,6 |
| Registros rechazados por mala calidad | < 10 % |

---

## Fase 5 — Modelo aprendido y nuevos ejercicios

### Tareas
- [ ] Ejercicios alternados (contador por lado), unilaterales, isométricos y de equilibrio.
- [ ] Pruebas funcionales estandarizadas: 30 s sentarse-pararse (con referencias por edad), Timed Up and Go, rango de hombro.
- [ ] Comparación con ejecución de referencia del profesional (DTW).
- [ ] Clasificador temporal sobre secuencias de puntos (entrenado con el dataset de la Fase 4); exportar a TFLite y comparar contra las reglas.
- [ ] Descarga de la especificación desde el servidor (`/v1/ejercicios`) con versión y respaldo local.

### Criterios de aceptación
- El modelo aprendido mejora en ≥ 5 puntos la sensibilidad de al menos 2 errores sin empeorar la especificidad.

---

## Fase 6 — Escala, seguridad y piloto (TRL 5)

### Tareas
- [ ] Análisis de video asíncrono (cola de trabajos, estado y progreso), *workers* escalables.
- [ ] Enviar solo puntos desde el teléfono por defecto (privacidad y costo).
- [ ] Seguridad: auditoría, cifrado en reposo, política de retención y eliminación, consentimiento en la app.
- [ ] Cumplimiento normativo (Ley 19.628, Ley 21.719, Ley 20.584 si aplica) con asesoría legal.
- [ ] Observabilidad (métricas, alertas), pruebas de carga.
- [ ] Distribución: TestFlight / Firebase App Distribution; luego tiendas.
- [ ] Piloto con 20–50 usuarios durante 4–8 semanas: adherencia, satisfacción (SUS), incidencias.

### Criterios de aceptación
- 99 % de disponibilidad en el piloto; tiempo de análisis de video < 30 s para 30 s de video; SUS > 70.

---

## Próximos 5 pasos concretos

1. Probar esta rama en un teléfono real (ver "Cómo probar" en el README) y anotar cualquier problema de cámara.
2. Sesión de calibración con un kinesiólogo usando la herramienta de webcam y ajustar `ejercicios.json`.
3. Definir nombre, identificador e ícono definitivos de la app.
4. Abrir un PR de esta rama hacia `main` para que corra la CI y revisar los cambios juntos.
5. Decidir el stack del backend (FastAPI + PostgreSQL propio, o un servicio gestionado) para iniciar la Fase 2.
