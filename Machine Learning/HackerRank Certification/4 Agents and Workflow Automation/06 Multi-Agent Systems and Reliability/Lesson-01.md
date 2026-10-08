# Sistemas Multi-Agente: Cuándo un solo agente no basta

## ¿Qué es?

Un **sistema multi-agente (MAS)** es una arquitectura donde **varios agentes LLM especializados colaboran** para resolver una tarea que un solo agente generalista no podría atender con suficiente profundidad. Cada agente tiene un **rol**, un **prompt** y un **conjunto de herramientas** acotado, y se comunican mediante un **orquestador**, un **bus de mensajes** o un **estado compartido**.

> **Idea clave:** así como ningún ingeniero senior revisa simultáneamente seguridad, performance, estilo y tests con la misma profundidad, un solo agente LLM que "lo hace todo" termina siendo mediocre en todo. La **especialización + coordinación** es lo que permite escalar la calidad.

El contraste frente a un agente único:

| Dimensión | Agente único (generalista) | Sistema multi-agente |
|---|---|---|
| Prompt | Enorme, lleno de instrucciones | Varios prompts cortos y enfocados |
| Contexto por tarea | Todo mezclado | Cada agente ve solo lo relevante |
| Profundidad por dominio | Superficial | Experta por área |
| Paralelismo | Secuencial por naturaleza | Agentes corren en paralelo |
| Resiliencia a fallos | Un error tumba todo | Fallos aislados por agente |
| Costo | 1 llamada grande | N llamadas pequeñas (puede ser más caro) |
| Observabilidad | Una traza larga | Traza por agente, más fácil de depurar |
| Latencia | Alta por un solo turno largo | Depende: paralelo baja, secuencial sube |

### ¿Cuándo usar multi-agente?

| Situación | ¿Multi-agente? | Razón |
|---|---|---|
| Tarea con **múltiples dominios de experticia** | Sí | Especialización profunda |
| Trabajo **paralelizable** (research en varias fuentes) | Sí | Reduce latencia |
| Flujo con **roles claros** (PM, dev, QA) | Sí | Mapea a la estructura humana |
| Tarea **lineal y simple** (resumir un email) | No | Overhead sin beneficio |
| **Latencia crítica** < 1s | Rara vez | Coordinación añade saltos |
| **Presupuesto limitado** | Con cuidado | MAS multiplica tokens |

### Patrones arquitectónicos principales

```
Supervisor–Worker          Swarm (hand-off)         Jerárquico
                                                   
    [Supervisor]              [A] ↔ [B]            [CEO]
     /   |   \                 ↕     ↕              /  \
   [W1][W2][W3]               [C] ↔ [D]        [Mgr] [Mgr]
                                                 / \   / \
                                               [W][W][W][W]
```

- **Supervisor–Worker:** un router central decide a qué worker delegar y sintetiza. Ideal cuando hay un "jefe" claro.
- **Swarm (hand-off):** los agentes se transfieren el control entre pares. Popularizado por *OpenAI Swarm* (ahora **Agents SDK**).
- **Jerárquico:** supervisores de supervisores. Útil en organizaciones simuladas tipo **MetaGPT**.
- **Debate / consenso:** varios agentes argumentan y un árbitro decide. Mejora calidad a costa de latencia.
- **Pipeline:** salida de A alimenta a B alimenta a C. Simple y predecible.

## ¿Por qué importa?

El salto de "chatbot con tools" a "sistema que resuelve problemas reales" casi siempre pasa por multi-agente. Anthropic reportó en 2025 (*How we built Multi-Agent Research*) que su sistema de investigación con **subagentes paralelos** superaba a Claude Opus solo por **~90% en benchmarks internos** de research, principalmente porque podía explorar en paralelo múltiples líneas de evidencia.

Importa porque:

- **Un prompt gigante no escala:** más de ~15 responsabilidades en un solo system prompt degrada el seguimiento de instrucciones.
- **El contexto es finito:** incluso con 1M tokens, meter toda la base de código, documentación y herramientas en una sola llamada es ineficiente y caro.
- **La paralelización ahorra tiempo real:** 5 agentes en paralelo con 30s cada uno terminan en 30s, no en 150s.
- **La modularidad acelera el desarrollo:** cambiar el agente de seguridad no toca el de performance.
- **Permite roles con permisos distintos:** el agente que lee código no necesita permisos de escritura; el que ejecuta en producción sí.

