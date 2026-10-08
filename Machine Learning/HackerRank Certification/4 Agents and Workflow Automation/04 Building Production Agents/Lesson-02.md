# State management, checkpoints y resumability

## ¿Qué es?

Un **agente sin estado persistente** es un agente que olvida. En el momento en que el proceso cae, el pod se reinicia, el usuario cierra la pestaña o un deploy mata el worker a mitad de ejecución, **todo el progreso se pierde**: la conversación, las herramientas ya invocadas, los resultados intermedios. El próximo intento arranca desde cero.

Tres conceptos relacionados pero distintos resuelven este problema:

- **State management:** cómo se representa, muta y comparte el estado entre nodos de un workflow o entre pasos de un agente. En LangGraph se expresa como un `StateGraph` tipado.
- **Checkpointing:** persistir snapshots del estado en puntos bien elegidos, de modo que una ejecución interrumpida pueda retomarse exactamente donde quedó.
- **Resumability (durabilidad):** la capacidad del sistema de reanudar automáticamente ejecuciones tras fallos, cambios de proceso o pausas intencionales (ej. esperar aprobación humana). Herramientas como **Temporal** e **Inngest** elevan este concepto a primitiva de la plataforma.

```
Sin checkpoint:          crash → ❌ reiniciar desde cero
Con checkpoint:          crash → ✅ reanudar desde último snapshot
Con durabilidad total:   crash → ✅ reanudar + reintentar + mover de worker
```

## ¿Por qué importa?

Los agentes en producción enfrentan tres realidades que un notebook no muestra:

1. **Las ejecuciones son largas.** Un code review agent puede tardar 2-5 minutos. Un agente de investigación profunda, 10-30 minutos. La probabilidad de que *algo* interrumpa esa ventana (deploy, OOM, pod rescheduled, network blip) no es cero.
2. **Las interrupciones humanas son parte del flujo (human-in-the-loop).** Un agente que decide gastar $500 debe pausarse y pedir aprobación. Sin resumability, "pausarse" significa "morir y volver a empezar".
3. **El costo de reiniciar es real.** Reiniciar un agente que ya gastó 50k tokens significa pagar esos 50k tokens otra vez. En equipos grandes, re-ejecutar flujos se convierte en una línea del balance.

El checkpoint convierte al agente en un **programa durable**: una abstracción donde el código "se ejecuta" aunque el proceso que lo corre haya muerto hace minutos. Es la misma idea que llevó a arquitectos como Temporal e Inngest a construir plataformas enteras alrededor del concepto.

## ¿Cómo funciona?

### 1. State explícito y tipado

En LangGraph, el estado es un `TypedDict` que viaja por el grafo. Cada nodo recibe el estado actual y devuelve un *patch* (los campos que modifica):

```python
from typing import TypedDict, Annotated
from operator import add

class AgentState(TypedDict):
    messages: Annotated[list, add]   # el reducer "add" acumula
    findings: list[str]
    phase: str                       # security | coverage | done
    budget_used: int
```

- `Annotated[list, add]` indica que los `messages` **se concatenan** entre pasos (no se reemplazan).
- Los campos sin reducer se **sobrescriben** con el valor devuelto.

### 2. Checkpointing con SqliteSaver / PostgresSaver

LangGraph expone un `checkpointer` opcional al compilar el grafo. Si está presente, cada transición entre nodos se persiste automáticamente, indexada por un `thread_id`:

```
nodo_A ──(save state)──▶ nodo_B ──(save state)──▶ nodo_C
                              ❌ crash aquí
                                  │
                                  └─▶ reanudar: carga último snapshot, continúa en nodo_C
```

Backends disponibles:
- `MemorySaver` (dev; se pierde al reiniciar).
- `SqliteSaver` (local, un archivo).
- `PostgresSaver` (producción, multi-worker).
- Checkpointers custom (Redis, DynamoDB).

### 3. Resumability y human-in-the-loop con interrupts

LangGraph permite marcar nodos como **puntos de interrupción**: cuando la ejecución llega ahí, se detiene, el estado queda persistido, y el proceso puede terminar. Más tarde, otro proceso llama `invoke(None, config)` con el mismo `thread_id` y la ejecución retoma desde ese nodo.

Esto habilita el patrón **human-in-the-loop**: pausa antes de una acción irreversible, muestra la decisión al humano, espera aprobación, y continúa.

### 4. Durabilidad externa: Temporal e Inngest

Para flujos de días o semanas (onboarding, workflows legales, agentes que esperan eventos externos), un checkpointer embebido no basta. Herramientas como **Temporal** modelan cada paso como una *activity* idempotente, con reintentos, timeouts y versionado del código a nivel de plataforma. **Inngest** ofrece una experiencia similar orientada a serverless. La regla:

