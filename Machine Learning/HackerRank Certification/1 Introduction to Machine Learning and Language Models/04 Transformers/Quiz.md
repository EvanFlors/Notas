# Quiz: Transformers

## ¿Qué es?

Preguntas de repaso sobre mecanismos de atención, arquitectura del Transformer y los tres patrones principales (encoder-only, decoder-only, encoder-decoder).

## ¿Por qué importa?

Validar que distingues *dónde* vive la atención, *por qué* su complejidad es O(n²) y *qué arquitectura* conviene a cada tarea evita gastar miles de dólares en el modelo equivocado antes de medir.

## ¿Cómo funciona?

Para cada pregunta: lee el escenario, elimina las opciones claramente incorrectas, elige la que mejor describe el mecanismo real. La respuesta correcta y su explicación aparecen después.

---

### Pregunta 1

Quieres detectar bugs sutiles que requieren comprensión contextual, como: *"Este método modifica directamente un objeto inmutable pasado como parámetro. La modificación en la línea 15 afecta la estructura de datos del caller de forma inesperada, violando el contrato de la función."*

¿Cómo ayudan específicamente los mecanismos de atención a detectar este tipo de bug contextual?

- **A.** La atención conecta la declaración del parámetro (línea 3) con la modificación directa (línea 15) para entender la violación del contrato.
- B. La atención procesa el código más rápido que el análisis secuencial.
- C. La atención reduce el uso de memoria comparado con otros enfoques de redes neuronales.
- D. La atención hace al modelo más interpretable para los desarrolladores.

**Respuesta correcta: A**

**Explicación:** La *self-attention* permite que cualquier token (p. ej. el nombre del parámetro en la línea 3) atienda directamente a cualquier otro token (la mutación en la línea 15), sin importar la distancia. Esta "lookup suave" es exactamente lo que permite capturar dependencias largas que las RNN/LSTM perdían. La velocidad (B) es un beneficio del paralelismo, pero no es *lo que* ayuda a detectar el bug. La memoria (C) es falsa: la atención es O(n²) en memoria, no reducida. La interpretabilidad (D) es parcial y controvertida (ver "Attention is not Explanation", Jain & Wallace 2019).

---

### Pregunta 2

Para revisión de código, ¿qué patrón de atención aporta más valor para detección de bugs?

- **A.** Self-attention dentro de funciones para entender flujo de datos y dependencias entre variables.
- B. Cross-attention entre archivos distintos para encontrar mismatches de API.
- C. Multi-head attention para procesamiento en paralelo de distintos aspectos del código.
- D. Sparse attention para procesamiento eficiente de codebases grandes.

**Respuesta correcta: A**

**Explicación:** La mayoría de bugs ocurren *dentro* de funciones (mutaciones, mal uso de variables, flujo de control incorrecto). La **self-attention** modela exactamente estas relaciones intra-función. Cross-attention (B) es útil para seq2seq, no típicamente aplicada entre archivos de código en un modelo estándar. Multi-head (C) y sparse (D) son optimizaciones estructurales, no patrones que *inherentemente* detecten bugs.

---

### Pregunta 3

Tu modelo transformer alcanza 87% de accuracy en detección de bugs con buena comprensión contextual. ¿Cuál es la siguiente capacidad más inmediatamente valiosa a añadir?

- A. Aumentar la accuracy a 95% con mejoras arquitecturales.
- B. Añadir soporte para más lenguajes de programación.
- **C.** Generar sugerencias específicas de corrección y mejoras de código.
- D. Reducir el tamaño del modelo para despliegue más rápido.

**Respuesta correcta: C**

**Explicación:** Con buena detección ya resuelta, lo que falta aportar valor al desarrollador es *qué hacer* con el bug. Pasar de **comprensión** (clasificación con encoder) a **generación** (con decoder) duplica la utilidad del producto. Mejorar accuracy del 87% al 95% (A) tiene rendimientos decrecientes. Más lenguajes (B) y menor latencia (D) son valiosos pero secundarios al salto de "detectar" a "corregir".

---

### Pregunta 4

Al aplicar transformers a análisis de código, ¿qué consideración arquitectural es más importante?

- A. Usar el modelo más grande posible para máxima accuracy.
- **B.** Balancear tamaño del modelo con velocidad de inferencia para mantener feedback en tiempo real al desarrollador.
- C. Enfocarse en interpretabilidad del modelo sobre performance.
- D. Optimizar para procesamiento por batches en vez de análisis individual.

**Respuesta correcta: B**

**Explicación:** Herramientas tipo autocompletado (Copilot, Cursor) necesitan responder en **<300ms** o el desarrollador pierde el flujo. Un modelo gigante que tarda 2s por sugerencia es inútil aunque sea más preciso. Esto empuja hacia modelos más pequeños, cuantizados (int8/int4), destilados, o técnicas como **speculative decoding**. Batch processing (D) rompe la interactividad.

