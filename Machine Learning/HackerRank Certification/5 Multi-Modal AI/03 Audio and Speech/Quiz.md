# Quiz: Audio y Voz

Estás construyendo un sistema de atención al cliente por voz para una compañía de telecomunicaciones. El sistema debe transcribir llamadas, generar respuestas habladas y mantener interacción en tiempo real. Procesas 5.000 llamadas diarias de 4 minutos en promedio, con clientes que tienen distintos acentos y ambientes ruidosos (calle, oficina, bebés llorando).

---

**1. Tu sistema atiende clientes en español, inglés y mandarín. Whisper puede autodetectar idioma, pero la precisión para los hablantes de español es menor de lo esperado. ¿Qué deberías hacer?**

- Confiar en la autodetección: está diseñada para manejar múltiples idiomas.
- Pedir al cliente que seleccione su idioma al inicio y pasarlo en el parámetro `language`.
- Transcribir en los tres idiomas y quedarse con el resultado de mayor confianza.
- Hacer fine-tune de Whisper con muestras de audio en español.

**Respuesta correcta: Pedir al cliente que seleccione su idioma al inicio y pasarlo en el parámetro `language`.**

**Explicación:** especificar el idioma explícitamente mejora significativamente la precisión, especialmente con habla acentuada o audio ruidoso. La autodetección gasta tokens y suele fallar en audios cortos, con code-switching o con mucho ruido. Fine-tune es desproporcionado como primera medida; transcribir en tres idiomas triplica el costo sin garantizar mejor resultado.

---

**2. Una llamada dura 25 minutos y excede el límite de 25 MB de la API de Whisper. ¿Cómo deberías manejarla?**

- Comprimir el audio a bitrate más bajo hasta que entre en el límite.
- Partir en chunks de ~10 minutos con pequeños solapes, transcribir cada uno y combinarlos.
- Transcribir solo los primeros 10 minutos como muestra representativa.
- Acelerar el audio 2× para que entre en el límite.

**Respuesta correcta: Partir en chunks de ~10 minutos con pequeños solapes, transcribir cada uno y combinarlos.**

**Explicación:** el chunking con solape de 1-2 s evita cortar palabras en los bordes, y pasar el final del transcript anterior como `prompt` mantiene coherencia de contexto entre chunks. Comprimir degrada WER; acelerar distorsiona el audio y empeora el reconocimiento; transcribir solo una parte descarta información del cliente.

---

**3. Necesitas generar respuestas de voz para: 1) saludos amistosos, 2) información de saldo, 3) alertas urgentes de fraude. ¿Cómo deberías seleccionar las voces?**

- Usar una sola voz consistente para reforzar el reconocimiento de marca en todos los escenarios.
- Usar voz cálida (`nova`/`shimmer`) para saludos, neutra (`alloy`) para información, autoritaria (`onyx`) para alertas.
- Dejar que el cliente elija su voz preferida en configuración.
- Usar la voz de generación más rápida para minimizar latencia.

**Respuesta correcta: Usar voz cálida (`nova`/`shimmer`) para saludos, neutra (`alloy`) para información, autoritaria (`onyx`) para alertas.**

**Explicación:** las características de la voz deben alinearse con el tono del mensaje. Una voz cálida genera cercanía al abrir, una neutra transmite datos sin cargarlos, y una grave señala urgencia. Una sola voz para todo pierde la señal emocional del mensaje; dejarlo al cliente genera inconsistencia; priorizar velocidad sacrifica experiencia donde no se necesita.

---

**4. Tu voice agent tiene una latencia total round-trip de 3 segundos (STT: 800 ms, LLM: 1500 ms, TTS: 700 ms). Los usuarios reportan que se siente "robótico y lento". ¿Cuál es la optimización más efectiva?**

- Usar `tts-1-hd` para que el audio suene más natural.
- Pre-generar las respuestas comunes en caché y hacer streaming del TTS mientras se genera.
- Añadir frases muletilla como "déjame revisar eso" mientras se procesa.
- Cambiar a un LLM más rápido aunque las respuestas sean de menor calidad.

**Respuesta correcta: Pre-generar las respuestas comunes en caché y hacer streaming del TTS mientras se genera.**

**Explicación:** cachear las frases que se repiten (muletillas, saludos, cierres) convierte muchos TTS en lookups instantáneos, y el streaming permite que el usuario empiece a oír audio antes de que el pipeline termine. Combinadas, bajan la latencia percibida más que cualquier intervención aislada. `tts-1-hd` **empeora** la latencia; los fillers ayudan pero sin cachear ni stream siguen sumando segundos; bajar la calidad del LLM afecta la experiencia pero deja pie el cuello de botella.

---

**5. Tu servicio de TTS falla ocasionalmente en horas pico, dejando a los clientes sin respuesta de audio. ¿Cuál es el mejor patrón de confiabilidad?**

- Reintentar hasta 5 veces con backoff exponencial.
- Reintentar con backoff y, si sigue fallando, degradar a respuesta en texto (o voz alternativa).
- Encolar las requests y procesarlas cuando el servicio se recupere.
- Pre-generar todas las respuestas posibles para evitar generación en runtime.

**Respuesta correcta: Reintentar con backoff y, si sigue fallando, degradar a respuesta en texto (o voz alternativa).**

**Explicación:** el retry con backoff cubre errores transitorios (429, 5xx puntuales), pero por sí solo no resuelve una caída prolongada del proveedor. El fallback (otra voz, otro proveedor, o texto en pantalla) garantiza que el cliente siempre reciba una respuesta, aunque sea degradada. Encolar deja al cliente esperando audio que puede llegar tarde o nunca; pre-generar todas las respuestas es imposible en un sistema conversacional dinámico donde se leen datos propios de cada cliente (saldo, nombre, número de ticket).
