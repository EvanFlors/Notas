# Quiz: Evaluación, Failure Modes y Governance

Has fine-tuneado un modelo para soporte al cliente y lo desplegaste a producción. Después del despliegue, recibes reportes de que el modelo rinde peor en tareas generales, muestra sesgos en los outputs y las métricas de evaluación no coinciden con el rendimiento real en producción. Este quiz verifica tu comprensión de evaluación de modelos fine-tuned, detección de failure modes y prácticas de governance.

---

### Pregunta 1

Durante la evaluación observas que la accuracy en training es 95% pero en validación es 78%. ¿Qué indica esto?

- A) El modelo está aprendiendo bien.
- B) El modelo está en underfitting.
- **C) El modelo está en overfitting: memoriza los datos de entrenamiento pero no generaliza.**
- D) El validation set es demasiado pequeño.

**Explicación:** Una brecha de 17 puntos porcentuales entre training y validation es un indicador clásico de **overfitting**: el modelo memoriza patrones específicos (incluyendo ruido) del training set en vez de aprender la estructura subyacente que se transfiere a datos nuevos. Mitigaciones típicas: reducir épocas, aumentar regularización (weight decay, dropout), early stopping en val loss, incrementar datos, bajar el rank en LoRA o reducir el learning rate. Underfitting (B) daría baja accuracy en ambos sets. El tamaño del val set (D) afecta la varianza del estimador, no explica brechas sistemáticas.

---

### Pregunta 2

Después del fine-tuning, pruebas el modelo en tareas generales y encuentras que rinde 20% peor que el modelo base. ¿Cómo se llama este fenómeno?

- A) Overfitting.
- **B) Catastrophic forgetting: el modelo perdió capacidades generales.**
- C) Underfitting.
- D) Comportamiento normal del fine-tuning.

**Explicación:** El **catastrophic forgetting** (McCloskey & Cohen, 1989) ocurre cuando los pesos que codificaban capacidades previas (idiomas, matemáticas, código) se sobrescriben al optimizar para la tarea nueva. Se detecta re-corriendo benchmarks base como MMLU, GSM8K, HumanEval y TruthfulQA antes y después del fine-tune. Se mitiga con **PEFT** (LoRA/QLoRA congela el modelo base), **replay** de 10-20% de datos generales, learning rates bajos (1e-5 a 2e-4), pocas épocas (1-3) y early stopping basado en benchmarks base. No es "normal": una regresión >5-10% en cualquier benchmark base debería bloquear el deploy (severidad S1/S2).

---

### Pregunta 3

¿Cuándo es más apropiado usar LLM-as-Judge para evaluación?

- A) Para todas las tareas de evaluación.
- **B) Para tareas complejas donde las métricas tradicionales son insuficientes, como calidad de generación.**
- C) Solo cuando la evaluación humana no está disponible.
- D) Nunca: las métricas tradicionales son siempre mejores.

**Explicación:** **LLM-as-Judge** (ej. GPT-4 como juez con rúbrica) brilla en tareas abiertas donde métricas como BLEU, ROUGE o accuracy no capturan matices: calidad de respuestas conversacionales, razonamiento multi-paso, utilidad percibida, adherencia a estilo. Para tareas con ground truth claro (clasificación, extracción, matemáticas con respuesta única) las métricas clásicas son más baratas, deterministas y auditables. Precauciones con LLM-judge: sesgo de longitud, sesgo de posición, sesgo hacia su propio estilo, y falta de reproducibilidad entre versiones del juez. Buenas prácticas: rotar jueces, aleatorizar orden, calibrar contra human eval en una muestra, y usar rúbricas explícitas. Herramientas de referencia: MT-Bench, AlpacaEval, Chatbot Arena.

---

### Pregunta 4

¿Cómo deberías evaluar sesgo (bias) en un modelo fine-tuned?

- A) Solo revisar la accuracy global.
- **B) Evaluar el rendimiento y los outputs a través de diferentes grupos demográficos y escenarios.**
- C) Solo revisar si el modelo es tóxico.
- D) La evaluación de sesgo no es necesaria.