### Casos de uso en producción (2024-2026)

| Sistema | Patrón | Agentes típicos |
|---|---|---|
| **Claude Code** | Supervisor + subagentes paralelos (Task tool) | Explore, Plan, code-review, test-runner |
| **Anthropic Research** | Supervisor con N workers de búsqueda | Planner, N searchers, synthesizer |
| **Cursor Composer** | Pipeline + hand-off | Planner → editor → verifier |
| **Devin (Cognition)** | Jerárquico con shell/browser/editor | Planner, coder, debugger |
| **Harvey (legal)** | Supervisor por tarea legal | Research, drafting, citation-check |
| **MetaGPT** | Jerárquico (empresa simulada) | PM, Architect, Engineer, QA |

### Frameworks comparados

| Framework | Patrón nativo | Estado (2026) | Fortaleza |
|---|---|---|---|
| **LangGraph** | Grafo de estados (supervisor, swarm) | Maduro | Control explícito, checkpoints, streaming |
| **CrewAI** | Roles + tareas secuenciales/paralelas | Maduro | Prompt-first, fácil para prototipos |
| **AutoGen** (Microsoft) | GroupChat + conversación entre agentes | Maduro, v0.4+ | Flexibilidad conversacional, code-execution |
| **OpenAI Agents SDK** | Hand-off (sucesor de Swarm) | Estable | Simple, nativo con tools de OpenAI |
| **Anthropic Agent SDK** | Subagentes vía Task tool | Reciente | Integración directa con Claude |
| **MetaGPT** | SOP de empresa simulada | Nicho | Flujos tipo waterfall |
| **LlamaIndex Agents** | Workflows (event-driven) | Maduro | Enfocado en RAG multi-paso |

## ¿Cómo funciona?

Un sistema multi-agente mínimo tiene cinco piezas:

1. **Agentes especializados:** cada uno con prompt, tools y modelo (puede variar: Opus para planner, Haiku para workers).
2. **Orquestador / router:** decide quién actúa y en qué orden.
3. **Protocolo de mensajes:** formato común para que los agentes se entiendan.
4. **Estado / memoria compartida:** base de datos, vector store o blackboard donde se acumula el contexto.
5. **Capa de confiabilidad:** timeouts, reintentos, circuit breakers, control de costo.

### Patrón 1: Supervisor–Worker (el más común)

```
                 ┌─────────────┐
   Usuario ──▶   │ Supervisor  │  ──▶  decide: ¿qué worker?
                 └──────┬──────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    [Security]    [Performance]    [Testing]
         │              │              │
         └──────────────┼──────────────┘
                        ▼
                  Síntesis final
```

El **supervisor** no analiza: **enruta y sintetiza**. Los workers hacen el trabajo pesado. Esta separación evita el anti-patrón de "orquestador que lo hace todo".

### Patrón 2: Subagentes paralelos (Anthropic Research)

El supervisor **lanza N subagentes en paralelo** con sub-tareas independientes, espera a que todos terminen y agrega los resultados. Es el patrón detrás del Task tool de Claude.

```
Prompt del usuario
       │
       ▼
   [Lead Agent] ── genera plan: [subtask_1, subtask_2, ..., subtask_N]
       │
       ├──▶ [Subagent 1] (contexto propio, tools propias)
       ├──▶ [Subagent 2]
       ├──▶ ...
       └──▶ [Subagent N]
                │
                ▼
       [Lead Agent] ── sintetiza resultados
```

Ventaja clave: **el lead agent no consume tokens** mientras los subagentes trabajan. Y cada subagente tiene su propio contexto limpio.

### Patrón 3: Swarm / Hand-off

Los agentes se pasan el control explícitamente. No hay supervisor; cada agente decide a quién transferir cuando su rol termina.