---

### Pregunta 5

Tu transformer sobresale detectando bugs pero tiene problemas sugiriendo fixes. Esto indica que deberías:

- A. Entrenar el mismo modelo más tiempo con más datos de detección de bugs.
- B. Aumentar el tamaño del modelo para capturar patrones más complejos.
- **C.** Considerar que detección de bugs (comprensión) y generación de fixes requieren objetivos de entrenamiento distintos.
- D. Cambiar a una arquitectura de modelo completamente diferente.

**Respuesta correcta: C**

**Explicación:** **Detección** es un problema de clasificación/comprensión (natural para encoder-only con MLM). **Generación de código** es un problema autoregresivo (natural para decoder-only con next-token prediction). Son objetivos de pre-entrenamiento distintos. Soluciones típicas: usar un **encoder-decoder** (como T5/BART code-tuned), o combinar dos modelos especializados, o reentrenar con objetivo seq2seq. Más datos del mismo tipo (A) o más parámetros (B) no cambian el objetivo. Cambiar de arquitectura entera (D) es exagerado — basta ajustar el objetivo de entrenamiento.

---

### Pregunta 6 (bonus)

¿Por qué es necesario dividir los scores de atención por `√d_k` en la fórmula `softmax(Q·Kᵀ / √d_k)·V`?

- A. Para forzar que los pesos sumen 1.
- B. Para hacer la operación invariante a traslaciones.
- **C.** Para evitar que los productos escalares crezcan con `d_k` y saturen el softmax, lo que anularía los gradientes.
- D. Para hacer la atención permutation-invariant.

**Respuesta correcta: C**

**Explicación:** Si `Q` y `K` tienen entradas con varianza 1, su producto escalar tiene varianza aproximadamente `d_k`. Para `d_k = 64`, los scores pueden crecer a órdenes de ±8-10, metiendo al softmax en una región saturada donde `∂softmax/∂x ≈ 0`. Dividir por `√d_k` renormaliza la varianza a ≈1, manteniendo gradientes sanos. (A) lo hace el softmax, no `√d_k`. (B) y (D) son propiedades no relacionadas.

---

### Pregunta 7 (bonus)

Quieres construir un buscador semántico sobre 10 millones de documentos. ¿Qué arquitectura es la más adecuada para generar los embeddings?

- **A.** Encoder-only (BERT, DeBERTa, modelos sentence-transformers).
- B. Decoder-only (GPT-4, LLaMA).
- C. Encoder-decoder (T5, BART).
- D. Cualquiera, da lo mismo.

**Respuesta correcta: A**

**Explicación:** Los **encoder-only** producen representaciones bidireccionales ricas por token y son el estándar para embeddings (sentence-transformers, BGE, E5, GTE). Decoder-only (B) tiene embeddings sesgados por la causalidad del último token y es desproporcionadamente caro de servir. Encoder-decoder (C) es excesivo para producir embeddings. La elección sí importa (D): cambia el costo de inferencia en 100-1000× y la calidad del retrieval.

## Errores comunes

- **Elegir "la respuesta más técnica"** aunque no responda a la pregunta. Siempre vuelve a leer el escenario.
- **Confundir multi-head con multi-layer.** Las cabezas corren en paralelo dentro de una capa; las capas se apilan.
- **Asumir que "más grande siempre es mejor".** En producción, latencia y costo frecuentemente dominan sobre accuracy marginal.
- **Olvidar que la arquitectura determina el objetivo natural.** BERT no genera; GPT no es ideal para embeddings; T5 brilla en traducción.
- **Interpretar los pesos de atención como explicación causal.** Son señal débil, no prueba del "porqué" de la decisión.

## Resumen

- La **self-attention** conecta tokens distantes directamente → explica cómo los Transformers capturan dependencias largas (contrato de función en la línea 3 ↔ mutación en la línea 15).
- La elección de **arquitectura** (encoder-only / decoder-only / encoder-decoder) debe venir dirigida por la **tarea**: comprensión vs generación vs transformación.
- Métricas de producto como **latencia** y **costo** suelen pesar más que ganar 1-2 puntos de accuracy.
- El `/ √d_k` en la atención no es cosmético: es la diferencia entre que el modelo entrene o colapse.
- Detección (clasificación) y generación de fixes (seq2seq) requieren **objetivos de entrenamiento distintos** — no es cuestión de más datos o más parámetros del mismo tipo.
- Para **embeddings y búsqueda semántica**, los encoder-only siguen siendo la opción correcta en 2024-2026, aun en la era de los LLMs decoder-only gigantes.
