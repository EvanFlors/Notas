# De Chatbots a Agentes

## ¿Qué es?

Un **agente de IA** es un sistema que combina un **LLM como motor de razonamiento**, un conjunto de **herramientas (tools)** que puede invocar, un **loop de ejecución** que decide qué hacer en cada paso, y algún tipo de **memoria** para mantener contexto entre iteraciones. A diferencia de un chatbot —que solo genera texto en respuesta a un prompt— un agente **percibe su entorno, decide, actúa y observa el resultado**, repitiendo el ciclo hasta cumplir un objetivo o determinar que no puede continuar.

La definición operativa que popularizó Anthropic en su guía *Building Effective Agents* (diciembre 2024) distingue tres niveles:

| Sistema | Qué hace | Control del flujo |
|---|---|---|
| **Chatbot** | Genera una respuesta a un prompt | Nulo: una entrada, una salida |
| **Workflow** | Encadena LLMs y tools por **caminos predefinidos** en código | **Determinístico**: lo decide el ingeniero |
| **Agente** | El LLM decide dinámicamente qué tools llamar y cuándo detenerse | **No determinístico**: lo decide el modelo |

> **Definición de Anthropic (2024):** *"Los agentes son sistemas donde los LLMs dirigen dinámicamente sus propios procesos y uso de herramientas, manteniendo el control sobre cómo realizan las tareas."*

### Agente vs Workflow vs Chatbot

La diferencia no es cosmética: define quién tiene el control del flujo.

```
Chatbot:    prompt ──► LLM ──► respuesta
Workflow:   prompt ──► LLM₁ ──► tool_A ──► LLM₂ ──► tool_B ──► respuesta
                      (los pasos están cableados en código)
Agent:      prompt ──► ┌──► LLM decide ──► tool ──► observa ──┐
                       └────────────── loop ──────────────────┘
                                     (el LLM decide cuándo parar)
```

Un chatbot pierde el control después de responder. Un workflow sigue un grafo escrito por el ingeniero (ej. `LangGraph` con nodos conectados a mano). Un agente **recibe un objetivo y herramientas, y el modelo elige la ruta**.

### Los cuatro componentes mínimos de un agente

1. **LLM (reasoning engine):** cerebro que decide qué hacer. Hoy: Claude 3.5/4, GPT-4/5, Llama 3+, Gemini.
2. **Tools (herramientas):** funciones externas con nombre, descripción y schema de parámetros. El modelo las "llama" devolviendo JSON estructurado.
3. **Loop (bucle de control):** código que ejecuta la tool pedida, inyecta el resultado al modelo y vuelve a preguntar "¿qué sigue?".
4. **Memory (memoria):** historial de la conversación actual (short-term) y, opcionalmente, conocimiento persistente entre sesiones (long-term).

Falta cualquiera de los cuatro y deja de ser un agente completo. Un LLM con tools pero sin loop es *function calling* clásico. Un loop sin memoria olvida lo que acaba de hacer en la iteración anterior.

## ¿Por qué importa?

Los chatbots alcanzan su techo rápido: hablan sobre acciones pero no las ejecutan. Un asistente que explica cómo revisar un PR no sirve si no puede abrir el diff, correr el linter y comentar la línea 45. El salto de "describir" a "hacer" es lo que convirtió a los LLMs de **demos impresionantes** en **herramientas de trabajo**.

Los agentes son la respuesta correcta cuando:

- El flujo **no se puede enumerar de antemano** (soporte al cliente con tickets heterogéneos).
- El número de pasos depende del **estado del mundo** (debugging: ¿cuántos logs hay que leer?).
- Hace falta **combinar varias APIs** y la combinación cambia según el caso.
- El valor viene de **adaptarse** a entradas que el diseñador no vio.

Para flujos fijos y predecibles (backup nocturno, validar un formulario, generar un reporte cada lunes) un **workflow determinístico sigue siendo mejor**: más rápido, más barato, más fácil de testear. La regla de oro de Anthropic: *"use the simplest solution possible, and only increase complexity when needed."* Agentes solo cuando ganan algo real.

### Contexto histórico

| Año | Hito |
|---|---|
| 2022 | ReAct paper (Yao et al., Princeton + Google): *"Synergizing Reasoning and Acting in LLMs"* |
| 2023 | AutoGPT, BabyAGI: primeros agentes "autónomos" virales, caóticos pero prueba de concepto |
| 2023 | OpenAI function calling en GPT-4; LangChain populariza el patrón `AgentExecutor` |
| 2024 | LangGraph (grafos de agentes), CrewAI (multi-agente), Anthropic Computer Use |
| 2024 | Anthropic publica *Building Effective Agents* y recomienda **empezar con workflows**, no con agentes |
| 2025 | OpenAI Assistants API, Anthropic MCP (Model Context Protocol), agentes en producción masiva |

