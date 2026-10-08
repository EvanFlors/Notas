# Workflows vs Agents: eligiendo el nivel correcto de autonomía

## ¿Qué es?

En diciembre de 2024, Anthropic publicó *Building Effective Agents*, un ensayo que fijó el vocabulario de la industria. En él se distinguen dos categorías de sistemas construidos con LLMs:

- **Workflows (flujos):** sistemas donde los LLMs y las herramientas se orquestan mediante **rutas de código predefinidas**. El grafo de ejecución es decidido por el programador.
- **Agents (agentes):** sistemas donde el LLM **dirige dinámicamente** sus propios procesos y el uso de herramientas, decidiendo paso a paso qué hacer para cumplir el objetivo.

Ambos pertenecen a la familia de **"agentic systems"** (sistemas agénticos), pero representan puntos distintos en un espectro:

```
Más control                                            Más flexibilidad
Más predecible                                         Más adaptable
Menor costo                                            Mayor costo
     │                                                        │
     ▼                                                        ▼
┌─────────────┐    ┌───────────────┐    ┌─────────────────────┐
│  LLM call   │ →  │   Workflow    │ →  │       Agent         │
│ (una sola)  │    │ (código fijo) │    │ (loop autónomo)     │
└─────────────┘    └───────────────┘    └─────────────────────┘
```

La regla práctica de Anthropic: **"usa el patrón más simple que funcione"**. Un workflow determinístico es casi siempre más barato, más depurable y más fiable que un agente autónomo. Solo cuando la tarea requiere ramificación impredecible debes recurrir a un agente.

### Workflow vs Agent en una tabla

| Dimensión | Workflow | Agent |
|---|---|---|
| Control de flujo | Programador (código) | LLM (decide en runtime) |
| Pasos | Conocidos de antemano | Dinámicos |
| Determinismo | Alto | Bajo |
| Costo por ejecución | Predecible | Variable (puede explotar) |
| Debugging | Fácil (trazas lineales) | Difícil (razonamiento no determinístico) |
| Casos ideales | ETL con IA, clasificación + routing, resumen multi-paso | Soporte técnico libre, coding agents, investigación abierta |

## ¿Por qué importa?

Equivocarse de nivel de autonomía es el error #1 en sistemas de IA en producción. Lo vemos en dos direcciones:

1. **Construir un agente cuando bastaba un workflow.** El equipo compra el hype, monta un loop con un LLM que llama 15 herramientas, el costo se dispara, el debugging es imposible y el 90% de los casos reales podían resolverse con `if cliente.tipo == "VIP": ruta_a()`.
2. **Construir un workflow cuando se necesitaba un agente.** El equipo intenta enumerar todas las ramas posibles de una conversación de soporte. Al cuarto `if/elif/else` anidado, el código se vuelve inmantenible y el usuario termina atrapado en un árbol que nunca lo escucha.

El marco de Anthropic da un lenguaje común para tomar esa decisión *antes* de escribir código. Herramientas como **LangGraph**, **LlamaIndex Workflows**, **Temporal** e **Inngest** han adoptado este vocabulario, lo cual hace que la decisión arquitectónica sea portable entre stacks.

### El espectro completo

Entre "una sola llamada al LLM" y "agente totalmente autónomo" existen **cinco patrones de workflow** canónicos (Anthropic, Dec 2024) y luego los agentes:

| Patrón | Qué es | Cuándo usarlo |
|---|---|---|
| **Prompt chaining** | Divide la tarea en pasos secuenciales; cada LLM procesa el output del anterior | Tareas descomponibles con pasos claros (traducir → revisar → formatear) |
| **Routing** | Un LLM clasifica el input y lo envía a un handler especializado | Entrada heterogénea con categorías distintas (soporte: facturación vs técnico vs reembolsos) |
| **Parallelization** | Múltiples LLMs trabajan en paralelo; luego se agregan resultados | Sectioning (dividir tarea) o voting (consenso para seguridad) |
| **Orchestrator-workers** | Un LLM central descompone dinámicamente y delega a workers | Tareas donde los subtasks no se conocen de antemano (ej. editar varios archivos de un repo) |
| **Evaluator-optimizer** | Un LLM genera, otro evalúa y da feedback; iteran | Hay criterios de calidad claros y la iteración añade valor (traducción literaria, búsqueda compleja) |
| **Agent** | Loop autónomo con herramientas, memoria y planificación | Problema abierto, pasos impredecibles, feedback del entorno disponible |

## ¿Cómo funciona?

### Workflow determinístico (prompt chaining)

El código define el grafo. El LLM solo rellena nodos. No hay decisión sobre "qué paso sigue":

```
Input → LLM₁ (extraer) → validar → LLM₂ (clasificar) → LLM₃ (resumir) → Output
                              │
                              └─ gate: si falla, STOP
```

### Routing

```
             ┌─ handler_facturación
Input → LLM router ──┼─ handler_técnico
             └─ handler_reembolsos
```

El LLM clasifica una vez; el código enruta. Permite usar un modelo barato para clasificar y modelos caros solo para handlers complejos.

### Parallelization