```python
# OpenAI Agents SDK (sucesor de Swarm)
triage_agent.handoffs = [billing_agent, support_agent]
# Si el triage detecta "quiero cancelar mi plan", hace handoff a billing
```

### Comunicación entre agentes

Tres estilos principales:

| Estilo | Cómo funciona | Cuándo |
|---|---|---|
| **Direct call** | Agente A llama al agente B como función | Jerárquico simple |
| **Message bus** | Publicar/suscribir en topics | Muchos agentes desacoplados |
| **Shared state (blackboard)** | Todos leen/escriben a un objeto común | LangGraph state, trabajo colaborativo |

### Descomposición de tareas

El supervisor convierte una tarea compleja en subtareas. Heurísticas:

- **MECE** (Mutually Exclusive, Collectively Exhaustive): subtareas sin solapar que juntas cubren todo.
- **Grano adecuado:** ni tan grande que un worker se abrume, ni tan pequeño que la coordinación domine.
- **Explicitar dependencias:** `subtask_3 requires outputs of subtask_1, subtask_2`.

### Consenso y resolución de conflictos

Cuando dos agentes contradicen (seguridad dice "no uses eval"; performance dice "usa eval, es más rápido"):

| Estrategia | Descripción |
|---|---|
| **Prioridad fija** | Seguridad > correctness > performance > estilo |
| **Votación mayoritaria** | N agentes votan; umbral configurable (ej. 0.6) |
| **Árbitro** | Un agente adicional (más poderoso) decide |
| **Debate** | Agentes argumentan en rondas, árbitro cierra |
| **Reportar ambas** | Dejar la decisión al humano |

## Ejemplo con código

### 1) Supervisor–Worker con LangGraph

```python
from typing import TypedDict, Annotated, Literal
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage

class ReviewState(TypedDict):
    messages: Annotated[list, add_messages]
    pr_diff: str
    findings: list[dict]
    next_agent: str

llm = ChatAnthropic(model="claude-opus-4-5", temperature=0)
cheap_llm = ChatAnthropic(model="claude-haiku-4-5", temperature=0)

# --- Workers especializados ---
def security_worker(state: ReviewState) -> ReviewState:
    prompt = SystemMessage(content=(
        "Eres un revisor de SEGURIDAD. Busca inyecciones (SQL, XSS, command), "
        "secretos hardcoded, autenticación rota. Responde JSON con findings. "
        "NO comentes estilo ni performance."
    ))
    resp = cheap_llm.invoke([prompt, HumanMessage(content=state["pr_diff"])])
    return {"findings": state["findings"] + [{"agent": "security", "text": resp.content}]}

def performance_worker(state: ReviewState) -> ReviewState:
    prompt = SystemMessage(content=(
        "Eres un revisor de PERFORMANCE. Busca N+1, O(n²) evitable, falta de caching. "
        "Responde JSON. NO comentes seguridad."
    ))
    resp = cheap_llm.invoke([prompt, HumanMessage(content=state["pr_diff"])])
    return {"findings": state["findings"] + [{"agent": "performance", "text": resp.content}]}

def testing_worker(state: ReviewState) -> ReviewState:
    prompt = SystemMessage(content=(
        "Eres un revisor de TESTING. Verifica cobertura y casos borde. Responde JSON."
    ))
    resp = cheap_llm.invoke([prompt, HumanMessage(content=state["pr_diff"])])
    return {"findings": state["findings"] + [{"agent": "testing", "text": resp.content}]}

# --- Supervisor: enruta y sintetiza ---
def supervisor(state: ReviewState) -> ReviewState:
    done = {f["agent"] for f in state["findings"]}
    pending = {"security", "performance", "testing"} - done
    if not pending:
        return {"next_agent": "synthesize"}
    # Prioridad: siempre seguridad primero
    nxt = "security" if "security" in pending else next(iter(pending))
    return {"next_agent": nxt}

def synthesize(state: ReviewState) -> ReviewState:
    summary_prompt = (
        "Sintetiza las revisiones. Prioridad: seguridad > correctness > performance.\n\n"
        + "\n\n".join(f["text"] for f in state["findings"])
    )
    resp = llm.invoke([HumanMessage(content=summary_prompt)])
    return {"messages": [resp]}

def route(state: ReviewState) -> Literal["security", "performance", "testing", "synthesize"]:
    return state["next_agent"]

# --- Grafo ---
graph = StateGraph(ReviewState)
graph.add_node("supervisor", supervisor)
graph.add_node("security", security_worker)
graph.add_node("performance", performance_worker)
graph.add_node("testing", testing_worker)
graph.add_node("synthesize", synthesize)

graph.set_entry_point("supervisor")
graph.add_conditional_edges("supervisor", route, {
    "security": "security",
    "performance": "performance",
    "testing": "testing",
    "synthesize": "synthesize",
})
for w in ["security", "performance", "testing"]:
    graph.add_edge(w, "supervisor")
graph.add_edge("synthesize", END)

app = graph.compile()
result = app.invoke({"messages": [], "pr_diff": "<diff>", "findings": [], "next_agent": ""})
```

