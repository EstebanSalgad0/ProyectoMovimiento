# Plan de mejoras y funciones — Proyecto Movimiento

Propuesta de funciones nuevas y mejoras para todo el sistema (app, motor de análisis y servidor),
pensada para que cada iteración se pueda **probar en un teléfono real**. Complementa:

- [`PROPUESTA_MEJORAS.md`](PROPUESTA_MEJORAS.md): diagnóstico técnico y mejoras del modelo.
- [`PLAN_IMPLEMENTACION.md`](PLAN_IMPLEMENTACION.md): fases hacia TRL 4–5.

**Leyenda**

| Estado | Significado |
|--------|-------------|
| ✅ | Implementado (funciona en el teléfono, sin backend) |
| 🛠️ | Implementado en parte |
| 📅 | Planificado (indica en qué fase) |

| Esfuerzo | Valor |
|----------|-------|
| S = días · M = 1–2 semanas · L = 3+ semanas | ★ a ★★★ (impacto para usuarios y para la validación TRL) |

Las funciones marcadas con ✅ trabajan con datos guardados en el teléfono. Cuando exista el backend
(Fase 2) se sincronizan sin cambiar las pantallas, porque los servicios ya están detrás de interfaces.

---

## A. Cuenta y perfil

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| A1 | **Perfil completo y editable**: nombre, correo, fecha de nacimiento (edad), sexo, estatura, peso, lado dominante, nivel de actividad, objetivo principal y zonas con molestias. | Personalizar recomendaciones y entregar valores de referencia por edad y sexo en las pruebas funcionales. | S | ★★★ | ✅ |
| A2 | **Configuración inicial guiada** tras crear la cuenta. | Que el perfil quede completo desde el primer día. | S | ★★ | ✅ |
| A3 | **Seguridad**: cambiar contraseña, cerrar sesión, eliminar la cuenta y sus datos. | Control del usuario sobre su cuenta. | S | ★★ | ✅ |
| A4 | **Privacidad**: consentimiento con fecha y versión; exportar mis datos (JSON). | Base para cumplir la Ley 21.719 (acceso y portabilidad). | S | ★★★ | ✅ |
| A5 | Color de avatar personalizable. | Identidad visual. | S | ★ | ✅ |
| A6 | Cuentas en la nube, recuperación de contraseña, ingreso con Google/Apple. | Usar la app en varios dispositivos. | M | ★★★ | 📅 Fase 2 |
| A7 | Foto de perfil. | Identidad visual. | S | ★ | 📅 Fase 2 |

## B. Entrenamiento

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| B1 | **Rutinas predefinidas**: activación diaria, fuerza de piernas, tren superior sentado, movilidad para adultos mayores. | Entrenar sin tener que armar nada. | S | ★★★ | ✅ |
| B2 | **Rutinas personalizadas**: crear y editar (ejercicios, series, repeticiones, descanso). | Que el usuario o su profesional definan el plan. | M | ★★★ | ✅ |
| B3 | **Sesión guiada**: la cámara sigue abierta, cada serie termina sola al llegar a las repeticiones, descanso con temporizador, avance automático y resumen final. | Entrenamiento completo con manos libres. | M | ★★★ | ✅ |
| B4 | **Objetivos personalizados por ejercicio**: ajustar umbrales (p. ej. profundidad de sentadilla) y activar/desactivar revisiones. Se aplican en vivo y en el análisis de video. | Adaptar a personas en rehabilitación o con rango limitado. | M | ★★★ | ✅ |
| B5 | **Ajustes de entrenamiento**: cuenta regresiva (3/5/10 s), mostrar esqueleto, velocidad de voz, vibración. | Comodidad y accesibilidad. | S | ★★ | ✅ |
| B6 | Ejercicios por tiempo (isométricos, plancha) y calentamiento/enfriamiento. | Cubrir más tipos de trabajo. | M | ★★ | 📅 Fase 5 |
| B7 | Metrónomo para marcar el ritmo de cada fase. | Controlar el tempo. | S | ★ | 📅 Fase 5 |
| B8 | Recordatorios con notificaciones. | Adherencia. | S | ★★★ | 📅 Fase 1 (requiere configurar Android/iOS) |

