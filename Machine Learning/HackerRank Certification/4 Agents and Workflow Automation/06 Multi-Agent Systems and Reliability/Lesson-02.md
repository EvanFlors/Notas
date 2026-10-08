# Comunicación y Coordinación entre Agentes

## ¿Qué es?

La **comunicación entre agentes** es el conjunto de **protocolos, formatos de mensaje y mecanismos de sincronización** que permiten que varios agentes LLM colaboren sin pisarse ni perder información. Es la "red + sistema operativo" de un sistema multi-agente.

Un sistema multi-agente sin protocolo de comunicación es como un equipo donde todos hablan al mismo tiempo en idiomas distintos: el trabajo "ocurre", pero el resultado es ruido. En producción, la coordinación suele consumir **más código que los propios prompts**.

Tres capas lógicas:

| Capa | Responsabilidad | Ejemplos |
|---|---|---|
| **Transporte** | Entregar mensajes entre agentes | Direct call, cola, pub/sub, websocket |
| **Formato** | Estructura del mensaje | JSON Schema, Pydantic, Protobuf, A2A, MCP |
| **Semántica** | Qué significa cada mensaje y quién puede enviarlo | Roles, permisos, políticas de conflicto |

### Protocolos emergentes (2025-2026)

| Protocolo | Promotor | Qué resuelve |
|---|---|---|
| **MCP** (Model Context Protocol) | Anthropic | Agente ↔ herramientas / recursos externos |
| **A2A** (Agent-to-Agent) | Google | Agente ↔ agente, cross-vendor |
| **ACP** (Agent Communication Protocol) | IBM/BeeAI | Mensajería estándar entre agentes |
| **OpenAI Agents SDK handoffs** | OpenAI | Hand-off nativo entre agentes del mismo stack |

> MCP se enfoca en el eje agente→tool; A2A y ACP se enfocan en agente→agente. En 2026 lo normal es combinarlos: MCP para que cada agente use tools, A2A/ACP para que agentes de distintos frameworks hablen entre sí.

## ¿Por qué importa?

Sin comunicación estructurada, los sistemas multi-agente fallan de formas sutiles y caras:

- **Hallazgos duplicados:** dos agentes reportan la misma vulnerabilidad con texto distinto; el humano la ve "dos veces" y pierde confianza.
- **Hallazgos perdidos:** el agente A asume que B lo leyó, pero B nunca recibió el mensaje.
- **Decisiones sobre contexto obsoleto:** el agente de performance usa una versión del diff que ya cambió.
- **Deadlocks:** A espera a B, B espera a A, el sistema se congela.
- **Costo descontrolado:** sin presupuesto por conversación, dos agentes pueden conversar por horas.

Importa porque la **calidad del sistema no depende solo de la calidad de cada agente**, sino de cómo intercambian información. En el reporte de Anthropic *Multi-Agent Research* (2025), más de la mitad de los bugs eliminados en producción fueron de **coordinación**, no de razonamiento del modelo.

### Comparación: comunicación ad-hoc vs. estructurada

| Dimensión | Ad-hoc (texto libre) | Estructurada (schema) |
|---|---|---|
| Parseo | Frágil, regex, fallos silenciosos | Validación automática |
| Evolución | Rompe sin aviso | Versionado explícito |
| Debug | "¿qué quiso decir el agente?" | Trazas limpias |
| Interop entre frameworks | Casi imposible | Natural con A2A/MCP |
| Costo de tokens | Alto (texto redundante) | Bajo (JSON compacto) |

## ¿Cómo funciona?

### 1. Protocolo de mensajes estructurado

Toda comunicación pasa por un `AgentMessage` validado:

```python
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum
from typing import Optional, Any
from uuid import uuid4

class MessageType(str, Enum):
    REQUEST   = "request"
    RESPONSE  = "response"
    BROADCAST = "broadcast"
    FINDING   = "finding"
    HANDOFF   = "handoff"
    ERROR     = "error"

class AgentMessage(BaseModel):
    message_id: str = Field(default_factory=lambda: str(uuid4()))
    conversation_id: str
    message_type: MessageType
    sender: str
    recipient: Optional[str] = None   # None = broadcast
    content: dict[str, Any]
    schema_version: str = "1.0"
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    priority: int = 5                 # 0 = max, 10 = min
    in_reply_to: Optional[str] = None # message_id al que responde
```

