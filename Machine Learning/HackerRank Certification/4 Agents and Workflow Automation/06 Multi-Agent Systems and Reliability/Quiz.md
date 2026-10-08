# Quiz: Sistemas Multi-Agente y Confiabilidad

### 1. ¿Cuándo tiene más sentido usar un sistema multi-agente en lugar de un agente único?

- A) Siempre: más agentes = más calidad.
- B) Cuando la tarea abarca varios dominios de experticia y es paralelizable.
- C) Cuando quieres reducir el costo en tokens.
- D) Cuando necesitas la menor latencia posible.

**Respuesta correcta:** B

**Explicación:** MAS brilla cuando una sola "mente" no puede ser experta en todo y las sub-tareas pueden ejecutarse en paralelo. No es una bala de plata: casi siempre aumenta el costo en tokens (más llamadas) y, si la coordinación es secuencial, incluso la latencia. Para una tarea simple y lineal, un solo agente bien construido es superior.

---

### 2. En el patrón supervisor-worker, ¿cuál es la responsabilidad principal del supervisor?

- A) Hacer todo el análisis y usar a los workers solo para formatear.
- B) Enrutar sub-tareas a workers especializados y sintetizar sus resultados.
- C) Validar que los workers no gasten tokens.
- D) Ejecutar las herramientas (tools) por los workers.

**Respuesta correcta:** B

**Explicación:** El supervisor debe ser **ligero**: compone el equipo, decide quién actúa y sintetiza. Si el supervisor termina haciendo el trabajo pesado, se vuelve un cuello de botella y pierdes la ventaja del paralelismo. Esto es el **"orchestrator bottleneck" anti-pattern**.

---

### 3. ¿Qué ventaja clave aporta el patrón de **subagentes paralelos** usado por Anthropic en su *Multi-Agent Research System*?

- A) Reduce el costo total en tokens.
- B) Permite que el lead agent no consuma tokens mientras los subagentes trabajan, y cada subagente usa su propio contexto limpio.
- C) Elimina la necesidad de un modelo potente para el lead.
- D) Garantiza que no haya alucinaciones.

**Respuesta correcta:** B

**Explicación:** Mientras los N subagentes trabajan en paralelo con contextos independientes, el lead agent está "dormido" sin acumular tokens. Esto permite explorar múltiples líneas simultáneamente. El trade-off es que el costo total sube (Anthropic reportó ~15× más tokens vs. agente único), compensado por una mejora grande en calidad para tareas de research.

---

### 4. ¿Cuál de las siguientes NO es un patrón arquitectónico común en MAS?

- A) Supervisor-Worker
- B) Swarm (hand-off)
- C) Jerárquico
- D) Monolith-Fallback

**Respuesta correcta:** D

**Explicación:** "Monolith-Fallback" no es un patrón reconocido. Los patrones canónicos son supervisor-worker, swarm/hand-off, jerárquico, pipeline y debate/consenso. "Fallback" sí existe como mecanismo de reliability (si falla el agente A, usar B), pero no es un patrón arquitectónico de MAS.

---

### 5. ¿Qué framework es más adecuado cuando necesitas **control explícito del flujo** y checkpoints de estado?

- A) CrewAI
- B) LangGraph
- C) OpenAI Agents SDK
- D) MetaGPT

**Respuesta correcta:** B

**Explicación:** LangGraph modela el sistema como un grafo de estados con nodos y aristas condicionales, lo que da control total sobre el flujo y permite persistir checkpoints. CrewAI es prompt-first y más opinado; Agents SDK se enfoca en hand-offs simples; MetaGPT impone un flujo tipo waterfall de empresa simulada.

---

### 6. ¿Qué estándar emergente estandariza la comunicación **agente ↔ agente** entre vendors distintos?

- A) MCP (Model Context Protocol)
- B) A2A (Agent-to-Agent)
- C) OpenAPI
- D) gRPC

**Respuesta correcta:** B

**Explicación:** A2A, promovido por Google, apunta a estandarizar la mensajería agente-agente cross-vendor. **MCP** (Anthropic) estandariza el eje agente↔herramientas/recursos. OpenAPI y gRPC son protocolos genéricos de servicios, no específicos de agentes.

---

### 7. Dos agentes contradicen: seguridad dice "no uses eval"; performance dice "usa eval, es más rápido". ¿Cuál es la mejor estrategia?

- A) Usar la recomendación del que respondió primero.
- B) Aplicar reglas de prioridad donde seguridad gana sobre performance.
- C) Reportar ambas sin resolver y dejar que el humano decida siempre.
- D) Promediar las severidades.