### 2) CrewAI con roles

```python
from crewai import Agent, Task, Crew, Process

security_reviewer = Agent(
    role="Security Reviewer",
    goal="Encontrar vulnerabilidades críticas en el diff",
    backstory="Eres un pentester senior con 10 años en app-sec.",
    tools=[],
    allow_delegation=False,
    max_iter=5,
)

performance_reviewer = Agent(
    role="Performance Reviewer",
    goal="Identificar cuellos de botella y O(n²) evitables",
    backstory="Expert en profiling y optimización.",
    allow_delegation=False,
    max_iter=5,
)

lead = Agent(
    role="Review Lead",
    goal="Sintetizar hallazgos y producir el veredicto final",
    backstory="Tech lead que resuelve conflictos entre especialistas.",
    allow_delegation=True,
)

task_sec  = Task(description="Analiza seguridad del PR {diff}", agent=security_reviewer, expected_output="JSON de findings")
task_perf = Task(description="Analiza performance del PR {diff}", agent=performance_reviewer, expected_output="JSON de findings")
task_lead = Task(description="Sintetiza y decide approve/request_changes", agent=lead,
                 context=[task_sec, task_perf], expected_output="Reporte markdown")

crew = Crew(
    agents=[security_reviewer, performance_reviewer, lead],
    tasks=[task_sec, task_perf, task_lead],
    process=Process.sequential,   # también Process.hierarchical
    verbose=True,
    max_rpm=20,                   # control de rate limit
)
result = crew.kickoff(inputs={"diff": "<pr diff>"})
```

### 3) AutoGen GroupChat

```python
from autogen import AssistantAgent, UserProxyAgent, GroupChat, GroupChatManager

llm_config = {"model": "claude-opus-4-5", "temperature": 0}

security = AssistantAgent("security", system_message="Solo analiza seguridad.", llm_config=llm_config)
perf     = AssistantAgent("perf", system_message="Solo analiza performance.", llm_config=llm_config)
lead     = AssistantAgent("lead", system_message="Coordina y sintetiza. Prioridad: seguridad.", llm_config=llm_config)
user     = UserProxyAgent("user", human_input_mode="NEVER", code_execution_config=False)

chat = GroupChat(
    agents=[user, security, perf, lead],
    messages=[],
    max_round=12,                 # evita loops infinitos
    speaker_selection_method="round_robin",
)
manager = GroupChatManager(groupchat=chat, llm_config=llm_config)
user.initiate_chat(manager, message="Revisa este PR: <diff>")
```

### 4) Patrón de subagentes paralelos (estilo Anthropic Research)

