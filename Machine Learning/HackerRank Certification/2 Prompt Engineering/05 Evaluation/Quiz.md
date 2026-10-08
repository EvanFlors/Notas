# Quiz: Evaluation

Este quiz evalúa tu comprensión de los métodos de evaluación de sistemas de IA generativa: métricas tradicionales (BLEU, ROUGE, cosine similarity), LLM-as-a-Judge, diseño de judge prompts y multi-judge systems. Necesitarás identificar cuándo cada enfoque es apropiado y cómo diseñar sistemas de evaluación confiables.

---

### Pregunta 1

Tu sistema de generación de contenido produce documentación técnica. Las métricas BLEU tradicionales muestran alto rendimiento (0.85), pero los usuarios se quejan de que la documentación no les ayuda realmente a resolver problemas. ¿Cuándo aporta más valor cambiar a LLM-as-a-Judge?

- Cuando necesitas una evaluación más rápida que procese miles de documentos por minuto
- **Cuando necesitas evaluar cualidades semánticas como utilidad y claridad que BLEU no puede capturar**
- Cuando necesitas reproducibilidad exacta entre corridas de evaluación
- Cuando quieres reducir costos eliminando por completo a los revisores humanos

**Respuesta correcta**

**Explicación:** BLEU mide solapamiento de n-gramas, es decir, qué tanto se parecen las palabras y frases entre el output y una referencia. No tiene forma de medir si el contenido *resuelve el problema* del usuario, si está bien estructurado para la tarea, o si tiene el tono adecuado. Un LLM-as-a-Judge sí puede evaluar esas cualidades semánticas y pragmáticas aplicando una rúbrica con dimensiones como "helpfulness" o "actionability". No es más rápido ni más barato que BLEU (de hecho es mucho más caro), tampoco más reproducible, y no reemplaza a los humanos: los complementa.

---

### Pregunta 2

Construiste un judge prompt para evaluar respuestas de atención al cliente por "calidad". Las pruebas iniciales muestran alta variabilidad: la misma respuesta recibe scores de 2 a 5 entre distintas corridas. ¿Cuál es la causa raíz más probable y la solución?

- La temperatura está muy alta, causando variación aleatoria en el output del juez
- **Los criterios de evaluación son vagos y carecen de definiciones específicas, medibles y de ejemplos de calibración**
- Al modelo juez le faltan datos de entrenamiento suficientes para evaluar atención al cliente
- El judge prompt debería incluir ejemplos few-shot de respuestas de alta calidad

**Respuesta correcta**

**Explicación:** La palabra "calidad" es la enemiga número uno de los judge prompts. Es subjetiva, no observable y cada evaluación puede interpretarla distinto. La solución canónica es descomponerla en 3-5 dimensiones concretas (helpfulness, accuracy, tone), definir cada nivel de la escala (1-5) con descripciones operacionales, e incluir anchors: ejemplos concretos de qué luce como score 5, score 3 y score 1 con su justificación. Esto garantiza consistencia. La temperatura es relevante (debe ser 0), pero bajarla sola no resuelve una rúbrica ambigua; los jueces siguen alucinando criterios distintos cada vez.

---

### Pregunta 3

Tu golden dataset para un sistema de análisis de documentos legales se creó hace 18 meses. Los logs de producción muestran que el sistema funciona bien contra los ejemplos del dataset, pero los usuarios reportan insatisfacción creciente. ¿Cuál es el problema más probable?

- El golden dataset carece de diversidad suficiente en tipos de documento y niveles de complejidad
- Las métricas BLEU y ROUGE no son apropiadas para análisis de documentos legales
- **Reference data staleness: los estándares legales y las expectativas de los usuarios han evolucionado desde la creación del dataset**
- El sistema necesita evaluación multi-judge en lugar de comparación con un golden set único

**Respuesta correcta**