**Respuesta correcta:** B

**Explicación:** La política estándar en sistemas de code review es **prioridad fija: seguridad > correctness > performance > estilo**. Promediar severidades no tiene sentido semántico; usar "quien respondió primero" es arbitrario. Reportar ambas sin resolver es aceptable como fallback pero genera ruido al humano si ocurre en cada review.

---

### 8. ¿Por qué es importante incluir instrucciones **"NO HAGAS"** (stay in your lane) en el prompt de cada agente especialista?

- A) Reduce el consumo de tokens del prompt.
- B) Evita que los agentes solapen funciones y produzcan hallazgos duplicados.
- C) Es un requerimiento del protocolo A2A.
- D) Permite usar modelos más baratos.

**Respuesta correcta:** B

**Explicación:** Sin un "no hagas", los agentes tienden a comentar fuera de su dominio (p.ej., el de seguridad comenta estilo), generando duplicados que confunden al sintetizador y al humano. Es una de las intervenciones más baratas y efectivas en MAS.

---

### 9. ¿Qué problema de concurrencia resuelve un `asyncio.Lock` sobre un `SharedContext`?

- A) Reduce la latencia del sistema.
- B) Garantiza que varias escrituras simultáneas al estado no se pisen (race conditions).
- C) Evita que los agentes alucinen.
- D) Reduce el costo en tokens.

**Respuesta correcta:** B

**Explicación:** Cuando múltiples agentes escriben al mismo objeto en paralelo (p.ej., `findings.append(...)`), sin mutua exclusión pueden perderse mensajes o corromperse estructuras. Un lock serializa los writes a esa sección crítica. Alternativas: estructuras CRDT o colas transaccionales.

---

### 10. Un agente queda esperando respuesta de otro, que a su vez espera al primero. ¿Cómo se llama y cómo se previene?

- A) Starvation; con prioridades.
- B) Deadlock; con timeouts y evitando dependencias circulares.
- C) Thrashing; con más RAM.
- D) Livelock; con reintentos.

**Respuesta correcta:** B

**Explicación:** Esto es un **deadlock por espera circular**. Las defensas estándar son timeouts por mensaje/iteración y diseñar el grafo de dependencias como DAG (acíclico). Starvation y livelock son fenómenos distintos; thrashing es de memoria/paginación.

---

### 11. En testing de agentes, ¿por qué se evita assertar strings exactas en la salida?

- A) Porque los agentes tardan demasiado y hacen el test lento.
- B) Porque los LLM producen salidas variables aun con la misma entrada; se validan **propiedades** en su lugar.
- C) Porque el framework de testing no soporta strings.
- D) Porque viola el protocolo MCP.

**Respuesta correcta:** B

**Explicación:** Un LLM, incluso con `temperature=0`, puede variar la redacción exacta entre versiones del modelo o cambios de prompt. Se assertan propiedades invariantes: "detecta la vulnerabilidad", "severidad es high o critical", "no inventa archivos". Esto se llama **property-based testing** aplicado a agentes.

---

### 12. ¿Qué mide la combinación precision/recall en una eval suite de agentes?

- A) Latencia y costo.
- B) Precision: cuántos hallazgos reportados son correctos (evitar falsos positivos). Recall: cuántos de los hallazgos reales encontró (evitar falsos negativos).
- C) Tokens consumidos y temperatura usada.
- D) Número de agentes activos.

**Respuesta correcta:** B

**Explicación:** Son métricas clásicas de clasificación. En agentes de code review, precision baja = muchos falsos positivos (molesta al desarrollador); recall bajo = se pierden bugs reales. El F1 (media armónica) balancea ambos. Latencia y costo se trackean como métricas aparte.

---

### 13. ¿Qué hace un **circuit breaker** por agente?

- A) Corta la ejecución al llegar al límite de tokens.
- B) Si un agente falla N veces consecutivas, se desactiva temporalmente para no cascadear fallos ni gastar tokens inútilmente.
- C) Impide que dos agentes se comuniquen directamente.
- D) Rota entre varias API keys automáticamente.

**Respuesta correcta:** B

**Explicación:** El patrón circuit breaker (de resiliencia clásica, popularizado por Netflix Hystrix) tiene estados `CLOSED → OPEN → HALF_OPEN`. En MAS evita bombardear al proveedor cuando devuelve 5xx y protege el presupuesto. Después del `recovery_s`, pasa a HALF_OPEN y prueba si el servicio volvió.