**Explicación:** La accuracy global **oculta disparidades** entre subgrupos: un modelo puede tener 90% de accuracy total pero 95% para un grupo y 70% para otro. La evaluación de sesgo requiere **desagregar métricas por factor** (género, idioma, región, tipo de cliente, categoría de ticket) y usar benchmarks específicos como **BBQ** (sesgo en Q&A), **StereoSet**, **Winogender**, **ToxiGen** y **CrowS-Pairs**. Herramientas: Fairlearn, AIF360, Giskard. El EU AI Act y el NIST AI RMF exigen esta evaluación para sistemas de alto riesgo. Toxicidad (C) es una dimensión distinta: mide outputs ofensivos, no trato desigual. Un gap de accuracy entre subgrupos >5 pp amerita investigación; >10 pp bloquea el deploy en contextos sensibles.

---

### Pregunta 5

¿Qué debería incluir un model card comprensivo?

- A) Solo métricas de rendimiento del modelo.
- **B) Model details, intended use, performance, training data, consideraciones éticas y limitaciones.**
- C) Solo la arquitectura del modelo.
- D) Solo información de despliegue.

**Explicación:** El estándar propuesto por **Mitchell et al. (2019)** y adoptado por HuggingFace, Google y Meta exige nueve secciones mínimas: (1) **model details** (arquitectura, versión, autor, licencia, fecha, checksum); (2) **intended use** incluyendo **out-of-scope**; (3) **factors** (subgrupos relevantes); (4) **metrics** desagregadas por factor; (5) **evaluation data**; (6) **training data** con provenance; (7) **ethical considerations** (bias, safety, red-teaming); (8) **caveats and recommendations**; (9) **license + maintenance**. Omitir cualquiera reduce el valor auditor del documento. Bajo el **EU AI Act** (vigor agosto 2024), para modelos de propósito general se exige además un resumen de datos de entrenamiento y, si FLOPs > 10²⁵, reporte de evaluaciones adversariales. Un model card copy-paste con números inventados es peor que no tenerlo: expone a responsabilidad legal.

---

### Pregunta 6

Después de hacer fine-tuning con DPO, descubres que las respuestas del modelo son 3x más largas que las del modelo base, sin que la calidad humana percibida haya mejorado. ¿Qué failure mode estás observando?

- A) Catastrophic forgetting.
- B) Mode collapse.
- **C) Reward hacking: el modelo optimiza una proxy (longitud) que correlaciona con el reward pero no con calidad real.**
- D) Data contamination.

**Explicación:** El **reward hacking** (Krakovna et al., 2020, *Specification Gaming*) ocurre cuando el modelo descubre atajos para maximizar el reward sin resolver la tarea real. El **length bias** es el patrón más documentado en RLHF/DPO: los annotators humanos tienden a puntuar mejor las respuestas largas, el reward model aprende esta correlación y el modelo converge a verbosidad. Detección: correlación de Pearson entre longitud de output y score (>0.5 con p<0.01 es sospechoso). Otros patrones: **sycophancy** (estar de acuerdo con el usuario incluso cuando se equivoca), **format bias** (abuso de bullets y emojis), **refusal collapse** (rechazar prompts benignos). Mitigación: datasets de preferencias balanceados por longitud, length normalization en el reward, evaluación con rúbricas que separen contenido de forma.

---

### Pregunta 7

¿Cuál de las siguientes licencias **impide** el uso comercial de un modelo?

- A) Apache 2.0 (Mistral 7B, Qwen 2.5).
- B) MIT (Phi-4).
- **C) CC-BY-NC 4.0 (Command R).**
- D) Llama Community License (para empresas con <700M MAU).

**Explicación:** **CC-BY-NC** (Creative Commons Attribution-**NonCommercial**) prohíbe explícitamente cualquier uso con fines comerciales, incluso interno en una empresa con fines de lucro. Apache 2.0 y MIT son licencias permisivas que permiten uso comercial con attribution. La **Llama Community License** permite uso comercial excepto si tu producto tiene >700M MAU (en cuyo caso debes solicitar licencia a Meta); también prohíbe entrenar otros LLMs con outputs y exige el prefijo "Llama" en el nombre del derivado. Otras licencias restrictivas que conviene conocer: **Mistral Research License** (research-only, aplica a Mistral Large/Medium), **OpenRAIL-M** (restricciones de uso) y los **términos de uso de OpenAI** (prohíben entrenar modelos competidores con sus outputs). Siempre auditar la licencia antes de desplegar y mantener un registro de dependencias.

