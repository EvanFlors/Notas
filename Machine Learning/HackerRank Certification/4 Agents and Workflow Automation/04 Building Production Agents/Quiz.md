# Quiz: Building Production Agents

Pon a prueba lo aprendido sobre workflows vs agents, state management, observabilidad, costos y despliegue seguro.

---

**1. Según el ensayo *Building Effective Agents* de Anthropic (Dic 2024), ¿cuál es la diferencia fundamental entre un workflow y un agent?**

- En un workflow el LLM decide cada paso; en un agent es el código quien decide.
- En un workflow los LLMs y herramientas se orquestan por **rutas de código predefinidas**; en un agent es el LLM el que **dirige dinámicamente** su propio flujo y uso de herramientas.
- Los workflows siempre son más lentos que los agents.
- Los agents solo pueden usar un modelo, los workflows pueden usar varios.

**Respuesta correcta:** La segunda.

**Explicación:** Anthropic define workflows como sistemas con rutas de código predefinidas (el programador controla el grafo) y agents como sistemas donde el LLM dirige dinámicamente los procesos. La regla práctica: usa el patrón más simple que funcione. Workflow = más control; agent = más flexibilidad.

---

**2. Tu equipo necesita decidir entre workflow y agent para automatizar triage de tickets. Si siempre quieres saber de antemano el camino exacto que seguirá el sistema, ¿qué eliges?**

- Agent, porque es más moderno.
- Workflow, porque el grafo es conocido y determinístico, lo que da más control, menor costo y mejor debugging.
- Un modelo más grande; eso resuelve el no-determinismo.
- Da igual: workflow y agent son equivalentes en control.

**Respuesta correcta:** La segunda.

**Explicación:** Si puedes dibujar el grafo antes de ejecutar, debe ser un workflow. Los workflows son más predecibles, baratos y fáciles de depurar. Los agents aportan autonomía pero cobran impuesto en costo, variabilidad y dificultad de debugging. Construir un agent cuando bastaba un workflow es uno de los errores más comunes en producción.

---

**3. ¿Cuál NO es uno de los cinco patrones de workflow descritos por Anthropic?**

- Prompt chaining
- Routing
- Parallelization
- **Reinforcement looping**
- Orchestrator-workers
- Evaluator-optimizer

**Respuesta correcta:** Reinforcement looping.

**Explicación:** Los cinco patrones canónicos son prompt chaining (pasos secuenciales), routing (clasificar y despachar), parallelization (sectioning/voting en paralelo), orchestrator-workers (orquestador descompone dinámicamente y delega) y evaluator-optimizer (generar + evaluar en loop). "Reinforcement looping" no existe en el documento.

---

**4. Un usuario abre tu chatbot, mantiene una conversación de 20 mensajes, cierra la pestaña y vuelve una hora después. La conversación se perdió. ¿Qué faltó?**

- Más tokens en el context window.
- **State persistente con un checkpointer (`SqliteSaver` / `PostgresSaver`) y un `thread_id` por sesión.**
- Un modelo más grande.
- Más RAM en el servidor.

**Respuesta correcta:** La segunda.

**Explicación:** Sin un checkpointer, el estado vive solo en memoria del proceso. Al cerrar la pestaña (o reiniciar el pod, o deployar), todo se pierde. LangGraph con `PostgresSaver` persiste el estado por `thread_id`, de modo que otro proceso puede reanudar la conversación exactamente donde quedó. Es la base de la resumability.

---

**5. ¿Para qué sirve `interrupt_before` en LangGraph?**

- Para cancelar la ejecución al llegar a un nodo.
- **Para marcar un nodo como punto de pausa: la ejecución se detiene ahí, el estado se persiste, y puede retomarse después (patrón human-in-the-loop).**
- Para acelerar la ejecución saltándose nodos.
- Para desactivar el logging.

**Respuesta correcta:** La segunda.

