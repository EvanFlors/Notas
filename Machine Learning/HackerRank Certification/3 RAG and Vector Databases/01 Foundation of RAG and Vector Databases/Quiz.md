# Quiz: Fundamentos de RAG y Vector Databases

**Escenario:** Tu empresa construye un chatbot de atención al cliente que debe responder preguntas sobre funcionalidades del producto, políticas de reembolso y documentación técnica. El equipo evalúa usar RAG, fine-tuning o un enfoque híbrido.

---

### Pregunta 1

**¿Por qué RAG es preferible sobre fine-tuning para este chatbot de atención al cliente?**

- Las respuestas de RAG son más rápidas que las de modelos fine-tuneados.
- **RAG permite actualizar fácilmente cuando cambian las políticas sin necesidad de reentrenar.** ✅
- RAG usa menos recursos computacionales en general.
- RAG ofrece mejores capacidades de razonamiento.

**Explicación:** Las políticas de reembolso, los precios y la documentación cambian con frecuencia. Con RAG basta con **re-indexar los documentos modificados** en la vector DB (segundos o minutos) y el sistema ya responde con la información nueva. Con fine-tuning tendrías que reentrenar el modelo (horas, GPUs, costo alto) cada vez que una política cambia. RAG no es necesariamente más rápido en latencia (de hecho añade retrieval, ~100-500 ms), ni consume menos cómputo (hace múltiples API calls: embed + search + generate), ni "razona mejor" (eso depende del LLM base). Su ventaja decisiva en este dominio es la **actualización incremental y barata del conocimiento**.

---

### Pregunta 2

**El equipo nota que el chatbot afirma con confianza plazos de reembolso incorrectos. ¿Qué componente de RAG abordaría esto?**

- Usar un modelo de embeddings más potente.
- **Recuperar documentos verificados de política antes de generar respuestas.** ✅
- Aumentar el parámetro de temperatura del LLM.
- Hacer fine-tuning del modelo con datos de la empresa.

**Explicación:** El problema descrito es una **alucinación**: el LLM inventa plazos porque los generó desde sus pesos sin tener acceso al documento real. La solución medular de RAG es **grounding**: antes de responder, el sistema recupera los chunks relevantes de la política de reembolsos (p. ej. `refunds.md`) y los inyecta como contexto en el prompt. El LLM entonces responde **con base en texto verificado**, y un buen prompt le pide citar fuentes. Un embedder mejor podría mejorar la **recuperación**, pero el componente que elimina la alucinación es el **retrieval + grounding**. Subir la temperatura empeora el problema (más creatividad = más invención). Fine-tuning tampoco resuelve alucinaciones estructurales en información cambiante.

---

### Pregunta 3

**El sistema usa `all-MiniLM-L6-v2` para embeddings durante la indexación. Un desarrollador quiere cambiar a `all-mpnet-base-v2` para mejor precisión. ¿Qué se debe hacer?**

- Re-embeber solo los documentos nuevos con el nuevo modelo.
- **Re-embeber todos los documentos existentes con el nuevo modelo.** ✅
- Aplicar una función de conversión a los embeddings viejos.
- Usar ambos modelos y promediar sus scores de similitud.

**Explicación:** Cada modelo de embeddings aprende su **propio espacio vectorial** durante entrenamiento. Los 384 dims de MiniLM y los 768 dims de mpnet **no son comparables**: ni siquiera tienen la misma dimensionalidad, y aunque la tuvieran, cada componente significa algo distinto en cada modelo. No existe una "función de conversión" universal entre espacios de embeddings (se puede entrenar un *projector* pero rara vez vale la pena). Promediar scores de dos modelos sobre vectores incompatibles produce basura. La única opción correcta es **re-embeber todo el corpus** con el modelo nuevo, actualizar la configuración de la vector DB (dimensionalidad, métrica) y usar el modelo nuevo también para las queries. Regla de oro: **mismo modelo para ingesta y query, siempre**.

---

### Pregunta 4

**Al buscar "política de reembolso", el sistema recupera documentos sobre "devoluciones y cambios" con alta similitud a pesar de usar palabras distintas. ¿Qué lo hace posible?**

- La vector DB usa fuzzy string matching.
- **Los embeddings colocan conceptos semánticamente similares cerca en el espacio vectorial.** ✅
- El LLM expande la query para incluir sinónimos.
- El sistema mantiene un diccionario manual de sinónimos.

**Explicación:** El poder de los embeddings es capturar **significado** y no solo letras. Durante entrenamiento con contrastive learning, el modelo aprendió que frases que aparecen en contextos similares ("reembolso", "devolución", "money back", "refund") deben mapearse a **vectores cercanos** en `ℝᵈ`. Al medir con cosine similarity, "política de reembolso" y "devoluciones y cambios" dan un valor alto (~0.8) aunque no compartan tokens. Esto es **búsqueda semántica**, radicalmente distinta del fuzzy matching (que opera sobre edición de caracteres) o de diccionarios manuales de sinónimos (frágiles, no escalables, no capturan paráfrasis complejas). La query expansion con LLM existe como técnica complementaria (HyDE, multi-query), pero no es lo que explica este match: la embedding ya **codifica** el significado antes de cualquier expansión.

---

### Pregunta 5

**Tu sistema RAG indexa 1 millón de vectores de 768 dimensiones. La búsqueda aproximada con HNSW devuelve resultados en 50 ms con 97% de recall. ¿Por qué usar búsqueda aproximada en vez de exacta?**

- La búsqueda aproximada usa menos memoria que la exacta.
- **La búsqueda exacta tardaría varios segundos por query.** ✅
- La búsqueda aproximada ofrece mejor comprensión semántica.
- La búsqueda exacta no puede manejar vectores de alta dimensión.

**Explicación:** La búsqueda **exacta** (brute force) calcula la similitud entre la query y **cada uno** de los n vectores: complejidad `O(n·d)`. Para 1M vectores × 768 dims eso son ~768 millones de multiplicaciones por query, lo que en CPU típica tarda **cientos de milisegundos a varios segundos** — inviable para producción con usuarios concurrentes. Los índices ANN como **HNSW** construyen un grafo navegable que permite llegar a los vecinos aproximados en **log(n)** saltos, obteniendo latencias de ~10-50 ms con recall >95%, es decir **100x más rápido** sacrificando ~3% de precisión. HNSW de hecho **usa más memoria** (todo el grafo en RAM), no menos; la comprensión semántica depende del **embedder**, no del índice; y la búsqueda exacta sí maneja altas dimensiones (solo es lenta). El trade-off real que motiva ANN es **latencia a cambio de un recall casi perfecto**.

---

## Resumen de conceptos clave

- **RAG se elige cuando el conocimiento cambia**; fine-tuning cuando el comportamiento (estilo, formato, razonamiento) debe cambiar.
- **El grounding en documentos recuperados** es lo que previene alucinaciones, no el embedder ni la temperatura.
- **Nunca mezcles modelos de embeddings**: cada uno define su propio espacio vectorial. Al migrar, re-indexa todo.
- **Los embeddings capturan significado**, no letras: por eso "reembolso" y "devolución" quedan cerca.
- **ANN (HNSW/IVF/LSH) es obligatorio a escala**: brute force es `O(n·d)` y colapsa con millones de vectores.