**Explicación:** Un golden set es una fotografía de la calidad esperada en el momento en que se creó. Los estándares legales cambian (nuevas regulaciones, jurisprudencia), las expectativas de los usuarios se mueven (acostumbrados a asistentes más capaces esperan más), y los casos de uso evolucionan. Un dataset de 18 meses mide performance contra un mundo que ya no existe. La solución es un ciclo de mantenimiento: revisión trimestral o semestral del golden set, incorporación de ejemplos nuevos extraídos de logs de producción, y versionado explícito (`golden_v1`, `golden_v2`, etc.) para que las métricas sean comparables.

---

### Pregunta 4

Tu sistema de moderación de contenido usa un único juez de IA para evaluar posts por violaciones de seguridad. Las pruebas revelan que el juez consistentemente pasa por alto patrones sutiles de acoso con referencias culturales, mientras marca contenido legítimo en exceso. ¿Cómo deberías mejorar la confiabilidad de la evaluación?

- **Implementar un sistema multi-judge con modelos diversos y experiencia especializada en seguridad**
- Aumentar el umbral de confianza para marcar contenido y reducir falsos positivos
- Añadir ejemplos de calibración mostrando patrones de acoso cultural al judge prompt
- Cambiar a métricas tradicionales como coincidencia de palabras clave para resultados más consistentes

**Respuesta correcta**

**Explicación:** El patrón de "pasa cosas sutiles" + "sobre-marca cosas legítimas" es la firma clásica de un juez con blind spots sistemáticos derivados de su entrenamiento. Añadir ejemplos ayuda marginalmente pero no cambia la arquitectura del modelo. La solución estructural es un multi-judge heterogéneo: distintos modelos (OpenAI, Anthropic, Google, posiblemente uno fine-tuned en moderación) tienen distintos blind spots. Un sistema de consenso con poder de veto para el juez especializado en safety captura patrones que un juez único no ve y, al mismo tiempo, reduce falsos positivos porque exige acuerdo. Subir el umbral solo reduce la sensibilidad general sin resolver el sesgo subyacente; volver a keyword matching retrocede diez años en capacidad semántica.

---

### Pregunta 5

Diseñaste un judge prompt que requiere output JSON con campos específicos para scores y justificaciones. En producción, el 15% de las respuestas del juez fallan al parsear por variaciones menores de formato como espacios extra o nombres de campo ligeramente diferentes. ¿Qué mejora arquitectónica resuelve mejor esto?

- Usar validación de JSON schema más estricta que rechace cualquier desviación de formato
- Añadir más ejemplos de calibración mostrando los requisitos exactos de formato JSON
- **Diseñar formatos de output con flexibilidad e implementar parsing robusto que maneje variaciones menores de forma elegante**
- Cambiar a output en lenguaje natural en vez de JSON estructurado para evitar problemas de parsing

**Respuesta correcta**

