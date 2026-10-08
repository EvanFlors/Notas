# Quiz: Entendiendo los LLMs

## ¿Qué es?

Este quiz evalúa tu comprensión práctica de los **Large Language Models**: cuándo usarlos, cómo arquitectar sistemas con ellos, cómo manejar sus riesgos (alucinaciones, costo, seguridad) y qué técnicas aplicar (RAG, fine-tuning, validation layers) ante distintos escenarios.

## ¿Por qué importa?

El escenario del quiz es realista: tu equipo construyó un sistema basado en transformers que detecta bugs y provee contexto. Ahora los developers quieren más — sugerencias automáticas de fixes, refactors y generación de tests. Es exactamente el tipo de decisiones arquitectónicas que un **AI Engineer** debe tomar: no sólo elegir modelo, sino *dónde* en el pipeline aplicar LLMs, *cuáles* tareas se benefician de su generatividad y *cómo* mitigar sus riesgos antes de que lleguen al usuario.

## ¿Cómo funciona?

Cada pregunta presenta un trade-off real de producción. La respuesta correcta refleja la práctica estándar de la industria 2024-2025. La **explicación** debajo justifica *por qué* y vincula el concepto a herramientas, patrones o estudios concretos.

---

## Pregunta 1

**¿Qué característica hace a los LLMs más efectivos para tareas de generación de código, comparado con modelos pequeños especializados?**

- [x] La exposición a repositorios masivos de código durante el entrenamiento les da conocimiento de convenciones, patrones y buenas prácticas en contextos diversos.
- [ ] Los LLMs generan código más rápido que los enfoques basados en templates.
- [ ] Los LLMs usan menos recursos computacionales que modelos pequeños especializados.
- [ ] Los LLMs proveen outputs más deterministas y consistentes.

**Respuesta correcta:** opción 1.

**Explicación:** los LLMs modernos (Codex, Code Llama, GPT-4, Claude, DeepSeek-Coder, Qwen-Coder) fueron pre-entrenados sobre decenas de millones de repos de GitHub, StackOverflow, documentación oficial y foros técnicos — centenares de miles de millones de tokens de código en docenas de lenguajes. Esto les permite "conocer" idioms de cada lenguaje (list comprehensions en Python, pattern matching en Rust, `async/await` en JS), convenciones de nomenclatura, patrones de diseño comunes y hasta las APIs específicas de librerías populares. Las otras opciones son incorrectas: los LLMs son *más lentos* que templates (no más rápidos), consumen *órdenes de magnitud más* compute que modelos pequeños, y son **no deterministas** por naturaleza (el sampling con `temperature > 0` produce outputs variados; incluso con `seed`, solo es best-effort). La ventaja real de los LLMs es la **generalización** a situaciones nunca vistas, no la velocidad ni el determinismo.

---

## Pregunta 2

**Para un despliegue costo-efectivo de tu sistema de code review, ¿cómo deberías arquitectar el uso de LLMs?**

- [x] Usa LLMs para tareas generativas complejas (fixes, explicaciones) y modelos más pequeños para clasificación y detección.
- [ ] Usa el LLM más grande disponible para todas las tareas de análisis de código para maximizar la calidad.
- [ ] Evita LLMs por completo debido al costo computacional y quédate con transformers.
- [ ] Usa LLMs sólo para análisis offline, no para herramientas en tiempo real para developers.

**Respuesta correcta:** opción 1.

**Explicación:** este es el patrón **"model routing" o "cascada de modelos"**, estándar en producción. Diferentes tareas tienen diferentes niveles de complejidad: detectar si una línea tiene una variable sin usar es un problema de clasificación simple que resuelve un modelo pequeño (o un linter determinístico) a milisegundos y centavos; explicar *por qué* ese código produce un race condition en concurrencia y proponer un fix requiere razonamiento multi-paso que justifica un LLM grande. En números concretos: `gpt-5-nano` cuesta $0.05/1M tokens input, mientras `claude-opus-4` cuesta $15/1M — una diferencia de **300×**. Usar el modelo grande para todo quema presupuesto sin mejorar la clasificación simple. La opción "evitar LLMs" sacrifica las capacidades generativas que son el valor diferencial. Y restringirlos a offline mata la UX en vivo (autocompletado, inline suggestions). El patrón ganador: **triaje con modelo barato → escalamiento a modelo grande solo cuando se necesita**. Librerías como LangChain, LiteLLM y Portkey facilitan este routing.

---

## Pregunta 3

**¿Cuál es el riesgo más significativo al usar LLMs para generar sugerencias de código para developers?**

- [ ] El código generado será demasiado lento para correr eficientemente.
- [x] Los LLMs pueden generar código inseguro, con bugs o inapropiado que los developers aceptan e integran por confianza.
- [ ] La generación de código será demasiado cara para despliegue práctico.
- [ ] Los LLMs no entenderán lenguajes y frameworks modernos.

**Respuesta correcta:** opción 2.

