# Quiz: Gestión y Optimización de Contenido

Este quiz evalúa tu comprensión de límites de tokens, optimización de precios, estrategias de chunking, prompt chaining y gestión de contexto. Resolverás problemas de optimización de costos, diseñarás estrategias de chunking efectivas y diseñarás cadenas de prompts multi-paso para tareas complejas.

---

### Pregunta 1

Tu aplicación de análisis de documentos procesa artículos de investigación de 15,000 tokens cada uno en promedio. La implementación inicial usa **GPT-5** ($0.025 input / $0.05 output por 1M tokens) para todo el procesamiento. Tras analizar patrones de uso descubres que el 70% de las tareas son extracciones simples de sección que podrían usar **GPT-5 mini** ($0.0008 input / $0.0012 por 1M tokens), mientras que solo el 30% requiere razonamiento complejo. ¿Qué estrategia de optimización ofrece el mejor balance costo/calidad?

- Cambiar completamente a GPT-5 mini para maximizar ahorros en todas las tareas.
- **Implementar selección dinámica de modelo enrutando tareas simples a GPT-5 mini y complejas a GPT-5.**
- Usar Claude Sonnet 4 para todas las tareas porque el context window mayor elimina la necesidad de chunking.
- Implementar chunking agresivo para bajar todos los papers a menos de 2,000 tokens para procesamiento más barato.

**Respuesta correcta:** Implementar selección dinámica de modelo.

**Explicación:** El 70% de tareas simples enviadas a GPT-5 mini ahorra ~97% en esos casos sin degradar calidad (son extracciones triviales). El 30% complejo mantiene la calidad de GPT-5. Cambiar todo a mini sacrifica calidad en el 30% crítico; usar Sonnet 4 para todo multiplica el costo; el chunking agresivo rompe la coherencia del paper. El **model routing** es el patrón óptimo cuando la carga de trabajo es heterogénea.

---

### Pregunta 2

Construiste un chatbot de soporte que referencia un manual de producto de 50 páginas. Los usuarios reportan que el bot no puede responder preguntas sobre pasos de troubleshooting que aparecen en secciones posteriores del manual. Tu implementación actual **trunca el manual al llegar al límite de tokens**. ¿Qué estrategia de chunking resuelve mejor el problema?

- Aumentar el context window para meter el manual completo en un solo prompt.
- Usar truncation simple pero empezando desde el final del documento en vez del inicio.
- **Implementar keyword density analysis para priorizar los chunks más relevantes a la query del usuario.**
- Partir el manual en chunks del mismo tamaño y procesarlos todos en cada query.

**Respuesta correcta:** Implementar keyword density analysis.

**Explicación:** El problema no es el tamaño total sino **qué** porción se envía. Priorizar por keyword density (o mejor aún, por similitud semántica con embeddings) recupera la sección relevante sin importar su posición física en el documento. Aumentar el context es caro y sufre *Lost in the Middle*; truncar desde el final solo invierte el bug; procesar todos los chunks en cada query es inviable económicamente. La solución correcta es **retrieval relevante**, no fuerza bruta.

---

### Pregunta 3

Tu cadena de análisis de documentos legales tiene tres pasos: **extraer cláusulas clave**, **analizar factores de riesgo**, **generar recomendaciones**. El tercer paso a veces produce recomendaciones genéricas que no se alinean con los riesgos específicos identificados en el paso dos. ¿Cuál es la causa más probable y la solución?

- El paso tres necesita más ejemplos en few-shot prompting para mostrar patrones de recomendación.
- **Gestión inadecuada del contexto entre pasos: el paso tres no recibe suficiente detalle del paso dos.**
- La cadena debería usar branching condicional según la severidad del riesgo en vez de procesamiento secuencial.
- Los límites de tokens están truncando el output del paso dos antes de que llegue al paso tres.

**Respuesta correcta:** Gestión inadecuada del contexto entre pasos.

**Explicación:** Outputs desalineados en una cadena casi siempre indican **pérdida de contexto entre eslabones**. Si el paso 3 recibe un resumen muy comprimido o solo las conclusiones del paso 2 sin los detalles concretos, no puede personalizar las recomendaciones. Few-shot no soluciona la falta de inputs; branching condicional es ortogonal; truncation sería un error distinto (produciría errores de API o cortes evidentes, no genericidad). La solución es **pasar los riesgos con detalle estructurado** (p.ej. JSON con `{riesgo, severidad, cláusula_fuente, impacto}`) al paso 3.