Clave: **versionar el schema** (`schema_version`) y validar en el receptor. Un cambio incompatible debe aumentar la versión y los agentes viejos deben rechazar o degradarse elegantemente.

### 2. Message bus (pub/sub)

Desacopla productores de consumidores. Agregar un agente nuevo no requiere tocar los existentes:

```python
import asyncio
from collections import defaultdict

class MessageBus:
    def __init__(self):
        self._subscribers: dict[str, list] = defaultdict(list)
        self._queue: asyncio.Queue = asyncio.Queue()

    def subscribe(self, topic: str, handler):
        self._subscribers[topic].append(handler)

    async def publish(self, topic: str, msg: AgentMessage):
        await self._queue.put((topic, msg))

    async def run(self):
        while True:
            topic, msg = await self._queue.get()
            for handler in self._subscribers[topic]:
                asyncio.create_task(handler(msg))   # no bloqueante
```

### 3. Shared state (blackboard) con locking

Es el patrón nativo de **LangGraph** (todos los nodos leen/escriben a un `State`):

```python
import asyncio
from dataclasses import dataclass, field

@dataclass
class SharedContext:
    pr_number: int
    repo: str
    files: list[dict]
    findings: list[dict] = field(default_factory=list)
    decisions: dict[str, Any] = field(default_factory=dict)
    version: int = 0                   # para detectar lecturas stale

class ContextManager:
    def __init__(self):
        self.ctx: dict[str, SharedContext] = {}
        self.locks: dict[str, asyncio.Lock] = {}

    def _lock(self, rid: str) -> asyncio.Lock:
        return self.locks.setdefault(rid, asyncio.Lock())

    async def update(self, rid: str, mutator):
        async with self._lock(rid):      # mutual exclusion
            ctx = self.ctx[rid]
            mutator(ctx)
            ctx.version += 1
            return ctx

    async def read(self, rid: str, expected_version: Optional[int] = None):
        async with self._lock(rid):
            ctx = self.ctx[rid]
            if expected_version is not None and ctx.version != expected_version:
                raise StaleReadError(expected_version, ctx.version)
            return ctx
```

### 4. Enrutamiento basado en capacidades

El router elige el agente **más idóneo + menos cargado**:

```python
from pydantic import BaseModel

class AgentCapabilities(BaseModel):
    agent_id: str
    languages: list[str]       # ["python", "typescript"]
    skills: list[str]          # ["security", "performance"]
    max_concurrent: int = 3
    current_load: int = 0
    avg_latency_ms: int = 2000
    cost_per_call_usd: float = 0.01

class CapabilityRouter:
    def __init__(self):
        self.agents: dict[str, AgentCapabilities] = {}

    def route(self, task: dict) -> Optional[str]:
        want_lang  = task.get("language")
        want_skill = task.get("skill")
        candidates = []
        for a in self.agents.values():
            if a.current_load >= a.max_concurrent: continue
            if want_lang and want_lang not in a.languages: continue
            score  = 10 if want_skill in a.skills else 0
            score -= a.current_load               # balanceo
            score -= a.avg_latency_ms / 1000      # preferir rápido
            candidates.append((score, a.agent_id))
        if not candidates: return None
        candidates.sort(reverse=True)
        return candidates[0][1]
```

### 5. Priority queue

```python
import heapq

class PriorityScheduler:
    def __init__(self):
        self.heap = []
        self.seq = 0

    def _priority(self, task: dict) -> int:
        if task.get("type") == "security":      return 0
        if task.get("severity") == "critical":  return 1
        if task.get("lines_changed", 0) > 500:  return 2
        if task.get("docs_only"):               return 8
        return 5

    def push(self, task: dict):
        self.seq += 1
        heapq.heappush(self.heap, (self._priority(task), self.seq, task))

    def pop(self):
        return heapq.heappop(self.heap)[2] if self.heap else None
```