```python
import asyncio
from anthropic import AsyncAnthropic

client = AsyncAnthropic()

async def subagent(subtask: str, idx: int) -> dict:
    """Cada subagente tiene su propio contexto limpio."""
    resp = await client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=1024,
        system=f"Eres el subagente {idx}. Resuelve SOLO esta subtarea con herramientas de búsqueda.",
        messages=[{"role": "user", "content": subtask}],
    )
    return {"idx": idx, "result": resp.content[0].text}

async def lead_agent(user_query: str) -> str:
    # 1) Plan: el lead descompone en subtareas
    plan = await client.messages.create(
        model="claude-opus-4-5",
        max_tokens=2048,
        system="Descompón la pregunta en 3-5 subtareas independientes. Responde JSON list.",
        messages=[{"role": "user", "content": user_query}],
    )
    import json
    subtasks = json.loads(plan.content[0].text)

    # 2) Lanzar subagentes EN PARALELO (clave del speedup)
    results = await asyncio.gather(*[subagent(st, i) for i, st in enumerate(subtasks)])

    # 3) Síntesis: el lead agrega
    synth = await client.messages.create(
        model="claude-opus-4-5",
        max_tokens=4096,
        system="Sintetiza los resultados de los subagentes en una respuesta cohesiva con citas.",
        messages=[{"role": "user", "content": f"Query: {user_query}\n\nResultados: {results}"}],
    )
    return synth.content[0].text
```

> Este patrón fue el núcleo del post *"How we built our Multi-Agent Research System"* de Anthropic (2025): un **lead Opus** coordinando **N subagentes Haiku/Sonnet** en paralelo, con una ganancia reportada de ~90% en calidad de research vs. agente único, al costo de 15× más tokens.

## Errores comunes

- **Multi-agente para todo:** no todo problema requiere MAS. Un agente bien construido con tools suele vencer a 5 agentes mal diseñados. Empieza con uno y agrega especialistas solo cuando el prompt se vuelva inmanejable (>500 líneas).
- **Agent-to-agent ping-pong infinito:** sin `max_rounds`/`max_steps`, dos agentes pueden pasarse control eternamente. Siempre define un límite duro y un timeout global.
- **Prompts sin "stay in your lane":** si el agente de seguridad también comenta estilo, duplicas trabajo y confundes al sintetizador. Incluye explícitamente qué NO debe hacer.
- **Orquestador que analiza:** el supervisor debe enrutar y sintetizar, no hacer el trabajo pesado. Si tu orchestrator usa el 70% de los tokens, perdiste el beneficio del paralelismo.
- **Sin presupuesto por run:** MAS multiplica tokens. Sin `max_cost_usd` o `max_tokens_total`, un bug puede quemar cientos de dólares en una ejecución.
- **Sin observabilidad por agente:** cuando algo falla, necesitas saber *cuál* agente, en *qué* iteración y con *qué* contexto. Usa **LangSmith**, **Langfuse** o **Arize Phoenix** desde el día uno.
- **Race conditions en estado compartido:** si dos agentes escriben al blackboard sin lock, se pisan los hallazgos. Usa `asyncio.Lock`, transacciones, o CRDTs.
- **Elegir el framework antes del problema:** CrewAI es rápido para prototipos; LangGraph si necesitas control; AutoGen si quieres conversación emergente; Agents SDK para hand-offs simples. Elige por el patrón, no por el hype.

## Resumen

- Los **sistemas multi-agente** reemplazan al agente generalista con **especialistas que colaboran**, imitando cómo trabajan los equipos humanos.
- Los patrones base son: **supervisor-worker**, **swarm/hand-off**, **jerárquico**, **debate/consenso** y **pipeline**. El supervisor-worker con **subagentes paralelos** es hoy el patrón dominante.
- Multi-agente aporta **especialización profunda, paralelismo, modularidad y resiliencia**, al costo de **mayor complejidad, latencia de coordinación y gasto en tokens**.
- Frameworks relevantes en 2026: **LangGraph** (control explícito), **CrewAI** (prompt-first), **AutoGen** (conversación), **OpenAI Agents SDK** (hand-offs), **Anthropic SDK** (Task tool).
- Anthropic demostró con su *Multi-Agent Research System* que subagentes paralelos pueden superar a un agente único por amplio margen cuando el trabajo es paralelizable.
- Nunca uses MAS sin **límites duros**: `max_steps`, `max_rounds`, timeout por iteración, presupuesto global y circuit breakers por agente.
- La **comunicación estructurada** (schemas, dataclasses, Pydantic) y el **"stay in your lane"** son la diferencia entre un sistema que funciona y un chat caótico entre LLMs.