```
            ┌─ LLM (revisa seguridad)
Input ──────┼─ LLM (revisa performance)   ──→ agregador → Output
            └─ LLM (revisa estilo)
```

Dos variantes:
- **Sectioning:** cada LLM atiende una parte distinta.
- **Voting:** varios LLMs atienden lo mismo; se toma la mayoría (útil para validaciones de seguridad donde `N-of-M` reduce falsos negativos).

### Orchestrator-workers

A diferencia de parallelization, aquí **el orquestador decide en runtime** cuántos workers lanzar y qué pedirles. El patrón canónico para agentes de código tipo Claude Code o Cursor.

### Evaluator-optimizer

Dos LLMs en loop: uno propone, otro critica. Converge cuando el evaluador aprueba. Útil cuando los criterios de calidad son explícitos y el modelo puede autoevaluarse mejor que generar bien al primer intento.

### Agent (loop autónomo)

```
┌─────────────────────────────────────────┐
│  observar entorno                       │
│         ↓                               │
│  pensar (LLM decide siguiente acción)   │
│         ↓                               │
│  actuar (tool call)                     │
│         ↓                               │
│  recibir feedback ───┐                  │
│         ↓            │                  │
│  ¿objetivo cumplido? │                  │
│    no ───────────────┘                  │
│    sí → return                          │
└─────────────────────────────────────────┘
```

El agente no sabe cuántos pasos tomará. Necesita: herramientas con descripciones claras, criterios de parada (completion, max_iterations, budget), observabilidad del razonamiento, y un entorno que le dé feedback real (no alucinado).

### La regla de decisión

**¿Puedes dibujar el grafo completo antes de ejecutar?**

- **Sí** → workflow (elige el patrón más simple de los cinco).
- **No, pero puedes acotar las opciones** → orchestrator-workers.
- **No, el problema requiere exploración abierta** → agent.

## Ejemplo con código

Comparación directa de un router (workflow) contra un agent para el mismo problema: triage de tickets de soporte.

```python
# ============================================================
# OPCIÓN A — Workflow: routing determinístico
# ============================================================
from anthropic import Anthropic

client = Anthropic()
MODEL_FAST = "claude-haiku-4-5"
MODEL_SMART = "claude-sonnet-4-5"

def clasificar(ticket: str) -> str:
    """LLM barato clasifica; el código enruta."""
    resp = client.messages.create(
        model=MODEL_FAST,
        max_tokens=10,
        messages=[{
            "role": "user",
            "content": (
                f"Clasifica este ticket en UNA palabra: "
                f"'facturacion', 'tecnico' o 'reembolso'.\n\n{ticket}"
            ),
        }],
    )
    return resp.content[0].text.strip().lower()

def handler_facturacion(ticket): return f"[FACTURACIÓN] {ticket[:40]}..."
def handler_tecnico(ticket):     return f"[TÉCNICO]     {ticket[:40]}..."
def handler_reembolso(ticket):   return f"[REEMBOLSO]   {ticket[:40]}..."

HANDLERS = {
    "facturacion": handler_facturacion,
    "tecnico":     handler_tecnico,
    "reembolso":   handler_reembolso,
}

def workflow_triage(ticket: str) -> str:
    categoria = clasificar(ticket)
    handler = HANDLERS.get(categoria, handler_tecnico)  # fallback
    return handler(ticket)


# ============================================================
# OPCIÓN B — Agent: loop autónomo con herramientas
# ============================================================
TOOLS = [
    {
        "name": "buscar_factura",
        "description": "Busca una factura por número.",
        "input_schema": {
            "type": "object",
            "properties": {"numero": {"type": "string"}},
            "required": ["numero"],
        },
    },
    {
        "name": "crear_ticket_jira",
        "description": "Crea un ticket técnico en Jira.",
        "input_schema": {
            "type": "object",
            "properties": {
                "titulo": {"type": "string"},
                "severidad": {"type": "string", "enum": ["low", "med", "high"]},
            },
            "required": ["titulo", "severidad"],
        },
    },
]

def ejecutar_tool(nombre: str, args: dict) -> str:
    if nombre == "buscar_factura":
        return f"Factura {args['numero']}: $450 MXN, estado=pagada"
    if nombre == "crear_ticket_jira":
        return f"Ticket SUP-{hash(args['titulo']) % 10000} creado"
    return "error: tool desconocida"

def agent_triage(ticket: str, max_iter: int = 10) -> str:
    messages = [{"role": "user", "content": ticket}]
    for i in range(max_iter):
        resp = client.messages.create(
            model=MODEL_SMART,
            max_tokens=1024,
            tools=TOOLS,
            messages=messages,
        )
        # Criterio de parada
        if resp.stop_reason == "end_turn":
            return resp.content[-1].text

        # El modelo pide usar una tool
        messages.append({"role": "assistant", "content": resp.content})
        tool_results = []
        for block in resp.content:
            if block.type == "tool_use":
                output = ejecutar_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": output,
                })
        messages.append({"role": "user", "content": tool_results})
    return "AGENT TIMEOUT"


# ============================================================
# Comparación
# ============================================================
ticket = "Mi factura F-9981 muestra un cargo duplicado"
print("Workflow:", workflow_triage(ticket))
print("Agent:   ", agent_triage(ticket))
```

