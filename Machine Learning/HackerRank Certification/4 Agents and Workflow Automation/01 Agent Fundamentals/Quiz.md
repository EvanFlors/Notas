# Quiz: Agent Fundamentals

Tu equipo construyó un chatbot que responde preguntas sobre código, pero los desarrolladores se frustran porque **no puede ejecutar nada**: ni correr el linter, ni abrir el PR, ni verificar tests. Necesitan convertirlo en un **agente** capaz de analizar pull requests, correr escaneos de seguridad, revisar cobertura y dar feedback accionable, todo manteniendo estado entre pasos y explicando su razonamiento.

---

### 1. ¿Cuál es la diferencia fundamental entre un chatbot y un agente que hace a los agentes mejores para revisar código?

- Los agentes usan modelos de lenguaje más avanzados que los chatbots
- **Los agentes pueden ejecutar workflows multi-paso con tools y mantener estado entre acciones, mientras que los chatbots solo generan texto**
- Los agentes son más rápidos procesando peticiones que los chatbots
- Los agentes dan explicaciones más detalladas que los chatbots

**Respuesta correcta:** Los agentes pueden ejecutar workflows multi-paso con tools y mantener estado entre acciones.

**Explicación:** Un chatbot genera texto *sobre* acciones pero no las ejecuta. Un agente combina **LLM + tools + loop + memoria**: lee el PR, corre el linter, consulta cobertura y encadena esas acciones manteniendo contexto. El modelo subyacente puede incluso ser el mismo; la diferencia es la **arquitectura** (loop de control, tool registry, state management), no la "potencia" del LLM.

---

### 2. En el loop del agente, ¿qué ocurre durante la fase de **observation**?

- El agente decide qué acción tomar según los tools disponibles
- **El agente recibe el feedback de las acciones ejecutadas, que pasa a ser parte de su percepción en la siguiente iteración**
- El agente ejecuta un tool o genera una respuesta al usuario
- El agente entiende su situación actual incluyendo la petición del usuario y el historial

**Respuesta correcta:** El agente recibe el feedback de las acciones ejecutadas.

**Explicación:** El loop clásico es *perceive → reason → act → observe*. La **observation** captura el resultado del tool (respuesta de la API, output del script, excepción) y lo re-inyecta como contexto para la próxima iteración. Sin observation el agente no puede corregir rumbo cuando algo falla: estaría ciego a las consecuencias de sus propias acciones.

---

### 3. ¿Por qué el patrón **ReAct** mejora la calidad de decisión frente a agentes que no "piensan en voz alta"?

- ReAct hace al agente más rápido reduciendo el número de tool calls
- **ReAct obliga al agente a razonar explícitamente antes de actuar, mejorando la calidad de decisión y permitiendo debugging**
- ReAct elimina la necesidad de state management
- ReAct permite al agente saltarse la fase de percepción del loop

**Respuesta correcta:** Obliga al agente a razonar explícitamente antes de actuar.

**Explicación:** ReAct (Yao et al., 2022) intercala `Thought → Action → Observation`. Verbalizar el razonamiento **antes** de la acción forzó mejoras medibles en benchmarks como HotpotQA y ALFWorld, y produce **trazas auditables**: cuando el agente se equivoca, puedes leer su Thought y detectar si le faltó contexto, malinterpretó una observation o eligió la tool incorrecta. La transparencia no es un extra, es parte del valor del patrón.

---

### 4. Al diseñar tools para un agente de code review, ¿por qué una abstracción **media** (como `get_pr_details(pr_number)`) es mejor que muy baja (`github_api_call(endpoint, method)`) o muy alta (`merge_pr_if_approved(pr_number)`)?

- Las tools de nivel medio son más rápidas de ejecutar
- **Las tools de nivel medio dan el balance correcto: mapean a operaciones de dominio significativas y siguen siendo componibles para escenarios diversos**
- Las tools de nivel medio requieren menos validación
- Las tools de nivel medio son las únicas que los agentes pueden usar de forma confiable

**Respuesta correcta:** Dan el balance entre flexibilidad y simplicidad.

**Explicación:** Las tools de **bajo nivel** (API raw) exigen que el agente conozca pagination, encoding y headers → muchos errores. Las de **alto nivel** esconden lógica rígida y no cubren variantes ("¿y si quiero mergear con otra estrategia?"). Las de **nivel medio** reflejan operaciones del dominio (como endpoints REST bien diseñados para humanos) y se componen libremente: `get_pr_details → analyze_security → add_comment → merge_pr`.

---

### 5. Tu agente necesita recordar que ya revisó el módulo de autenticación. ¿Qué tipo de memoria es más apropiado para el estado de la tarea actual?

- **Episodic**, que guarda interacciones pasadas como episodios discretos
- **Working**, que mantiene la conversación actual, acciones recientes y observaciones inmediatas
- **Semantic**, que guarda conocimiento general y patrones aprendidos
- **Procedural**, que guarda procedimientos y workflows aprendidos

**Respuesta correcta:** Working memory.

**Explicación:** **Working memory** es el equivalente a la memoria de trabajo humana: vive en el context window del LLM y rastrea *lo que está pasando en esta sesión* (qué chequeaste, qué falta, qué observaste). Episodic serviría para recordar *"hace dos semanas revisé un PR parecido"*; semantic para *"el módulo auth suele tener bugs de validación"*; procedural para *"el playbook de review de seguridad tiene 5 pasos"*. Para "¿ya revisé auth en esta corrida?", es working.

---

### 6. Tras 50 tool calls el historial no cabe en el context window. ¿Qué mitigación encaja mejor con los fundamentos?

- Aumentar el tamaño del context window para que quepa todo
- **Resumir el historial viejo, mantener solo las acciones recientes en detalle y diseñar agentes que resuelvan tareas en menos pasos**
- Borrar todo el historial después de cada tool call
- Usar un modelo más rápido que pueda procesar contextos mayores

**Respuesta correcta:** Resumir el historial viejo + retener solo recientes + reducir pasos.

**Explicación:** El **context explosion** se ataca con compresión: *summarization* de steps antiguos, *selective retention* de los importantes, *hierarchical state* por fases y *sliding window*. Aumentar el context window es un parche caro (más tokens = más dólares por llamada y peor calidad por *lost-in-the-middle*). Borrar todo rompe la continuidad. Cambiar de modelo no resuelve el problema de diseño: si tu agente necesita 50 iteraciones, probablemente le faltan tools de más alto nivel o le sobra re-trabajo.

---

### 7. Tu agente de code review debe decidir qué checks correr, ejecutarlos, trackear cuáles ya completó y prevenir merges sin autorización. ¿Qué componente trackea los checks completados?

- El **reasoning engine**, que analiza PRs y decide qué checks correr
- **State management**, que trackea lo que ha pasado entre iteraciones del loop, incluyendo acciones completadas**
- El **execution layer**, que corre los tools de seguridad
- **Safety controls**, que previenen acciones dañinas como merges no autorizados

**Respuesta correcta:** State management.

**Explicación:** Cada componente tiene su responsabilidad: el **reasoning engine** (el LLM) decide; el **execution layer** ejecuta tools; **safety controls** aplican permisos y rate limits. El **state management** es la memoria del loop: guarda qué tools se llamaron, con qué parámetros, qué devolvieron y qué queda por hacer. Sin esa capa, el agente no sabría que ya corrió el escaneo de seguridad y lo repetiría indefinidamente.