**Explicación:** este es el riesgo documentado como **"automation bias"** — cuando una herramienta parece autoritativa, los humanos tienden a aceptar sus sugerencias con revisión superficial. Estudios de 2023-2024 (Perry et al. de Stanford, GitHub, Snyk) mostraron que developers usando Copilot escribieron código con **más vulnerabilidades de seguridad** que grupos de control, y además eran *más confiados* de que su código era seguro. Ejemplos reales: LLMs sugieren SQL con concatenación de strings (inyección), llaman APIs con secretos hardcodeados, importan paquetes npm con nombres similares a los reales pero inexistentes (**"slopsquatting"** — atacantes registran esos nombres y los convierten en malware), y usan algoritmos criptográficos obsoletos. Las otras opciones son falsas o secundarias: el código generado suele ser *correcto en performance*, el costo es manejable con buen routing, y los LLMs sí entienden frameworks modernos (su training suele llegar a 2023-2024). Mitigaciones: revisión obligatoria, scanning automático (Semgrep, CodeQL, Snyk), tests, y nunca ejecutar código generado sin sandbox.

---

## Pregunta 4

**Al implementar sugerencias de código con LLMs, ¿qué enfoque gestiona mejor el riesgo de alucinación?**

- [ ] Usar sólo los LLMs más grandes y capaces para minimizar errores.
- [ ] Generar múltiples sugerencias y dejar que los developers elijan la mejor.
- [x] Implementar capas de validación (chequeo sintáctico, scanning de seguridad, testing) antes de mostrar sugerencias a los developers.
- [ ] Etiquetar claramente todas las sugerencias como "generado por IA" y dejar que los developers manejen la validación.

**Respuesta correcta:** opción 3.

**Explicación:** los LLMs **alucinan**: inventan nombres de funciones que no existen, importan paquetes ficticios, inventan firmas de API, usan sintaxis inválida en lenguajes menos comunes. El modelo más grande (opción 1) *reduce* pero no elimina alucinaciones — y es más caro sin resolver el problema de raíz. Generar múltiples sugerencias (opción 2) multiplica el costo y transfiere la carga cognitiva al developer, que puede elegir la respuesta elegante pero incorrecta. Etiquetar como "AI-generated" (opción 4) no previene nada; estudios muestran que las etiquetas no reducen significativamente el automation bias. La solución robusta es **validación automática en capas** antes de que la sugerencia llegue al humano: (1) **parsing/AST** — si no compila, descartar; (2) **linters** (ESLint, Ruff, Clippy); (3) **security scanning** (Semgrep, Bandit); (4) **type checking** (mypy, TypeScript); (5) **test execution en sandbox**; (6) **verificación de que los imports/APIs existan realmente**. Este es el patrón que usan Cursor, Windsurf, Copilot Workspace y agentes como Claude Code o Devin. La regla general: **nunca confíes en el output de un LLM; verifica antes de ejecutarlo o mostrarlo**.

---

## Pregunta 5

**Tu LLM genera excelentes explicaciones de código pero ocasionalmente sugiere APIs deprecadas o patrones obsoletos. ¿Cómo deberías abordar esto?**

- [ ] Acepta esta limitación como inevitable con la tecnología actual.
- [ ] Cambia a otro LLM entrenado con datos más recientes.
- [x] Implementa Retrieval-Augmented Generation (RAG) con documentación actual y buenas prácticas.
- [ ] Fine-tunea el LLM sólo con los ejemplos de código más recientes.

**Respuesta correcta:** opción 3.

**Explicación:** todos los LLMs tienen un **knowledge cutoff** — una fecha después de la cual no vieron datos. GPT-4o: Oct 2023 originalmente. Claude 3.5 Sonnet: Abr 2024. LLaMA 3.1: Dec 2023. Esto significa que APIs lanzadas o deprecadas después del cutoff son invisibles para el modelo, que seguirá recomendando lo que conocía. "Aceptar la limitación" (opción 1) condena al usuario a bugs recurrentes. "Cambiar de modelo" (opción 2) sólo pospone el problema unos meses — el cutoff del nuevo modelo también envejecerá. "Fine-tuning sólo con ejemplos recientes" (opción 4) es **catastrophic forgetting**: el modelo pierde conocimiento general importante y es operativamente caro mantener (re-entrenar cada semana que sale una nueva versión de una librería es inviable). **RAG** es la respuesta: en cada request, recuperas los chunks relevantes de la documentación oficial actual (versionada), de notes de release, y de ejemplos canónicos, y los inyectas en el contexto del LLM. El modelo entonces genera con información fresca y verificable. Patrones avanzados: *Agentic RAG* (el LLM decide qué buscar), *CRAG* (self-correction), **tool use** con búsqueda web (Perplexity, SearchGPT). Librerías: LlamaIndex, LangChain, Haystack. Infraestructura: Pinecone, Qdrant, Weaviate, pgvector, Chroma. Como bonus, RAG permite citar fuentes — crucial para que el developer verifique la sugerencia.

---

## Resumen

- **Los LLMs sobresalen en código porque vieron millones de repos**, no porque sean rápidos ni deterministas.
- **Arquitectura óptima = cascada de modelos**: barato para clasificar/detectar, caro sólo para generar/razonar. Diferencias de 100-300× en costo.
- **Automation bias es el riesgo #1**: los developers aceptan output de LLMs con revisión superficial. Más vulnerabilidades + más confianza falsa.
- **Validación automática en capas** (parse → lint → sec-scan → tests) antes de mostrar al humano es la única mitigación robusta de alucinaciones.
- **RAG resuelve el problema del knowledge cutoff** mejor que cambiar de modelo o fine-tuning parcial. Permite citar fuentes y mantiene información fresca sin re-entrenar.
- **Nunca confíes ciegamente en el output de un LLM.** Esta es la regla de oro común a las 5 preguntas.