### 6. Barrier (fan-in sincronizado)

Después de un fan-out paralelo necesitas esperar a todos antes de sintetizar:

```python
class Barrier:
    def __init__(self, n: int):
        self.n = n
        self.waiting = 0
        self.cond = asyncio.Condition()

    async def wait(self):
        async with self.cond:
            self.waiting += 1
            if self.waiting == self.n:
                self.waiting = 0
                self.cond.notify_all()
            else:
                await self.cond.wait()
```

### 7. Consenso con votación

```python
class ConsensusManager:
    def __init__(self, agents: list[str], threshold: float = 0.6):
        self.agents = agents
        self.threshold = threshold

    async def vote(self, topic: str, ctx: dict) -> dict:
        votes = await asyncio.gather(*[self._ask(a, topic, ctx) for a in self.agents])
        tally: dict[str, int] = {}
        for v in votes:
            tally[v["position"]] = tally.get(v["position"], 0) + 1
        for pos, count in tally.items():
            if count / len(votes) >= self.threshold:
                return {"consensus": True, "position": pos, "tally": tally}
        return {"consensus": False, "needs_arbitration": True, "tally": tally}
```

Alternativas al voto plano: **voto ponderado por confianza del agente**, **debate iterativo**, o **árbitro con un modelo más capaz** (p.ej. Opus) como juez final.

### 8. Definición explícita de roles

```python
@dataclass
class AgentRole:
    name: str
    responsibilities: list[str]
    out_of_scope: list[str]      # qué NO debe hacer (clave)
    defers_to: list[str]

    def system_prompt(self) -> str:
        return f"""Eres {self.name}.
Haz:
- {chr(10) + '- '.join(self.responsibilities)}

NO hagas:
- {chr(10) + '- '.join(self.out_of_scope)}

Para casos fuera de tu dominio delega a: {', '.join(self.defers_to)}.
Mantente en tu carril (stay in your lane)."""

security_role = AgentRole(
    name="Security Reviewer",
    responsibilities=[
        "Detectar inyecciones (SQL, XSS, command)",
        "Revisar autenticación y autorización",
        "Flaguear secretos hardcoded",
    ],
    out_of_scope=["Comentar estilo de código", "Comentar performance", "Sugerir refactors"],
    defers_to=["Performance Reviewer", "Style Reviewer"],
)
```

### 9. Work stealing

Cuando un agente queda ocioso, roba trabajo de la cola de los ocupados. Útil cuando las sub-tareas son heterogéneas en duración.

## Ejemplo con código

Pipeline completo: **bus + schema + routing + barrier + consenso**.

```python
import asyncio
from typing import Any

bus     = MessageBus()
router  = CapabilityRouter()
ctxmgr  = ContextManager()

# --- Registrar agentes ---
router.agents["sec-1"]  = AgentCapabilities(agent_id="sec-1",  languages=["python"], skills=["security"])
router.agents["sec-2"]  = AgentCapabilities(agent_id="sec-2",  languages=["python"], skills=["security"])
router.agents["perf-1"] = AgentCapabilities(agent_id="perf-1", languages=["python"], skills=["performance"])

# --- Handler genérico de un worker ---
async def worker_handler(agent_id: str, bus: MessageBus):
    async def handle(msg: AgentMessage):
        router.agents[agent_id].current_load += 1
        try:
            # ... llamada al LLM con timeout ...
            finding = {"agent": agent_id, "text": "placeholder"}
            await bus.publish("findings", AgentMessage(
                conversation_id=msg.conversation_id,
                message_type=MessageType.FINDING,
                sender=agent_id,
                content=finding,
                in_reply_to=msg.message_id,
            ))
        finally:
            router.agents[agent_id].current_load -= 1
    return handle

# --- Colector con barrier ---
collected: list[AgentMessage] = []
barrier = Barrier(n=3)

async def collector(msg: AgentMessage):
    collected.append(msg)
    await barrier.wait()

# --- Suscripciones ---
for aid in ["sec-1", "sec-2", "perf-1"]:
    bus.subscribe(f"task.{aid}", await worker_handler(aid, bus))
bus.subscribe("findings", collector)

# --- Lanzar bus y publicar tareas ---
asyncio.create_task(bus.run())

tasks = [
    {"skill": "security",    "language": "python", "payload": "<diff 1>"},
    {"skill": "security",    "language": "python", "payload": "<diff 2>"},
    {"skill": "performance", "language": "python", "payload": "<diff 3>"},
]
for t in tasks:
    aid = router.route(t)
    await bus.publish(f"task.{aid}", AgentMessage(
        conversation_id="review-42",
        message_type=MessageType.REQUEST,
        sender="supervisor",
        recipient=aid,
        content=t,
    ))

# ... después de que barrier libera, se puede sintetizar ...
```