| Horizonte temporal | Herramienta típica |
|---|---|
| Segundos | In-memory loop |
| Minutos | LangGraph + SqliteSaver / PostgresSaver |
| Horas | LangGraph + Postgres + queue (Celery, RQ) |
| Días o más | Temporal, Inngest, AWS Step Functions |

### 5. Qué NO poner en el checkpoint

- **Transcripciones completas del LLM**, versión por versión: ocupan mucho, no son portables entre modelos.
- **Secrets** (API keys, tokens de OAuth): el checkpoint se persiste en una DB; trátalo como PII.
- **Objetos no serializables** (conexiones DB, clientes HTTP): guarda identificadores, reconstruye los objetos al reanudar.

El checkpoint ideal captura **lo mínimo necesario para reconstruir el progreso semántico**: fases completadas, hallazgos acumulados, mensajes clave resumidos. Si tu checkpoint pesa megabytes, estás guardando ruido.

## Ejemplo con código

Agente de code review con LangGraph, `SqliteSaver` para checkpointing y un **interrupt** para pedir aprobación humana antes de publicar.

```python
from typing import TypedDict, Annotated, Literal
from operator import add
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver

# ────────────────────────────────────────────────────────────
# 1. Definición del estado
# ────────────────────────────────────────────────────────────
class ReviewState(TypedDict):
    pr_number: int
    findings: Annotated[list[str], add]   # acumula entre fases
    phase: Literal["security", "coverage", "awaiting_approval", "published"]
    approved_by_human: bool
    budget_tokens: int

# ────────────────────────────────────────────────────────────
# 2. Nodos (cada uno simula una llamada LLM + tool calls)
# ────────────────────────────────────────────────────────────
def fase_seguridad(state: ReviewState) -> dict:
    pr = state["pr_number"]
    print(f"[security] escaneando PR #{pr}")
    nuevos = [f"PR#{pr}: posible SQL injection en auth.py"]
    return {
        "findings": nuevos,
        "phase": "coverage",
        "budget_tokens": state["budget_tokens"] - 1200,
    }

def fase_cobertura(state: ReviewState) -> dict:
    pr = state["pr_number"]
    print(f"[coverage] revisando tests PR #{pr}")
    nuevos = [f"PR#{pr}: cobertura 68% (< umbral 80%)"]
    return {
        "findings": nuevos,
        "phase": "awaiting_approval",
        "budget_tokens": state["budget_tokens"] - 800,
    }

def esperar_aprobacion(state: ReviewState) -> dict:
    # Punto de interrupción: no hace trabajo, solo marca el estado.
    # LangGraph se detendrá aquí gracias a `interrupt_before`.
    print("[gate] esperando aprobación humana...")
    return {}

def publicar(state: ReviewState) -> dict:
    if not state["approved_by_human"]:
        print("[publish] NO aprobado; cancelando")
        return {"phase": "published"}
    print(f"[publish] publicando {len(state['findings'])} hallazgos")
    return {"phase": "published"}

# ────────────────────────────────────────────────────────────
# 3. Grafo + checkpointer
# ────────────────────────────────────────────────────────────
builder = StateGraph(ReviewState)
builder.add_node("security", fase_seguridad)
builder.add_node("coverage", fase_cobertura)
builder.add_node("gate",     esperar_aprobacion)
builder.add_node("publish",  publicar)

builder.set_entry_point("security")
builder.add_edge("security", "coverage")
builder.add_edge("coverage", "gate")
builder.add_edge("gate",     "publish")
builder.add_edge("publish",  END)

checkpointer = SqliteSaver.from_conn_string("reviews.db")
app = builder.compile(
    checkpointer=checkpointer,
    interrupt_before=["gate"],   # ← pausa antes de 'gate'
)

# ────────────────────────────────────────────────────────────
# 4. Ejecución: corre hasta el interrupt
# ────────────────────────────────────────────────────────────
config = {"configurable": {"thread_id": "pr-1247"}}
initial = {
    "pr_number": 1247,
    "findings": [],
    "phase": "security",
    "approved_by_human": False,
    "budget_tokens": 50_000,
}
app.invoke(initial, config)
# → el grafo se detiene antes de 'gate'; el estado está en disco

# ... minutos u horas después, posiblemente en OTRO proceso ...

# ────────────────────────────────────────────────────────────
# 5. Reanudación: inyectar aprobación y continuar
# ────────────────────────────────────────────────────────────
app.update_state(config, {"approved_by_human": True})
app.invoke(None, config)   # ← None = continúa desde donde quedó
```