## C. Evaluación funcional y clínica

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| C1 | **Prueba de sentarse y pararse en 30 s** con conteo automático, cronómetro y comparación con valores de referencia por edad y sexo (CDC STEADI, 60–94 años). | Indicador validado de fuerza de piernas y riesgo de caídas. | M | ★★★ | ✅ |
| C2 | **Medición de rango articular** con la cámara (hombro, codo, cadera, rodilla; lado izquierdo/derecho), con máximo alcanzado e historial. | Seguir la evolución de la movilidad en rehabilitación. | M | ★★★ | ✅ |
| C3 | **Dolor y esfuerzo percibido** después de cada sesión (escalas 0–10) con notas. | Seguimiento clínico; detectar sobrecarga. | S | ★★★ | ✅ |
| C4 | Equilibrio unipodal y Timed Up and Go. | Evaluar equilibrio y movilidad. | M | ★★★ | 📅 Fase 5 |
| C5 | Cuestionarios estandarizados (funcionalidad, calidad de vida). | Resultados reportados por el paciente. | M | ★★ | 📅 Fase 3 |

## D. Progreso y motivación

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| D1 | **Meta semanal** configurable con anillo de progreso. | Constancia. | S | ★★★ | ✅ |
| D2 | **Logros** (primera sesión, rachas, técnica perfecta, repeticiones acumuladas, pruebas). | Motivación. | S | ★★ | ✅ |
| D3 | **Calendario de actividad** (últimas 12 semanas). | Ver la constancia de un vistazo. | S | ★★ | ✅ |
| D4 | **Tendencias** de dolor, esfuerzo, rango articular y pruebas. | Ver la evolución clínica. | S | ★★★ | ✅ |
| D5 | **Gestión del historial**: eliminar sesiones, filtrar. | Mantener los datos limpios. | S | ★★ | ✅ |
| D6 | **"Para ti"**: recomendaciones según las correcciones más frecuentes. | Feedback accionable entre sesiones. | S | ★★ | ✅ |

## E. Revisión del movimiento

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| E1 | **Repetición animada del esqueleto** de cada sesión en tiempo real, con línea de tiempo, velocidad y marcas de repeticiones. | Revisar la técnica después de entrenar sin guardar video (privacidad). | M | ★★★ | ✅ |
| E2 | **Video con el esqueleto superpuesto** en los análisis de video (el servidor devuelve los puntos). | Ver exactamente dónde está el error. | M | ★★★ | ✅ |
| E3 | Comparar dos sesiones lado a lado. | Ver la mejora. | M | ★★ | 📅 Fase 3 |

## F. Profesional

| # | Función | Para qué sirve | Esfuerzo | Valor | Estado |
|---|---------|----------------|----------|-------|--------|
| F1 | **Reporte PDF compartible** (perfil, resumen, pruebas, rangos, dolor y últimas sesiones). | Llevarlo a la consulta o enviarlo al kinesiólogo. | M | ★★★ | ✅ |
| F2 | Modo evaluador: varios pacientes en el mismo teléfono. | Evaluaciones en consulta o en terreno. | M | ★★★ | 📅 Fase 3 |
| F3 | Panel del profesional, asignación de planes, comentarios. | Seguimiento remoto. | L | ★★★ | 📅 Fase 3 |

## G. Sistema, IA y servidor

