# Quiz: Retrieval Strategies and Query Optimization

Contexto: tu equipo construye un sistema de búsqueda sobre la documentación técnica de una empresa de software. Los usuarios buscan endpoints de API, ejemplos de código y guías de troubleshooting. El sistema debe manejar tanto términos técnicos exactos como preguntas en lenguaje natural.

---

### Pregunta 1

Un usuario busca `"API authentication"` pero el dense retrieval **no** devuelve documentos que contienen el nombre exacto del endpoint `auth/v2/token`. ¿Qué enfoque capturaría esos documentos?

- Usar un modelo de embeddings más grande con más dimensiones.
- **Añadir sparse retrieval (TF-IDF o BM25) para coincidencia por keywords.** ✅
- Aumentar el número de documentos recuperados.
- Hacer fine-tuning del modelo de embeddings con términos técnicos.

**Explicación:** Los embeddings densos tienden a perder *tokens exactos* raros como nombres de endpoint, códigos de error o SKUs porque esos tokens aparecen poco en el corpus de pre-entrenamiento. BM25 / TF-IDF opera por coincidencia léxica exacta y es el complemento natural. Un modelo más grande o fine-tuning ayudan, pero son caros y lentos de iterar; añadir sparse en paralelo (hybrid) es la solución estándar y suele subir el NDCG de inmediato.

---

### Pregunta 2

Comparando vectores de query y documento, cosine similarity devuelve `0.85` y Euclidean distance devuelve `0.3`. ¿Por qué cosine similarity es preferida para retrieval de texto?

- Cosine similarity es más rápida de calcular.
- **Cosine similarity ignora la magnitud del vector y se enfoca en la dirección.** ✅
- Euclidean distance no puede manejar vectores de alta dimensionalidad.
- Cosine similarity proporciona mejor comprensión semántica.

**Explicación:** Documentos largos producen vectores con mayor magnitud; cosine normaliza por `||A||·||B||` y mide solo el **ángulo** entre vectores → el significado, no el tamaño. Así evitas el sesgo hacia textos largos y obtienes rankings consistentes para chunks de distinto tamaño. Si los embeddings están normalizados (`||v||=1`), cosine y dot product son equivalentes y el dot product es más rápido.

---

### Pregunta 3

El equipo divide una documentación de API de 5,000 palabras en segmentos de 200 palabras **sin overlap**. Los usuarios reportan que falta información sobre rate limiting que **cae justo en los bordes** de los chunks. ¿Qué hay que hacer?

- Reducir el chunk size a 100 palabras.
- **Implementar un overlap del 10-20% entre chunks consecutivos.** ✅
- Usar semantic chunking en vez de chunks de tamaño fijo.
- Aumentar el chunk size a 500 palabras.

**Explicación:** El overlap duplica la información cerca de los bordes para que un concepto partido entre dos chunks aparezca completo en al menos uno de ellos. Un overlap de 10-20% (ej. 20-40 palabras sobre 200) es el estándar y mejora el recall sin inflar demasiado el índice. Semantic chunking también ayuda, pero es más caro y no resuelve directamente este problema; cambiar el tamaño sin overlap no evita el corte.

---

### Pregunta 4

Un pipeline RAG tarda 2 segundos por consulta: 50 ms de embedding, 100 ms de retrieval, 1,800 ms de generación LLM, 50 ms de formateo. ¿Dónde hay que enfocar la optimización?

- Optimizar la generación de embeddings cacheando queries comunes.
- **Optimizar la generación del LLM usando streaming o modelos más pequeños.** ✅
- Optimizar el retrieval cambiando HNSW por un índice flat.
- Optimizar todos los componentes por igual.

**Explicación:** La ley de Amdahl: la generación LLM es el 90% de la latencia (1800/2000). Reducirla al 50% (900 ms) ahorra 900 ms totales; mejorar el embedding al 0 ms solo ahorra 50 ms. Opciones prácticas: streaming (el usuario percibe TTFB más corto), modelo más pequeño (gpt-4o-mini vs 4o), prompt más corto, respuestas con `max_tokens` limitado, caching semántico de respuestas. Cambiar HNSW por flat **empeoraría** el retrieval en escala.

---

### Pregunta 5

Un pipeline RAG recupera documentos con similarity scores de `0.42`, `0.39` y `0.35`. La respuesta generada es vaga y genérica. ¿Cuál es la causa más probable?

- El modelo LLM es muy pequeño y necesita upgrade.
- **Los documentos recuperados tienen baja relevancia respecto a la query.** ✅
- La ventana de contexto es muy pequeña para el LLM.
- La base de datos vectorial necesita reindexación.

**Explicación:** Scores por debajo de 0.5 (con modelos como `all-MiniLM` o `text-embedding-3`) indican *weak matches*: el retriever devolvió lo mejor que encontró, pero lo mejor no es suficientemente bueno. El LLM, al no tener contexto relevante, responde con generalidades o alucina. Soluciones típicas: mejorar el chunking, añadir sparse/hybrid, aplicar query expansion o HyDE, añadir un cross-encoder reranker, revisar que el corpus realmente contenga la respuesta.