**Qué observar:** el workflow termina en **una** llamada LLM barata + un handler determinístico. El agent puede dar una mejor respuesta cuando el ticket es ambiguo (porque usa herramientas y razona), pero cuesta de 5x a 50x más y es imposible garantizar el camino exacto que tomará.

### Orchestrator-workers con LangGraph

Para tareas donde los subtasks se descubren en runtime (ej. "edita todos los archivos del repo que usan la API antigua"), **LangGraph** ofrece la primitiva correcta: un grafo con un nodo orquestador que puede despachar workers dinámicamente.

```python
from typing import TypedDict, Annotated
from langgraph.graph import StateGraph, END
import operator

class ReviewState(TypedDict):
    archivos: list[str]
    hallazgos: Annotated[list[str], operator.add]   # workers acumulan

def planificar(state: ReviewState):
    """Orquestador: decide qué archivos revisar."""
    return {"archivos": ["auth.py", "db.py", "api.py"]}

def revisar_archivo(state: ReviewState):
    """Worker: revisa un archivo (uno por invocación)."""
    archivo = state["archivos"].pop(0)
    # ...llamada al LLM...
    return {"hallazgos": [f"{archivo}: ok"]}

def consolidar(state: ReviewState):
    return {"hallazgos": [f"RESUMEN: {len(state['hallazgos'])} archivos"]}

def hay_mas(state: ReviewState):
    return "revisar_archivo" if state["archivos"] else "consolidar"

g = StateGraph(ReviewState)
g.add_node("planificar", planificar)
g.add_node("revisar_archivo", revisar_archivo)
g.add_node("consolidar", consolidar)
g.set_entry_point("planificar")
g.add_edge("planificar", "revisar_archivo")
g.add_conditional_edges("revisar_archivo", hay_mas,
                        {"revisar_archivo": "revisar_archivo",
                         "consolidar": "consolidar"})
g.add_edge("consolidar", END)

app = g.compile()
resultado = app.invoke({"archivos": [], "hallazgos": []})
```

Este es el patrón que usan en producción herramientas como Claude Code, Devin y Cursor.

## Errores comunes

- **Construir un agente cuando bastaba un workflow.** El síntoma clásico: tu "agente" siempre toma la misma secuencia de pasos. Si siempre hace A → B → C, no es un agente: es un workflow mal implementado que paga el impuesto de autonomía (costo, latencia, imprevisibilidad) sin recibir el beneficio.
- **No definir criterios de parada en el loop.** Un agente sin `max_iterations`, sin budget de tokens, sin timeout y sin detección de loops puede quedarse corriendo horas, acumular cuentas de 4 dígitos y dejar al usuario esperando. Siempre define **al menos tres** criterios de parada: finalización natural (`end_turn`), límite duro (`max_iterations`) y presupuesto de tokens.
- **Mezclar workflow y agent sin separar responsabilidades.** Es tentador meter un loop autónomo dentro de un nodo de workflow. El resultado: no sabes si una falla es del grafo externo o del agente interno. Separa: workflow para la columna vertebral determinística, agents para subtareas acotadas donde la autonomía realmente ayuda.
- **Elegir framework antes de elegir patrón.** "Usemos CrewAI / AutoGen / LangGraph" es la pregunta equivocada. Primero decide: ¿workflow o agent? ¿Qué patrón? *Después* elige el framework que mejor expresa ese patrón. LangGraph es fuerte en grafos explícitos con state; CrewAI en roles multi-agente; AutoGen en conversaciones multi-agente; Temporal e Inngest en durabilidad y resumability.
- **Herramientas mal diseñadas.** Un agente solo es tan bueno como sus tools. Nombres ambiguos, descripciones vagas, schemas sin validación y mensajes de error inútiles destruyen el razonamiento del LLM. Trata las descripciones de tool como prompts críticos: itera sobre ellas con la misma seriedad que sobre el system prompt.

## Resumen

- **Workflows** = control del programador (grafos fijos); **Agents** = control del LLM (decisiones en runtime). Ambos son "sistemas agénticos".
- La regla de oro de Anthropic (*Building Effective Agents*, Dic 2024): **usa el patrón más simple que funcione**.
- Los **cinco patrones de workflow**: prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer. Un agente es la sexta opción, no la primera.
- Decisión rápida: *¿puedo dibujar el grafo antes de ejecutar?* Sí → workflow. No → agent.
- **LangGraph** es la referencia actual para expresar workflows + agents con estado explícito; **CrewAI** y **AutoGen** se enfocan en multi-agent; **Temporal** e **Inngest** aportan durabilidad.
- Los **tres criterios de parada** mínimos para un agente: fin natural, max_iterations, budget de tokens.
- Construir un agente cuando bastaba un workflow es el error #1: paga el costo de autonomía sin recibir el beneficio.
- Diseña las **tool descriptions** con tanto cuidado como el system prompt: el agente razona sobre lo que lee ahí.