**Explicación:** `interrupt_before` convierte un nodo en punto de interrupción. Cuando el grafo llega a él, se detiene y el estado queda persistido en el checkpointer. Más tarde, `app.invoke(None, config)` con el mismo `thread_id` reanuda. Es el mecanismo canónico para human-in-the-loop: pausar antes de una acción irreversible y esperar aprobación.

---

**6. ¿Qué horizonte temporal justifica usar Temporal o Inngest en vez de un checkpointer embebido como `PostgresSaver`?**

- Ejecuciones de segundos.
- Ejecuciones de minutos.
- **Flujos durables de horas, días o más, con reintentos, versionado y escalado multi-worker a nivel de plataforma.**
- Siempre; son la única opción válida en producción.

**Respuesta correcta:** La tercera.

**Explicación:** LangGraph + Postgres cubre perfectamente agentes de minutos a horas. Temporal e Inngest aportan primitivas de workflow durable (reintentos idempotentes, versionado del código, workers distribuidos) que son útiles para flujos de días/semanas (onboarding, procesos legales, agentes esperando eventos externos). Elegirlos para un simple chatbot añade complejidad operativa innecesaria.

---

**7. Tu agente de code review completó la ejecución sin errores y aprobó un PR con una inyección SQL. ¿Qué tipo de falla es?**

- Infraestructura; el agente debió crashear.
- **Reasoning failure: el agente terminó bien, pero tomó una decisión incorrecta con confianza (falla silenciosa).**
- Token explosion.
- Rate limiting.

**Respuesta correcta:** La segunda.

**Explicación:** Las reasoning failures son el modo más insidioso: no hay excepción, no hay log de error, el status es 200. El agente razonó mal (quizás se dejó engañar por el nombre `safe_query`) y devolvió un verdict incorrecto. Solo se detectan con **reasoning observability**: loguear decisiones con razonamiento y evidencia, y métricas de calidad (no solo de disponibilidad).

---

**8. ¿Cuál de las tres capas de observabilidad de agentes responde "¿por qué decidió eso?"?**

- Infrastructure observability.
- Behavior observability.
- **Reasoning observability.**
- Latency observability.

**Respuesta correcta:** Reasoning observability.

**Explicación:** Infrastructure = ¿corre? (uptime, latencia, error rate). Behavior = ¿qué hizo? (tool calls, inputs/outputs). Reasoning = ¿por qué decidió eso? (chain-of-thought, evidencia, confianza). Sin la tercera, no puedes depurar reasoning failures. Herramientas como LangSmith, Langfuse, Arize Phoenix y Helicone capturan las tres.

---

**9. Tu agente llama `get_file_content("auth.py")` 47 veces seguidas en la misma ejecución. ¿Qué defensa habría prevenido esto?**

- Un modelo más rápido.
- Un context window más grande.
- **Loop detection + `max_iterations` + token budget: tres guards combinados.**
- Más RAM.

**Respuesta correcta:** La tercera.

**Explicación:** Un agente puede quedarse pidiendo la misma información porque su razonamiento no reconoce que ya la tiene. Las defensas mínimas: (1) rastrear historial de acciones y detectar repeticiones idénticas, (2) `max_iterations` como límite duro, (3) token budget por ejecución. Confiar solo en el timeout HTTP no basta: el agente puede terminar "a tiempo" habiendo gastado $50.

---

**10. ¿Por qué los circuit breakers tradicionales no son suficientes para agentes?**

- Son demasiado lentos.
- **Un circuit breaker clásico se abre con errores; los agentes pueden "no fallar" (sin errores) y aun así producir decisiones incorrectas. Se necesita un *quality circuit breaker* que mida calidad, no solo disponibilidad.**
- Solo funcionan con HTTP.
- Son incompatibles con async.

**Respuesta correcta:** La segunda.

**Explicación:** Un servicio tradicional degrada con errores observables. Un agente degrada en calidad: aprueba todo, da respuestas verbosas pero vacías, pierde hallazgos. El circuit breaker clásico queda cerrado mientras el agente arruina reviews. Necesitas un breaker que rastree correctness (feedback humano, ground truth, agreement con un modelo de referencia) y que, al caer la calidad, enrute a humano.

