# Quiz: Aplicaciones multimodales

Estás diseñando un asistente de IA multimodal para una empresa de servicio en campo. Los técnicos usan dispositivos móviles para fotografiar problemas en equipos, grabar notas de voz sobre los problemas y recibir guía diagnóstica generada por IA con imágenes e instrucciones habladas. El sistema procesa 2.000 solicitudes diarias a través de las modalidades de visión, audio y texto, con requisitos estrictos de tiempo de respuesta (bajo 5 segundos) y confiabilidad (99,9% de uptime).

---

**Pregunta 1.** Tu base de conocimiento contiene manuales de equipo (PDFs), videos de procedimientos de reparación y fotografías de solución de problemas. Un técnico pregunta: "¿Cómo reemplazo el filtro en el modelo X450?" ¿Qué estrategia de recuperación deberías usar?

**Explicación:** Esta es una pregunta clásica de multi-modal RAG. El técnico necesita pasos escritos (texto del manual), referencia visual del componente (fotos) y confirmación del procedimiento (video). Limitar la búsqueda a una sola modalidad reduce la utilidad; devolver solo video obliga al técnico a esperar y buscar el momento exacto; no usar retrieval abre la puerta a alucinaciones sobre un modelo específico.

- Buscar solo documentos de texto porque la pregunta está basada en texto.
- **Buscar en todas las modalidades y devolver una mezcla relevante de texto, imágenes y clips de video.** ✅
- Devolver solo resultados de video porque los procedimientos de reparación se muestran mejor visualmente.
- Generar una respuesta nueva sin recuperación porque la pregunta es sencilla.

**Correcto.** La recuperación multimodal entrega guía integral: texto para los pasos y foto/video como referencia visual, con las fuentes citadas para que el técnico pueda profundizar.

---

**Pregunta 2.** Un técnico envía una foto de un panel de control que no funciona y pide ayuda. El agente puede responder con texto, un diagrama generado o instrucciones habladas. ¿Qué debería determinar la modalidad de la respuesta?

**Explicación:** La modalidad de salida no se elige por simetría ni por maximizar un único eje (densidad informativa). Depende del **contexto del usuario**: si tiene las manos ocupadas, el audio gana; si debe seguir una secuencia larga, el texto permite re-leer; si debe identificar un componente, una imagen anotada es insustituible. Dejar que el LLM decida sin reglas lleva a comportamiento impredecible y caro.

- Siempre responder con la misma modalidad que usó el usuario (foto → respuesta en imagen).
- Siempre usar texto para máxima densidad de información.
- **Considerar el contexto: texto para pasos detallados, audio si las manos están ocupadas, imágenes para guía visual.** ✅
- Dejar que el LLM decida la modalidad de respuesta autónomamente.

**Correcto.** La modalidad óptima depende del tipo de contenido y de la situación del técnico; en campo esto suele determinarse por una señal explícita del cliente o por el tipo de tarea.

---

**Pregunta 3.** Tu sistema necesita procesar una solicitud que requiere: 1) transcribir una nota de voz, 2) analizar una foto del equipo, 3) generar una respuesta, 4) convertir la respuesta a voz. ¿Qué patrón de arquitectura minimiza la latencia?

**Explicación:** La regla general es: **paraleliza operaciones independientes, serializa las dependientes**. La transcripción (STT) y el análisis de la foto son independientes entre sí: ninguno depende de la salida del otro. La generación de la respuesta depende de ambos, por lo tanto debe esperar a los dos. El TTS depende de la respuesta generada. Batching diferido mata el SLA de 5 s; omitir modalidades degrada la calidad diagnóstica.

- Procesamiento secuencial: transcribir → analizar → generar → hablar.
- **Procesamiento paralelo de inputs (transcribir + analizar simultáneamente), luego generar, luego hablar.** ✅
- Agrupar todas las solicitudes y procesarlas juntas cada 30 segundos.
- Omitir la transcripción de audio y analizar solo la imagen para ahorrar tiempo.

**Correcto.** Paralelizar operaciones independientes (STT y visión) con `asyncio.gather` o workers concurrentes reduce la latencia total casi a la mitad en este pipeline.

---

**Pregunta 4.** Los costos de tu sistema multimodal son 60% API de visión, 25% APIs de audio, 15% generación de texto. Necesitas reducir el presupuesto 30% sin impacto mayor en calidad. ¿Qué deberías optimizar primero?

**Explicación:** El principio de **Amdahl aplicado a costos**: optimiza primero el componente que domina el gasto. Reducir el 15% a cero solo recorta 15%; eliminar audio es destrozar la UX; limitar a 5 requests/día rompe el producto. Los dos ataques con mejor ROI en visión son: bajar el *detail level* a `low` cuando no se necesita (ahorro ~70% de tokens de imagen) y cachear por hash para no re-procesar fotos duplicadas (en campo los técnicos re-fotografían el mismo equipo).

- Reducir la calidad de generación de texto porque es el componente de menor costo.
- **Optimizar costos de visión: usar detalle bajo donde sea apropiado, cachear análisis de imágenes repetidas.** ✅
- Reemplazar todo el audio con interfaces de solo texto.
- Limitar a los usuarios a 5 solicitudes por día para reducir el volumen.

**Correcto.** 60% del costo significa que optimizar visión tiene el mayor impacto. Ajustar el nivel de detalle y agregar caché puede recortar fácilmente 30-40% del gasto sin que el usuario lo note.

---

**Pregunta 5.** Durante una caída de la API de visión, los técnicos no pueden obtener diagnósticos basados en fotos. ¿Cuál es el mejor diseño de fallback?

**Explicación:** El principio es **degradación graciosa**: cuando una modalidad falla, el sistema sigue entregando valor en otra. Mostrar error y pedir reintentar deja al técnico varado; encolar las imágenes puede ser válido como complemento, pero no resuelve el ahora; escalar todo a humanos no escala y es carísimo. Caer a texto implica pedir al técnico que describa síntomas y responder con el conocimiento del manual + razonamiento del LLM; es peor que con foto pero sigue siendo útil.

- Mostrar mensaje de error y pedir a los técnicos que reintenten más tarde.
- **Caer a solución de problemas basada en texto usando descripciones de síntomas en lugar de fotos.** ✅
- Encolar las solicitudes de análisis de fotos hasta que la API de visión se recupere.
- Escalar automáticamente todas las solicitudes a soporte humano durante las caídas.

**Correcto.** La degradación graciosa a diagnóstico basado en texto es menos óptima que con foto, pero sigue entregando valor y mantiene el servicio operativo mientras el proveedor se recupera.
