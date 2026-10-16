# Ejemplo 02 — Plantilla de encuesta SPACE trimestral

Esta plantilla es una **referencia concreta** de encuesta SPACE que un platform team puede enviar trimestralmente a los stream-aligned teams que lo consumen. 20 preguntas, 5 bloques (uno por dimensión), ~10 minutos para responder.

## Diseño

- **Mezcla de escala Likert + abiertas**: ni todo cuantitativo (gameable) ni todo cualitativo (incomparable entre trimestres).
- **Anónima** por defecto, con opt-in a identificarse para follow-up 1:1.
- **Pregunta sobre la plataforma, no sobre el equipo del encuestado**: enfoca al proveedor, no al cliente.
- **Repetir las mismas preguntas trimestre tras trimestre**: la señal es la **tendencia**, no el valor absoluto.

Archivos:

- `survey.yaml` — las 20 preguntas estructuradas (lo que un formulario o API consumiría).
- `README.md` — este archivo, con guía de uso e interpretación.

## Cómo leer los resultados

Para cada dimensión:

- **Media + mediana** de las preguntas Likert.
- **Trend vs trimestre anterior**: ±0.5 puntos ya es relevante.
- **Clustering de respuestas abiertas** (3–5 clusters manuales por dimensión).

Reglas de la casa:

1. **Nunca se reporta una dimensión aislada**: siempre al menos 3.
2. **La dimensión A (Activity) nunca es el titular**: es la más fácil de medir y la más fácil de abusar.
3. **Lee las respuestas abiertas antes de leer los números.** Los números te dicen qué cambió; las abiertas te dicen por qué.
4. **Un drop grande en S (Satisfaction) desbloquea un retro extraordinario**, no un plan de "mejora de métrica".

## Follow-up

Los 3 detractores (NPS 0–6) y los 3 promotores (NPS 9–10) **que se identificaron** reciben un 1:1 de 30 min dentro de las 2 semanas de cerrada la encuesta. Las dos preguntas son las mismas:

- "Cuéntame la última vez que algo en la plataforma te frustró. ¿Qué pasó?"
- "¿Qué haces hoy a mano que te gustaría que la plataforma hiciera por ti?"

## Antipattern a evitar

- Enviar la encuesta y nunca mostrar el resultado agregado a los encuestados → **la próxima tasa de respuesta se desploma**.
- Enviarla el mismo día del release de la plataforma → sesgo por el último evento.
- Cambiar las preguntas cada trimestre → pierdes la línea base.

## Siguiente

Ver `../03-platform-product-roadmap/` para cómo convertir el aprendizaje de la encuesta en roadmap.
