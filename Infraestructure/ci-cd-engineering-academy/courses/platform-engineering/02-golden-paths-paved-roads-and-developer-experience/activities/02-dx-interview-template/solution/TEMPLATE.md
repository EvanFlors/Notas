# DX Interview Template — plat-02 (REFERENCIA)

> **Referencia** de plantilla. No es la única forma correcta — es un modelo contra el que compararte.

## 1. Metadatos

- **Fecha:** YYYY-MM-DD
- **Participante:** <nombre>, <rol>, <equipo>
- **Entrevistador:** <nombre> (DRI del feedback loop)
- **Duración objetivo:** 35 min (rango 30–45)
- **Consentimiento:** notas tomadas por el entrevistador; se comparten anonimizadas en el reporte trimestral; sin grabación salvo acuerdo explícito.
- **Canal:** videoconferencia (preferido) o presencial.

## 2. Rapport (3 min)

Preguntas blandas, cámara/café en mano:

- "¿Cómo va la semana? ¿Algo que esté quemando?"
- "¿Qué estás tocando esta sprint?"

Objetivo: bajar la guardia; no tomar notas aún.

## 3. Contexto (5 min)

- Equipo y rol actual.
- Antigüedad en la empresa / en el equipo.
- Servicios tocados en los últimos 30 días.
- Último servicio nuevo creado (si aplica) y por qué path.

## 4. Preguntas (20–25 min)

Mínimo 6 preguntas abiertas, en este orden sugerido:

1. "Cuéntame **tu último scaffolding** desde el click al primer deploy. Paso a paso. ¿Dónde dudaste o paraste a buscar algo?"
2. "Dime un momento del **último mes** en el que la plataforma te **frustró**. ¿Qué pasó, qué esperabas, qué hiciste?"
3. "¿Hubo alguna vez en que decidiste **salirte** del golden path? ¿Qué te empujó fuera y qué asumiste al hacerlo?"
4. "Cuando algo no funciona del path y necesitas ayuda, ¿dónde buscas primero (docs, Slack, un compañero, un ticket)? ¿Por qué ese orden?"
5. "Si pudieras **quitar una cosa** del path (un paso, una herramienta, una convención) para que tu día fuera más fácil, ¿cuál sería y por qué?"
6. "¿Qué cosa del path te ha **sorprendido para bien** en los últimos 90 días? Algo donde pensaste 'qué bien que esto funcione así'."
7. (Opcional) "Si fueras tú quien decide el próximo golden path para tu equipo (más allá del microservicio Python), ¿cuál sería y por qué?"

Guía al entrevistador:

- **No** interrumpir en los primeros 20 segundos de cada respuesta.
- Reformular con "lo que te oí decir es… ¿lo entendí bien?".
- Pedir **ejemplos concretos** si la respuesta se vuelve abstracta ("¿en qué servicio exactamente?").
- Nunca defender la plataforma durante la entrevista. Solo escuchar.

## 5. Cierre (3–5 min)

- Resumir en 2–3 bullets lo que te llevas.
- Preguntar: "¿Hay algo que **no** te he preguntado y querías contarme?"
- **Compromisos del entrevistador:** nombra 1–2 cosas concretas que harás a raíz de la conversación (p. ej. "voy a revisar el error X del scaffolder", "lo subo al próximo backlog grooming").
- **Próximo paso:** cómo volverás con una respuesta (Slack DM dentro de 2 semanas, mención en el próximo update de plataforma, etc.).

## 6. Método

### Muestreo

- **Universo:** developers que han tocado microservicios creados en los últimos 90 días.
- **Tamaño:** 5 por iteración.
- **Estratificación:**
  - 2 developers de equipos de **alto uso** del path.
  - 2 developers de equipos de **bajo uso** del path (long tail).
  - 1 developer que haya **ido off-road** explícitamente.
- **Sesgo evitado:** no muestrear solo "los que levantan la mano" ni solo los veteranos. Sorteo acotado dentro de cada estrato.

### Cadencia

- **Trimestral** (5 entrevistas / trimestre).
- Semana 2 del trimestre: muestreo + agenda. Semana 3: entrevistas. Semana 4: análisis + reporte interno.

### Responsable

- **DRI:** <nombre> — Platform Lead o PM de plataforma (persona concreta, no "el equipo").
- Rotación opcional entre miembros del platform team para evitar sesgo del entrevistador.

### Triangulación

Las entrevistas **no sustituyen** telemetría ni survey. Se cruzan:

| Fuente | Qué contesta |
|--------|--------------|
| **Telemetría** (scaffolder, catalog, CI) | ¿**Dónde** duele? (dónde fallan los pasos, dónde abandonan) |
| **Survey** (Platform NPS + Likert) | ¿**Cuánto** duele y a cuántos? |
| **Entrevistas DX** | ¿**Por qué** duele y qué hacer? |

Reportamos los tres **en el mismo documento trimestral**. Un hallazgo cualitativo sin señal cuantitativa queda marcado como *hipótesis*, no como *decisión*.

## 7. Anexo — rubric de notas (opcional)

Para cada entrevista, clasificar hallazgos en:

- **Fricción** (algo que ralentiza): descripción + severidad 1–3.
- **Delight** (algo que funciona bien): descripción.
- **Bloqueo** (algo que impide avanzar): descripción + # de intentos.
- **Deseo** (algo que les gustaría tener): descripción + prioridad del participante.

Al final del trimestre, agregar por categoría y ordenar por frecuencia y severidad.