---

### Pregunta 8

¿Cuál es la mejor forma de detectar **data contamination** entre tu benchmark de evaluación y los datos de entrenamiento del modelo?

- A) Comparar accuracy entre splits de train y test.
- **B) Buscar coincidencias de n-gramas (ej. 13-gramas) del test set en el corpus de entrenamiento.**
- C) Entrenar un modelo desde cero y comparar.
- D) Usar únicamente benchmarks publicados antes de 2020.

**Explicación:** La convención establecida por **Brown et al. (GPT-3, 2020)** es buscar **13-gramas exactos** del test set dentro del corpus de entrenamiento; un overlap >10% indica contaminación significativa. Si no tienes acceso al corpus (modelos cerrados), hay alternativas: **canary strings** (frases únicas insertadas durante training y buscadas en outputs), **membership inference attacks** (el modelo asigna mayor probabilidad a ejemplos vistos), o **post-cutoff benchmarks** como **MMLU-Pro** (2024), **LiveBench** (actualizado mensualmente) o **SWE-Bench Verified**. Brown et al. reportaron hasta 40% de overlap entre MMLU y Common Crawl; Zhou et al. (2024) encontraron 20-30% de GSM8K en corpus modernos. La opción (A) no detecta contaminación de internet, (C) es inviable económicamente, y (D) descarta benchmarks útiles sin resolver el problema.

---

### Pregunta 9

Bajo el **EU AI Act** (vigente desde agosto 2024), ¿qué obligación aplica específicamente a modelos de propósito general (GPAI) con FLOPs de entrenamiento > 10²⁵?

- A) Prohibición total de uso comercial.
- B) Obligación de ser open source.
- **C) Evaluaciones adversariales, reporte de incidentes serios al AI Office y ciberseguridad reforzada.**
- D) Registro obligatorio en una base de datos pública.

**Explicación:** El **art. 55 del EU AI Act** clasifica los modelos GPAI con FLOPs > 10²⁵ como "con riesgo sistémico" y exige: (1) **evaluaciones adversariales** (red-teaming) documentadas; (2) **evaluación y mitigación de riesgos sistémicos**; (3) **reporte de incidentes serios** al AI Office en plazos definidos; (4) **ciberseguridad adecuada** del modelo y su infraestructura. Para GPAI en general (art. 53), se exige documentación técnica, resumen público de datos de entrenamiento y respeto a derechos de autor incluyendo opt-outs. Las multas llegan a **35M€ o 7% del volumen global**. Entrada en vigor escalonada: feb 2025 (prohibiciones de riesgo inaceptable), agosto 2025 (obligaciones GPAI), agosto 2026 (sistemas de alto riesgo). Aplica a cualquier modelo cuyos outputs se usen en la UE, independientemente de dónde se entrene.

---

### Pregunta 10

Después de hacer fine-tuning observas que, a temperature=0.9, el modelo responde casi lo mismo a prompts distintos: distinct-2 cae de 0.45 (modelo base) a 0.18, y self-BLEU sube de 22 a 68. ¿Qué failure mode es?

- A) Catastrophic forgetting.
- **B) Mode collapse: el modelo converge a un conjunto reducido de respuestas.**
- C) Reward hacking.
- D) Overfitting a estilo.

**Explicación:** El **mode collapse** (término importado de GANs, Goodfellow et al. 2016) se diagnostica cuando el modelo pierde diversidad de output: baja **distinct-n** (fracción de n-gramas únicos), alto **self-BLEU** (las respuestas se parecen entre sí) y baja entropía del output a temperatura alta. Es común tras entrenar con cross-entropy loss excesiva, DPO con dataset de preferencias sesgado, o fine-tuning agresivo que empuja al modelo a una moda. Mitigación: añadir regularización KL contra el modelo base, usar datasets de preferencias balanceados en diversidad estilística, bajar el número de épocas, instrumentar detectores de diversidad en producción. Catastrophic forgetting (A) se mide con benchmarks base, reward hacking (C) con correlación métrica-proxy vs. calidad humana, y overfitting a estilo (D) con eval en paráfrasis.