## ¿Cómo funciona?

### El loop clásico: observe → think → act → observe

Todo agente ejecuta variantes de este bucle:

```
┌─────────────────────────────────────────────────┐
│  1. PERCEPCIÓN:  leer estado (goal + historial) │
│  2. RAZONAMIENTO: LLM decide siguiente acción   │
│  3. ACCIÓN:      ejecutar tool (o responder)    │
│  4. OBSERVACIÓN: capturar resultado             │
│                                                 │
│  ¿objetivo cumplido? ──NO──► volver al paso 1   │
│                      ──SÍ──► entregar respuesta │
└─────────────────────────────────────────────────┘
```

**Perception:** el agente lee la petición del usuario, el historial de pasos previos, los tools disponibles y cualquier contexto cargado (memoria, documentos).

**Reasoning:** el LLM analiza qué sabe y qué le falta. Decide: "¿llamo un tool para obtener más datos, o ya puedo responder?".

**Action:** se ejecuta la decisión. Si es un tool call, el loop invoca la función real (API, DB, script). Si es `respond`, el agente termina.

**Observation:** el resultado del tool (JSON, texto, error) se guarda en el historial y se le re-inyecta al modelo en la siguiente iteración.

### Componentes de arquitectura en producción

| Componente | Responsabilidad | Ejemplo |
|---|---|---|
| **Reasoning engine** | LLM que decide la próxima acción | Claude 3.5 Sonnet, GPT-4o |
| **Tool registry** | Catálogo de funciones con nombre + descripción + schema | Lista de `tools=[...]` que se le pasa al modelo |
| **Execution layer** | Ejecuta el tool real, maneja errores, formatea el output | Dispatcher que mapea `tool_name → función Python` |
| **State / memory** | Historial de thoughts, actions, observations | Lista en RAM, Redis, o DB persistente |
| **Safety controls** | Permisos, rate limiting, cost caps, validación | `if calls > 10: stop`, allowlist de tools |

### Agente vs automatización tradicional

| Dimensión | Script tradicional | Agente LLM |
|---|---|---|
| Flujo | Fijo, codificado en `if/else` | Decidido por el LLM en runtime |
| Adaptabilidad | Solo casos previstos | Generaliza a situaciones nuevas |
| Latencia | Milisegundos | Segundos (cada iteración = llamada LLM) |
| Costo por ejecución | Casi cero | $$ (tokens por iteración) |
| Predictibilidad | Alta | Baja (no determinístico) |
| Debuggabilidad | Logs claros, stack traces | Requiere trazas de reasoning |
| Mejor para | Backup, validación, cálculos | Soporte, triage, investigación |

## Ejemplo con código

### Agent loop desde cero con Anthropic SDK

```python
from anthropic import Anthropic
import json

client = Anthropic()

# 1) Tool registry: funciones reales que el agente puede llamar
def get_build_logs(build_id: str) -> str:
    return f"[build {build_id}] ImportError: cannot import name 'deprecated' from 'library-name'"

def search_error_patterns(error: str) -> str:
    if "ImportError" in error:
        return "Patrón común: versión incompatible de dependencia. Fijar en requirements.txt."
    return "Sin patrón conocido."

def suggest_fix(issue: str) -> str:
    return "Fijar 'library-name==2.1.0' en requirements.txt y re-ejecutar CI."

TOOLS_IMPL = {
    "get_build_logs": get_build_logs,
    "search_error_patterns": search_error_patterns,
    "suggest_fix": suggest_fix,
}

# 2) Schema que el modelo necesita para elegir tools
TOOLS_SCHEMA = [
    {
        "name": "get_build_logs",
        "description": "Obtiene los logs de un build de CI por ID.",
        "input_schema": {
            "type": "object",
            "properties": {"build_id": {"type": "string"}},
            "required": ["build_id"],
        },
    },
    {
        "name": "search_error_patterns",
        "description": "Busca el patrón de un error en una base de errores conocidos.",
        "input_schema": {
            "type": "object",
            "properties": {"error": {"type": "string"}},
            "required": ["error"],
        },
    },
    {
        "name": "suggest_fix",
        "description": "Sugiere una solución para un tipo de problema identificado.",
        "input_schema": {
            "type": "object",
            "properties": {"issue": {"type": "string"}},
            "required": ["issue"],
        },
    },
]

# 3) El loop: observe → think → act → observe
def agent_loop(goal: str, max_iterations: int = 10) -> str:
    messages = [{"role": "user", "content": goal}]

    for i in range(max_iterations):
        response = client.messages.create(
            model="claude-3-5-sonnet-latest",
            max_tokens=1024,
            tools=TOOLS_SCHEMA,
            messages=messages,
        )

        # Caso 1: el modelo responde texto final (no pide tools) → terminar
        if response.stop_reason == "end_turn":
            return "".join(b.text for b in response.content if b.type == "text")

        # Caso 2: el modelo pide uno o más tool_use
        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                fn = TOOLS_IMPL[block.name]
                result = fn(**block.input)   # ejecutamos la tool real
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": str(result),
                })

        messages.append({"role": "user", "content": tool_results})

    return "Se alcanzó el máximo de iteraciones sin completar el objetivo."


print(agent_loop("¿Por qué falló el build #1247?"))
```