---

**11. Para reducir el costo de tokens en un code review agent, ¿cuál es la optimización de mayor impacto?**

- Usar siempre el modelo más caro para evitar errores.
- Cargar siempre el archivo completo "por si acaso".
- **Usar diffs en vez de archivos completos (10-20× menos tokens), resumir historia antigua, y hacer model routing (modelo barato para fácil, caro para complejo).**
- Deshabilitar la caché.

**Respuesta correcta:** La tercera.

**Explicación:** Los input tokens dominan el costo. Diffs ahorran 10-20× sobre archivos completos. Summarization evita crecimiento cuadrático de historia conversacional. Model routing usa Haiku para clasificar o tareas simples, Sonnet solo para análisis profundo. Prompt caching (Anthropic/OpenAI) puede ahorrar hasta 90% en system prompts largos repetidos.

---

**12. Pediste al agente una revisión de **seguridad** y terminó dando una revisión de **estilo**. ¿Cómo se llama esto y cómo se previene?**

- Token explosion; se previene con límites de tokens.
- **Goal drift; se previene incluyendo el objetivo en cada iteración, estructurando fases explícitas y validando el output final contra el objetivo original.**
- Reasoning failure; se previene con un modelo más grande.
- Infra failure; se previene con más réplicas.

**Respuesta correcta:** La segunda.

**Explicación:** Goal drift ocurre cuando el agente pierde de vista su objetivo en razonamientos multi-paso: cada paso parece razonable, pero el agregado se desvía. Defensas: reinyectar el goal en cada prompt (`"Recuerda: tu objetivo es X"`), estructurar el trabajo en fases con transiciones explícitas, y validar el verdict final contra el objetivo original antes de publicarlo.

---

**13. ¿Qué es el *shadow mode* en el despliegue de una nueva versión de agente?**

- Ejecutar la nueva versión solo de noche.
- **Correr la nueva versión en paralelo con la actual sobre tráfico real, loguear sus respuestas sin devolverlas al usuario y comparar.**
- Esconder la nueva versión del equipo de QA.
- Desplegar solo en una región.

**Respuesta correcta:** La segunda.

**Explicación:** Shadow mode procesa tráfico real con la nueva versión, pero la respuesta se loguea en vez de servirse. Permite medir agreement rate, costo real y categorías de disenso sin exponer usuarios. Interpretación: agreement > 95% es seguro; shadow más permisivo que prod es peligroso (podría estar perdiendo problemas reales); < 90% requiere revisión manual.

---

**14. Un **cambio de una línea** en el system prompt del agente debe tratarse como:**

- Un cambio trivial que no requiere revisión.
- Puede subirse directo a producción.
- **Un cambio de código: PR, review, eval dataset en CI, shadow test en tráfico real y canary rollout con quality gates.**
- Solo necesita aprobación del PM.

**Respuesta correcta:** La tercera.

**Explicación:** Un cambio de prompt puede alterar el comportamiento del 20% o más de las ejecuciones sin señales obvias. Trátalo como cambio de código: en Git, con PR revisado, pasando por eval dataset (regression gate), shadow mode durante 24-48h y canary (5% → 10% → 25% → 50% → 100%) con umbrales de rollback definidos.

---

**15. ¿Cuál es el error principal al elegir un framework para construir un agente?**

- Elegir uno open-source.
- Usar Python en vez de JavaScript.
- **Elegir el framework (LangGraph, CrewAI, AutoGen, Temporal) antes de decidir el patrón arquitectónico (workflow vs agent, cuál de los cinco patrones).**
- No comprar la versión enterprise.

**Respuesta correcta:** La tercera.

**Explicación:** "Usemos LangGraph" o "usemos CrewAI" es la pregunta equivocada. Primero decide: ¿workflow o agent? ¿Qué patrón (chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer)? Después elige el framework que mejor expresa ese patrón: LangGraph brilla en grafos explícitos con state; CrewAI en roles multi-agente; AutoGen en conversaciones multi-agente; Temporal/Inngest en durabilidad de días.