| # | Mejora | Para qué sirve | Esfuerzo | Valor | Estado |
|---|--------|----------------|----------|-------|--------|
| G1 | El servidor devuelve el **esqueleto muestreado** del video. | Permite E2. | S | ★★ | ✅ |
| G2 | El servidor acepta **objetivos personalizados** (mismas reglas que la app). | Coherencia entre vivo y video. | S | ★★ | ✅ |
| G3 | Especificación de ejercicios descargable desde el servidor. | Ajustar umbrales sin publicar la app. | S | ★★ | 📅 Fase 2 |
| G4 | Análisis de video asíncrono con cola de trabajos. | Escalar. | M | ★★ | 📅 Fase 6 |
| G5 | Telemetría de errores y rendimiento (cuadros por segundo). | Calidad en dispositivos reales. | S | ★★ | 📅 Fase 1 |
| G6 | Modelo aprendido sobre secuencias de puntos. | Detectar errores difíciles de expresar con reglas. | L | ★★★ | 📅 Fase 5 |

## H. Diseño y experiencia

| # | Mejora | Estado |
|---|--------|--------|
| H1 | Nueva pestaña **Entrenar** que reúne ejercicios, rutinas y evaluaciones. | ✅ |
| H2 | **Inicio rediseñado**: meta semanal, accesos rápidos, rutina sugerida, recomendaciones y aviso de perfil incompleto. | ✅ |
| H3 | **Ícono propio** de la app (Android adaptable y monocromo, iOS), dibujado con el mismo logo de la app. | ✅ |
| H4 | Animaciones: aviso "¡Logro desbloqueado!" en cualquier pantalla, trofeo al completar una rutina, contador de la prueba de 30 s y anillos de meta y descanso. | ✅ |
| H5 | Modo de alto contraste y textos grandes verificados con lector de pantalla. | 📅 Fase 1 |

---

## Orden de implementación sugerido para lo pendiente

1. **Fase 1 (pruebas en teléfono):** B8 recordatorios, G5 telemetría, H5 accesibilidad.
2. **Fase 2 (backend):** A6/A7 cuentas en la nube y foto, G3 especificación remota.
3. **Fase 3 (profesional):** F2 modo evaluador, F3 panel, E3 comparación, C5 cuestionarios.
4. **Fase 5 (más movimientos):** B6, B7, C4, G6.
5. **Fase 6 (escala):** G4.

## Cómo probar las funciones nuevas en un teléfono

1. Entrar con `usuario.prueba` / `1234` (o crear una cuenta y completar la configuración inicial).
2. **Entrenar → Rutinas →** "Activación diaria" → *Comenzar*: deja el teléfono apoyado y sigue las series.
3. **Entrenar → Evaluaciones →** "Sentarse y pararse 30 s" y "Goniómetro".
4. Al terminar, registra dolor y esfuerzo; en el resultado usa **Revisar movimiento**.
5. En el detalle de un ejercicio, **Qué detecta la IA → Personalizar** para ajustar tus objetivos.
6. **Progreso:** calendario, tendencias y logros. **Cuenta:** perfil, meta semanal, ajustes de
   entrenamiento y **Datos y privacidad** (reporte PDF, exportación, borrar datos, eliminar cuenta).

### Qué revisar especialmente en el teléfono

- Que la serie termine sola al llegar a las repeticiones y que el descanso avance a la siguiente.
- En la prueba de 30 s, que el conteo coincida con las veces que te pusiste de pie (cuenta también la
  última si al terminar el tiempo ya ibas más de la mitad del camino).
- En el goniómetro, que el ángulo cambie al mover la articulación con la cámara de costado.
- Que el esqueleto de la revisión coincida con el movimiento (frontal y trasera).

## Fuentes

- CDC STEADI, *Assessment: 30-Second Chair Stand* (valores bajo el promedio por edad y sexo, 60–94 años):
  [formulario del CDC](https://stacks.cdc.gov/view/cdc/157303/cdc_157303_DS1.pdf).
- Rangos articulares de referencia en adultos: American Academy of Orthopaedic Surgeons (hombro 180°,
  codo 150°, cadera 120°, rodilla 135°).