Qué está pasando:

1. El modelo recibe el goal y el catálogo de tools.
2. Decide llamar `get_build_logs(build_id="1247")` → recibe el log.
3. Observa un `ImportError` → decide llamar `search_error_patterns`.
4. Observa el patrón → llama `suggest_fix`.
5. Con todo el contexto, genera la respuesta final (`stop_reason="end_turn"`).

### Mismo agente con LangGraph (grafo explícito)

LangGraph es la forma recomendada hoy para agentes en producción: convierte el loop en un **grafo de estados** auditable.

```python
from langgraph.prebuilt import create_react_agent
from langchain_anthropic import ChatAnthropic
from langchain_core.tools import tool

@tool
def get_build_logs(build_id: str) -> str:
    """Obtiene logs de un build de CI."""
    return f"[build {build_id}] ImportError: cannot import name 'deprecated'"

@tool
def suggest_fix(issue: str) -> str:
    """Sugiere una solución para un issue."""
    return "Fijar 'library-name==2.1.0' en requirements.txt."

llm = ChatAnthropic(model="claude-3-5-sonnet-latest")
agent = create_react_agent(llm, tools=[get_build_logs, suggest_fix])

result = agent.invoke({"messages": [("user", "¿Por qué falló el build #1247?")]})
print(result["messages"][-1].content)
```

En 10 líneas tienes el mismo bucle, pero con streaming, checkpointing, resumabilidad y trazas listos para producción.

## Errores comunes

- **Infinite loops.** El agente pide la misma tool con los mismos parámetros, falla, y vuelve a pedirla. Mitigación: detección de loops (3 fallos iguales → stop) y `max_iterations` **siempre** definido.
- **No límites de iteraciones.** Un `while True` sin tope convierte un bug en una factura de miles de dólares. Define `max_iterations` y un `max_cost_usd` por ejecución.
- **No manejar errores de tools.** Si una tool lanza una excepción, el loop crashea. Captura el error y devuélveselo al modelo como `observation` para que **razone sobre el fallo** y pruebe otra cosa.
- **Context explosion.** Después de 30 iteraciones el historial satura el context window y el costo por llamada se dispara. Mitigación: resumir historial viejo, retener solo pasos "high importance", limitar herramientas por fase.
- **Agentes sin memoria entre runs.** Cada sesión parte de cero, el agente repite trabajo ya hecho ayer. Mitigación: persistir conversaciones en DB (ej. `langgraph.checkpoint.sqlite`) y recuperarlas por `thread_id`.
- **Descripciones de tools vagas.** "Reviews code" es inútil; el modelo no sabe cuándo llamarla. Escribe descripciones ricas con *qué hace, cuándo usarla, qué devuelve*.
- **Usar un agente cuando bastaba un workflow.** Si siempre haces `A → B → C`, cablealo. No le pagues al LLM por "decidir" lo evidente.
- **Confiar en el `stop_reason` del modelo.** El modelo puede alucinar que terminó. Valida tú mismo que el goal se cumplió (criterios de aceptación medibles).

## Resumen

- Un **agente** = LLM + tools + loop + memoria. Sin cualquiera de los cuatro, es otra cosa.
- **Chatbot** responde, **workflow** sigue un grafo fijo, **agente** elige dinámicamente qué tool llamar.
- El **loop clásico** es *perceive → reason → act → observe*, repetido hasta cumplir el goal o toparse con un límite.
- Producción exige **cinco componentes**: reasoning engine, tool registry, execution layer, state management y safety controls.
- Anthropic (dic 2024) recomienda **empezar con la solución más simple** y escalar a agentes solo cuando el flujo no se puede predecir.
- Agentes son **flexibles pero lentos, caros y no determinísticos**: úsalos donde la flexibilidad justifique el costo.
- Los errores clásicos son **loops infinitos, context explosion, fallos de tools sin manejar y falta de límites**: diseña defensas desde el día uno.
- Hoy el stack típico es **Anthropic/OpenAI SDK + LangGraph** (o LlamaIndex / CrewAI para multi-agente); evita montarlo todo a mano salvo para aprender.