---

### Pregunta 4

Tu sistema de reportes financieros procesa 10,000 registros de transacciones diarios generando reportes de análisis. La implementación actual envía todos los registros a **Claude Sonnet 4** en una sola llamada a $3 input / $15 output por millón de tokens. Cada reporte cuesta aproximadamente $8.50. Tu manager quiere reducir costos en 60% manteniendo la calidad. ¿Qué enfoque es más viable?

- Cambiar a GPT-5 mini para todo el procesamiento para minimizar costo por token.
- Reducir el número de transacciones analizadas por reporte de 10,000 a 4,000.
- Usar chunking agresivo para procesar transacciones en lotes pequeños con GPT-5 mini.
- **Implementar caching para patrones de transacciones comunes y usar GPT-5 mini para categorización inicial, Claude Sonnet 4 solo para análisis complejo.**

**Respuesta correcta:** Caching + arquitectura híbrida (mini para categorizar, Sonnet solo para análisis complejo).

**Explicación:** Es la combinación de tres técnicas que suman: (1) **prompt caching** reutiliza prefijos estables con 90% de descuento, (2) **model routing** envía trabajo barato a GPT-5 mini, (3) **Sonnet 4 solo en lo complejo**. Cambiar todo a mini sacrifica la calidad del análisis financiero; reducir transacciones degrada el reporte directamente; chunking agresivo sin un buen router no reduce lo suficiente. La arquitectura híbrida con cache logra 60-70% de ahorro conservando la calidad del output final.

---

### Pregunta 5

Tu sistema de análisis de papers chunkea documentos partiendo cada 2,000 tokens sin considerar la estructura del documento. Los usuarios se quejan de que el análisis **pierde conexiones entre hallazgos relacionados** distribuidos en múltiples secciones. ¿Qué estrategia document-aware mejoraría más la calidad?

- Reducir el tamaño del chunk a 1,000 tokens para procesamiento más granular.
- Añadir 20% de overlap entre chunks para prevenir pérdida de información en bordes.
- **Chunkear por secciones semánticas (Introduction, Methods, Results) preservando el contenido completo de cada sección.**
- Implementar selección por prioridad para incluir solo las secciones más importantes.

**Respuesta correcta:** Chunking por secciones semánticas.

**Explicación:** La causa raíz es que el chunking arbitrario por tokens **rompe la estructura lógica** del paper, separando resultados de la metodología que los explica. Chunkear por secciones semánticas mantiene unidos los hallazgos con su contexto (Methods con Results, por ejemplo). Reducir el tamaño empeora el problema; añadir overlap mitiga bordes pero no resuelve la fragmentación semántica; priority-based descarta información potencialmente útil. La solución correcta es **respetar las fronteras naturales del documento** (document-aware chunking).

---

### Pregunta 6

Estás diseñando una cadena de prompts para análisis de competidores. La cadena debe: identificar competidores, analizar sus features, evaluar pricing, evaluar marketing, y luego sintetizar hallazgos. Durante las pruebas, el paso de síntesis tarda demasiado y a veces hace timeout. ¿Qué cambio arquitectónico aborda mejor el problema?

- **Convertir la cadena secuencial en branching donde el análisis de features, pricing y marketing ocurran en paralelo tras la identificación de competidores.**
- Reducir el número de competidores analizados en el primer paso para acelerar los subsiguientes.
- Combinar todos los pasos en un único prompt comprehensivo para eliminar overhead de la cadena.
- Añadir lógica condicional para saltar el análisis de marketing cuando features y pricing son suficientes.

**Respuesta correcta:** Convertir la cadena en branching paralela.

**Explicación:** Features, pricing y marketing son **tracks independientes** una vez identificados los competidores: no hay dependencia entre ellos. Paralelizarlos con `asyncio.gather` reduce la latencia end-to-end (de la suma a la máxima individual). Reducir competidores sacrifica cobertura; combinar todo en un prompt reproduce el problema original de atención dispersa y hace imposible el debug; saltar marketing elimina información valiosa. El patrón **map → branch → reduce** es el canónico para este tipo de análisis multi-dimensional.

---
