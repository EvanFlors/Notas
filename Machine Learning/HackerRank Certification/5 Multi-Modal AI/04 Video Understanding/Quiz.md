# Quiz: Video Understanding

Estás construyendo un sistema de análisis de video para una empresa de medios. El sistema debe analizar videos subidos (desde clips de 30 segundos hasta documentales de 2 horas) para moderación de contenido, generación automática de capítulos y archivos de video buscables. Procesas 1,000 videos diarios usando la API Vision de gpt-4.1-mini extrayendo y analizando frames.

---

### Pregunta 1

Un video de review de producto de 10 minutos necesita marcadores de capítulo. El video tiene segmentos de talking-head, demos de producto y grabaciones de pantalla. ¿Qué estrategia de frame sampling deberías usar?

- Extraer 1 frame por segundo (600 frames en total) para máxima cobertura
- Extraer exactamente 10 frames equiespaciados a lo largo del video
- **Usar scene detection para extraer frames en transiciones visuales, complementado con intervalos regulares** ✅
- Extraer frames solo cuando el transcript de audio indique un cambio de tema

**Explicación:** Los capítulos coinciden naturalmente con **cambios de escena** (pasas de talking-head a demo a pantalla); scene detection los captura automáticamente. Pero las escenas estáticas largas también necesitan muestreo mínimo para no quedar "ciegas", de ahí los intervalos regulares complementarios. 600 frames a 1 fps es caro y redundante; 10 frames equiespaciados pierde transiciones; depender solo del audio ignora cambios visuales (ej. cambio de demo a pantalla sin que el narrador lo anuncie).

---

### Pregunta 2

Necesitas detectar cuándo un producto aparece por primera vez en un video de review. El producto aparece en diferentes momentos en diferentes videos. ¿Qué enfoque funciona mejor?

- Analizar cada frame independientemente y encontrar el primer frame que contiene el producto
- **Enviar todos los frames en una sola llamada preguntando al modelo cuándo el producto aparece de forma prominente por primera vez** ✅
- Usar búsqueda binaria: revisar el frame medio, luego buscar en la mitad anterior o posterior
- Entrenar un modelo custom de object detection para cada tipo de producto

**Explicación:** El **multi-frame prompting con razonamiento temporal** permite al VLM comparar la prominencia del producto entre frames y decidir cuál es el "primero" significativo. Analizar frame por frame pierde el contexto de "prominente" (puede aparecer de reojo antes). La búsqueda binaria asume monotonía que no se cumple en video. Entrenar un modelo custom por producto es inviable para un catálogo cambiante.

---

### Pregunta 3

Tu sistema de moderación revisa videos por violaciones de política. La mayoría de los videos (95%) son seguros, pero necesitas detectar violaciones rápidamente. ¿Cuál es el enfoque más cost-effective?

- Análisis completo con frames de alto detalle para cada video
- **Quick scan con frames de bajo detalle primero, análisis detallado solo para contenido flaggeado** ✅
- Muestreo aleatorio del 10% de los videos con análisis exhaustivo
- Analizar solo el primer y último frame de cada video

**Explicación:** La **estrategia de dos pasadas** aprovecha la distribución 95/5: el 95% paga solo el costo barato del quick scan (`detail=low`, pocos frames), mientras que solo el 5% activa el análisis caro (`detail=high`, frames flaggeados). El resultado es un ahorro de 80-90% vs análisis completo siempre. El muestreo aleatorio deja pasar violaciones; mirar solo primer/último frame es claramente insuficiente.

---

### Pregunta 4

Quieres hacer los videos buscables por contenido (por ejemplo, "muéstrame videos donde alguien demuestra una técnica de cocina"). ¿Qué deberías indexar?

- Solo el título y descripción del video provistos por los uploaders
- Descripciones frame-por-frame de cada frame extraído
- **Resumen de video, tópicos, entidades y descripciones de escenas con timestamps** ✅
- Embeddings crudos de frames para búsqueda por similitud vectorial

**Explicación:** Un **índice comprehensivo** (`{summary, topics, entities, scenes}`) habilita búsqueda semántica sin almacenar gigabytes de embeddings ni descripciones por frame. Los metadatos del uploader son incompletos o engañosos. Descripciones por frame generan ruido y costo de almacenamiento. Los embeddings crudos funcionan pero son más caros y menos interpretables para debugging; el enfoque de resumen+topics+entities es el sweet spot entre expresividad y practicidad.

---

### Pregunta 5

Un documental de 2 horas necesita análisis completo. Procesar todos los frames de una vez excede los límites de contexto de la API. ¿Cuál es el mejor enfoque?

- Muestrear solo 20 frames distribuidos uniformemente a lo largo de 2 horas
- **Procesar en segmentos de 10 minutos, luego usar otra llamada para sintetizar los resúmenes de segmentos** ✅
- Extraer el transcript de audio y saltar el análisis visual por completo
- Aumentar el timeout de la API y enviar todos los frames en un request muy grande

**Explicación:** El **análisis jerárquico** (segmentos de 10 min analizados en detalle + síntesis final) preserva la granularidad local sin exceder los límites de contexto. 20 frames en 2 horas son 1 frame cada 6 minutos: eventos enteros desaparecen. Saltar el video pierde información visual crucial de un documental. Enviar todo en un request es imposible: el límite de contexto del modelo es fijo (no depende del timeout), y además costaría una fortuna.