**Qué observar:**
- `thread_id="pr-1247"` es la clave única de esta ejecución. Si el proceso muere, otro proceso con el mismo `thread_id` continúa.
- `interrupt_before=["gate"]` convierte al nodo `gate` en un punto de pausa automático.
- `app.invoke(None, config)` reanuda la ejecución; LangGraph carga el checkpoint y continúa.
- El estado persistido es un *patch set*: no vuelves a ejecutar `security` ni `coverage`, aunque el proceso haya reiniciado.

### Pattern: orchestrator-workers con checkpoints

Cuando el orquestador descompone trabajo dinámicamente y cada worker es caro, el checkpoint evita re-ejecutar workers ya terminados tras un fallo:

```python
def orquestar(state):
    archivos = planificar_desde_pr(state["pr_number"])
    return {"pendientes": archivos, "procesados": []}

def worker(state):
    archivo = state["pendientes"][0]
    hallazgos = analizar(archivo)                 # LLM caro
    return {
        "pendientes": state["pendientes"][1:],
        "procesados": state["procesados"] + [archivo],
        "findings": hallazgos,
    }

def router(state):
    return "worker" if state["pendientes"] else "consolidar"

# ...construcción análoga; cada paso worker queda persistido.
```

Si el pod muere después de procesar 7 de 20 archivos, al reanudar el agente arranca en el archivo #8. Sin checkpoint, pagarías la revisión de los 7 primeros otra vez.

### Observabilidad del state

LangGraph expone `app.get_state(config)` y `app.get_state_history(config)` para inspeccionar el estado actual y pasado de un `thread_id`. Combinado con **LangSmith**, obtienes una línea de tiempo visual de cada nodo ejecutado, los patches aplicados y los tokens consumidos.

## Errores comunes

- **No persistir state (user cierra tab y pierde conversación).** El clásico: montas un chatbot con historia en memoria, el usuario refresca y toda la sesión desaparece. Solución: `thread_id` por sesión + checkpointer en Postgres o Redis. El state vive fuera del proceso.
- **Checkpointear demasiado o demasiado poco.** Guardar la transcripción cruda de cada token es un desperdicio y rompe la portabilidad al cambiar de modelo. No guardar nada deja al agente sin memoria. El punto medio: snapshots en *fronteras semánticas* (fases, hitos, acciones irreversibles).
- **Olvidar que los nodos deben ser idempotentes al reanudar.** Si tu nodo "enviar email" se ejecuta, se persiste el checkpoint, pero el proceso muere *antes* de que se registre el envío... al reanudar enviarás el email dos veces. Diseña nodos como *outbox pattern*: registra la intención primero, ejecuta después, usa IDs únicos para deduplicar.
- **Confundir `thread_id` con `user_id`.** Un usuario puede tener múltiples hilos simultáneos (varios PRs, varios tickets). Un `thread_id` es una **ejecución**; un `user_id` agrupa varias. Mezclarlos lleva a historias cruzadas y bugs raros.
- **Guardar secrets en el state.** El checkpoint es una DB. Si pones el token OAuth del usuario en el state, lo acabas de persistir en texto plano (a menos que cifres a nivel de columna). Guarda referencias (`"token_ref": "vault://user/123/github"`) y resuelve en runtime.
- **No versionar el schema del state.** El día que agregas un campo nuevo (`budget_tokens`), los checkpoints antiguos no lo tienen y el nodo falla con `KeyError`. Usa `.get()` con defaults o migra los checkpoints explícitamente.
- **Elegir Temporal cuando bastaba un checkpointer.** Temporal es poderoso pero añade complejidad operativa (cluster, workers, SDKs específicos). Para la mayoría de agentes de minutos, LangGraph + Postgres es suficiente. Reserva Temporal para flujos realmente durables (horas, días).

## Resumen

- Un agente sin **state persistente** olvida al primer crash: no sobrevive a deploys ni a interrupciones humanas.
- **State management**, **checkpointing** y **resumability** son tres capas: cómo representar el estado, cómo persistirlo y cómo reanudar automáticamente.
- **LangGraph** modela el estado como un `TypedDict` tipado que fluye por un `StateGraph`; los reducers (`Annotated[list, add]`) controlan cómo se combinan los patches.
- `SqliteSaver` para dev, `PostgresSaver` para producción multi-worker, custom para Redis/DynamoDB. **Temporal** e **Inngest** para flujos durables de días.
- `interrupt_before` convierte un nodo en punto de pausa: el estado se persiste, el proceso puede morir, y otro proceso retoma con `app.invoke(None, config)`.
- El patrón **human-in-the-loop** es un caso particular de resumability: pausa, muestra, espera input, continúa.
- Checkpointea en **fronteras semánticas** (fases, hitos), no cada token. Guarda lo mínimo para reconstruir el progreso.
- Diseña nodos **idempotentes** y nunca guardes secrets en el state.
- Combinar LangGraph con **LangSmith** da observabilidad visual del grafo, los nodos y los patches aplicados.