### Ejemplo mínimo con MCP (Model Context Protocol)

Un agente expone recursos vía MCP y otro los consume:

```python
# server MCP (expone una herramienta "get_diff")
from mcp.server import Server
srv = Server("pr-tools")

@srv.tool()
async def get_diff(pr_number: int) -> str:
    return fetch_github_diff(pr_number)

# Cliente MCP dentro de un agente
from mcp.client import ClientSession
async with ClientSession("stdio://pr-tools") as session:
    tools = await session.list_tools()
    diff  = await session.call_tool("get_diff", {"pr_number": 42})
```

## Errores comunes

- **Mismatch de schema silencioso:** el agente A manda `{severity: "HIGH"}`, el agente B espera `{severity: "high"}`. Valida con Pydantic y falla ruidoso.
- **Deadlocks por espera circular:** A espera finding de B, B espera clarificación de A. Siempre define **timeouts** por mensaje y evita dependencias circulares.
- **Lecturas stale del estado compartido:** sin versionado, el agente toma decisiones con datos de hace 10 segundos. Usa `version` o `updated_at` y rechaza lecturas desactualizadas en operaciones críticas.
- **Overcommunication:** cada agente notificando cada paso satura el bus y multiplica tokens de los que resumen. Define qué merece broadcast y qué es "silencioso" (log, no mensaje).
- **Race conditions en writes:** dos agentes agregan al mismo `findings[]` sin lock → mensajes perdidos. Usa `asyncio.Lock`, transacciones o estructuras CRDT.
- **Prompts sin "stay in your lane":** la fuente #1 de hallazgos duplicados. Incluye explícitamente la lista `out_of_scope`.
- **Confiar en el formato que "siempre devuelve" el LLM:** incluso con JSON mode, parsea defensivamente y reintenta con feedback estructurado si falla la validación.
- **Message bus sin dead-letter queue:** mensajes que fallan N veces se pierden sin rastro. Siempre encamínalos a una DLQ para inspección manual.
- **Priority inversion:** una tarea crítica queda atrás de muchas de baja prioridad porque el worker tomó una larga primero. Usa colas separadas por prioridad o preemption.

## Resumen

- La **comunicación estructurada** es lo que separa un sistema multi-agente que funciona de un chat caótico entre LLMs.
- Los tres pilares son: **protocolo de mensajes** (schema versionado), **transporte** (bus, call directo, hand-off) y **estado compartido** (blackboard con locking).
- Estándares emergentes: **MCP** (agente↔tools), **A2A** y **ACP** (agente↔agente cross-vendor). Combínalos.
- Para distribuir trabajo: **capability-based routing** + **priority queue** + opcionalmente **work stealing**. El balanceo por carga evita hotspots.
- Para sincronizar fases: **barriers** (fan-in), **locks** (mutua exclusión), **voting / consensus** (resolución de conflictos).
- Define **roles explícitos** con `responsibilities` y `out_of_scope`; "stay in your lane" elimina la mayoría de duplicados.
- Pon **timeouts, DLQs y validación de schema** desde el día uno: la mayoría de los bugs en MAS son de coordinación, no de razonamiento.
- Observabilidad por agente y por mensaje (LangSmith, Langfuse, Arize Phoenix) hace la diferencia entre un sistema debuggeable y uno que es magia negra.