---

### 14. ¿Para qué sirve una **Dead Letter Queue** en un sistema multi-agente?

- A) Para dar prioridad a los mensajes importantes.
- B) Para almacenar mensajes que fallaron el máximo de reintentos, de modo que puedan inspeccionarse sin perderse.
- C) Para encriptar la comunicación entre agentes.
- D) Para serializar accesos al estado compartido.

**Respuesta correcta:** B

**Explicación:** Sin DLQ, los mensajes que fallan N veces desaparecen y pierdes señal valiosa de debug. Con DLQ puedes auditarlos, reprocesarlos tras un fix o detectar patrones (p.ej., todos los mensajes de un dominio específico fallan).

---

### 15. ¿Qué anti-patrón describe el "agent-to-agent infinite ping-pong"?

- A) Dos agentes se transfieren control eternamente sin converger.
- B) Un agente llama a tools 100 veces en un turno.
- C) Un agente usa el modelo equivocado.
- D) Un agente aluciona la respuesta.

**Respuesta correcta:** A

**Explicación:** Sin un límite duro de `max_rounds` o `max_steps`, dos agentes pueden pasarse control mutuamente (A→B→A→B...) sin terminar. Siempre define un límite + timeout global + heurística de detección de loop (mismo mensaje repetido). Es uno de los bugs más caros en producción.

---

### 16. ¿Cuál es una decisión típica de **costo/calidad** al diseñar un MAS?

- A) Usar Opus para todo porque "siempre es mejor".
- B) Usar un modelo potente (Opus) para el lead/síntesis y uno barato (Haiku) para los workers especializados.
- C) Usar Haiku para todo porque es más rápido.
- D) Entrenar un modelo propio desde cero para cada agente.

**Respuesta correcta:** B

**Explicación:** El trabajo del lead (planificar, sintetizar, resolver conflictos) exige razonamiento profundo; los workers suelen tener tareas acotadas que modelos pequeños resuelven con la misma calidad por una fracción del costo. Esta heterogeneidad típicamente baja el costo 3-5× sin degradar el F1.

---

### 17. ¿Qué herramienta se usa comúnmente para **observabilidad por agente** (traces, costos, latencias)?

- A) Grafana sin más.
- B) LangSmith, Langfuse o Arize Phoenix.
- C) Jenkins.
- D) Jira.

**Respuesta correcta:** B

**Explicación:** LangSmith (de LangChain), Langfuse (open-source) y Arize Phoenix son plataformas específicas para tracing de LLMs/agentes: muestran spans por agente, tokens, costos, latencia P50/P95, y permiten correr evals. Grafana puede ingerir métricas vía OpenTelemetry pero no es LLM-nativo.

---

### 18. ¿Qué estrategia resuelve el problema de **lecturas stale** del estado compartido?

- A) Usar más tokens.
- B) Versionar el estado y rechazar lecturas con versión obsoleta en operaciones críticas.
- C) Usar un modelo con mayor contexto.
- D) Correr menos agentes en paralelo.

**Respuesta correcta:** B

**Explicación:** Si un agente leyó el contexto en v3 y actúa cuando ya va en v7, su decisión está desactualizada. Un campo `version` o `updated_at` con rechazo/retry en writes críticos (optimistic concurrency control) resuelve el problema. Es análogo a los `ETag` en HTTP.

---

### 19. ¿Qué significa "budget-aware agent"?

- A) Un agente que mide el ancho de banda de la red.
- B) Un agente que trackea su propio gasto en tokens/USD y se detiene cuando excede un límite.
- C) Un agente que negocia precios con la API.
- D) Un agente financiero.

**Respuesta correcta:** B

**Explicación:** Clave en producción: cada agente lleva su cuenta de `spent_usd` y se autodetiene si supera `budget_usd`. Previene que un bug en el loop queme cientos de dólares. Complementa con un **budget global** por conversación y alertas en Langfuse.

---

### 20. ¿Qué patrón de sincronización se usa para **esperar a que todos los agentes paralelos terminen** antes de sintetizar?

- A) Semaphore.
- B) Barrier.
- C) Mutex.
- D) Spinlock.

**Respuesta correcta:** B

**Explicación:** Un **barrier** bloquea al llegar N llamadores y los libera a todos juntos. Es el patrón natural de fan-in después de un fan-out paralelo. `asyncio.gather(...)` implementa esto implícitamente para corrutinas. Mutex serializa accesos, semaphore limita concurrencia, spinlock es busy-waiting (poco útil en async).