**Explicación:** La estrategia correcta es "estricto en lo que generas, tolerante en lo que aceptas" (Postel's Law). En el prompt, pides formato JSON exacto; en el código, parseas con tolerancia: extraes el primer bloque `{...}` válido, aceptas trailing commas, normalizas espacios. Mejor aún, usa el `response_format` nativo del proveedor (OpenAI JSON mode, Anthropic tool use) o librerías como `instructor` y `pydantic` que fuerzan schema a nivel de API. Validación más estricta aumenta el problema; cambiar a texto libre tira a la basura todo el beneficio de output estructurado para análisis downstream.

---

### Pregunta 6

Tu generador de descripciones de productos de e-commerce usa cosine similarity (umbral 0.75) para evaluación. Todas las descripciones generadas pasan este umbral, pero los stakeholders de negocio se quejan de que las descripciones carecen de lenguaje persuasivo y no destacan puntos de venta clave. ¿Por qué cosine similarity es insuficiente para este caso?

- **Cosine similarity mide cercanía semántica pero no puede evaluar persuasión ni valor de negocio**
- Las descripciones de productos requieren métricas ROUGE en lugar de cosine similarity para una evaluación adecuada
- El umbral de 0.75 es demasiado bajo y debería elevarse a 0.90 o más
- Las descripciones de referencia en el golden dataset necesitan actualizarse con más frecuencia

**Respuesta correcta**

**Explicación:** Cosine similarity sobre embeddings mide qué tan parecidos son dos textos en significado general. Dos descripciones pueden tener cosine 0.85 (mismo tema, mismo producto, mismos atributos) y una ser persuasiva mientras la otra es un listado seco. La métrica es ciega a dimensiones como *tono emocional*, *estructura narrativa*, *énfasis en beneficios vs features*, o *call-to-action*. Esas dimensiones requieren un LLM-as-a-Judge con rúbrica específica de marketing. Subir el umbral no resuelve nada: todas las descripciones pueden ser semánticamente similares pero igualmente aburridas. ROUGE sufre del mismo problema.

---

### Pregunta 7

Construiste un sistema multi-judge usando tres instancias distintas de GPT-5 con prompts idénticos. El acuerdo entre jueces es alto (95%), pero los tres consistentemente infravaloran respuestas creativas que los usuarios realmente prefieren. ¿Cuál es la falla arquitectónica fundamental?

- Los jueces necesitan prompts especializados enfocados en diferentes dimensiones de evaluación
- El mecanismo de consenso debería usar votación ponderada en vez de promedio simple
- Se necesita validación humana para calibrar los jueces contra las preferencias de los usuarios
- **Correlación sin diversidad: usar modelos similares crea fallas correlacionadas en vez de evaluación independiente**

**Respuesta correcta**

**Explicación:** El acuerdo alto no es evidencia de corrección, es evidencia de que los jueces comparten sesgos. Tres instancias del mismo modelo con el mismo prompt no son un ensemble: son el mismo juez tres veces. Si GPT-5 tiene un sesgo contra estructuras creativas (porque fue entrenado principalmente con texto formal), replicarlo tres veces amplifica el sesgo, no lo mitiga. El multi-judge aporta valor real cuando hay diversidad: distintas familias de modelos (Claude, Gemini, Llama), distintos tamaños, distintos prompts, o jueces especializados por dimensión. Las fallas deben ser *independientes* para que el ensemble las promedie. Validación humana es necesaria pero es el *síntoma* que detecta el problema, no la solución arquitectónica.

---

### Pregunta 8

Tu IA de consejo médico usa tanto scores BLEU automatizados (rápidos, baratos) como LLM judges (lentos, caros) para evaluación. Quieres optimizar costos manteniendo calidad. ¿Qué estrategia de evaluación en cascada ofrece el mejor balance?

- Usar LLM judges para todas las evaluaciones ya que la calidad importa más en contextos médicos
- Usar scores BLEU para todas las evaluaciones y confiar en feedback de usuarios para detectar problemas de calidad
- **Usar scores BLEU rápidos para screening inicial, rutear los casos con scores bajos o alto stake a LLM judges**
- Alternar entre BLEU y LLM judges aleatoriamente para obtener muestreo representativo

**Respuesta correcta**

**Explicación:** La arquitectura jerárquica (cascada) es el patrón canónico para optimizar costo sin sacrificar calidad crítica. Un juez barato screena el 100% y resuelve con confianza los casos claramente buenos y claramente malos (típicamente 70-80% del volumen). Los casos ambiguos o con score bajo escalan a jueces caros y, si son de alto stake (como consejo médico), eventualmente a revisión humana. Esto típicamente reduce el costo total 3-5× respecto a usar LLM judge para todo. Opción 1 (LLM para todo) es ineficiente; opción 2 (BLEU puro + feedback) usa a los usuarios como instrumento de medición, inaceptable en medicina; opción 4 (alternar aleatorio) no provee ninguna garantía de calidad sobre casos individuales y confunde evaluación con sampling.
