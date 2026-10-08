# Diseño de workflows de aprobación

## ¿Qué es?

Un **workflow de aprobación** es la mecánica concreta que convierte "esta acción necesita humano" en una experiencia operativa: cómo se encola la petición, quién la ve, cuánto tiempo tiene para responder, qué pasa si no responde, cómo se registran sus modificaciones y qué efecto final tiene el "approve" o "reject".

> **Checkpoint:** cualquier punto del plan del agente donde la ejecución se **pausa** hasta recibir una señal humana. El estado del agente se persiste para poder **resumir** sin perder contexto.

Un workflow bien diseñado se siente natural: el humano recibe una notificación con todo lo que necesita, decide en segundos, y el agente continúa. Un workflow mal diseñado se siente burocrático: notificaciones a destiempo, contexto insuficiente, decisiones que se pierden en una cola sin dueño.

### Elementos de todo workflow

| Elemento | Pregunta que responde |
|---|---|
| **Trigger** | ¿Qué condición dispara la aprobación? (tipo de acción, umbral de confianza, riesgo calculado) |
| **Routing** | ¿Quién puede aprobar y a quién le llega? (pool de aprobadores, load balancing, expertise) |
| **Presentation** | ¿Qué ve el humano? (resumen, findings, diff, confianza) |
| **Response** | ¿Qué puede responder? (approve / reject / modify / escalate) |
| **Timeout** | ¿Qué pasa si no responde? (escalate / auto-approve / auto-reject) |
| **Post-action** | ¿Qué ejecuta el agente al recibir la respuesta? ¿Qué se registra? |

## ¿Por qué importa?

Sin workflow, HITL es una buena intención. Con un workflow mal diseñado, se vuelve el cuello de botella de todo el sistema: el agente puede generar 500 reviews por hora, pero si cada uno requiere aprobación de un solo tech lead, el throughput real es 10 por hora. Peor: la cola crece sin control, los tiempos de respuesta se degradan y el humano empieza a rubber-stamp.

Un workflow correcto permite:

- **Throughput alto** sin sacrificar supervisión: el agente trabaja en paralelo mientras los humanos revisan por batches.
- **Resiliencia** ante vacaciones, incidentes y rotación: múltiples aprobadores elegibles con fallback automático.
- **Trazabilidad regulatoria**: quién aprobó qué, cuándo, con qué contexto. Obligatorio en finanzas, salud y gobierno.
- **Aprendizaje**: las modificaciones humanas son la fuente de verdad para mejorar el agente.

### Interrupt-and-resume

El patrón técnico subyacente es **interrupt-and-resume**: el agente ejecuta su grafo de decisiones hasta un nodo marcado como "requiere humano", persiste su estado completo (checkpoint), notifica, y queda esperando. Cuando el humano responde, se restaura el estado y la ejecución continúa como si no hubiera pausa. Frameworks como **LangGraph** (`interrupt()`), **Temporal** (durable workflows) y **OpenAI Assistants** (`required_action`) implementan esta primitiva.

## ¿Cómo funciona?

### Ciclo de vida de una PendingAction

```
submit → pending → [approved | rejected | modified | expired | escalated] → executed
                      ↑           ↑           ↑           ↑            ↑
                      └───────────┴───────────┴───────────┴────────────┘
                              Transiciones registradas (audit log)
```

### Políticas de timeout

| Política | Cuándo usarla | Riesgo |
|---|---|---|
| `escalate` | Cualquier acción no trivial | Default seguro |
| `auto_approve` | Acciones bajas de riesgo con default razonable | Si se mal-calibra, pierdes el valor del HITL |
| `auto_reject` | Acciones donde "no hacer nada" es seguro | Puede frustrar al usuario final |
| `hold` | Decisiones críticas que deben esperar | Puede bloquear flujos dependientes |

### Load balancing entre aprobadores

Distribuir solicitudes al aprobador con **menor carga actual** evita saturar a una sola persona. Variantes:

- **Round robin** por simplicidad.
- **Least loaded** por fairness (ordena por items pendientes).
- **Expertise match** por calidad (routea a quien conoce el área).
- **Follow the sun** para equipos globales (horario laboral del aprobador).

### Capturar modificaciones como señal

Cuando el humano aprueba *con edits*, esos edits son **oro para fine-tuning**. Un patrón recurrente ("el humano siempre quita el emoji del comentario") se puede traducir a una guideline de prompt o a un ejemplo negativo en el dataset.

## Ejemplo con código

### Estructura base y motor de aprobación

```python
import uuid
import asyncio
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum

class ApprovalStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    MODIFIED = "modified"
    EXPIRED = "expired"
    ESCALATED = "escalated"

@dataclass
class PendingAction:
    action_id: str
    action_type: str
    payload: dict
    created_at: datetime
    expires_at: datetime
    required_approvers: list[str] = field(default_factory=list)
    approvals_received: list[str] = field(default_factory=list)
    status: ApprovalStatus = ApprovalStatus.PENDING
    priority: int = 0
    modifications: list[dict] = field(default_factory=list)

@dataclass
class Workflow:
    action_type: str
    timeout_hours: int
    min_approvals: int
    on_timeout: str  # "escalate" | "auto_approve" | "auto_reject"
    eligible_approvers: list[str]

class ApprovalEngine:
    def __init__(self, storage, notifier):
        self.storage = storage
        self.notifier = notifier
        self.workflows: dict[str, Workflow] = {}

    def register(self, workflow: Workflow):
        self.workflows[workflow.action_type] = workflow

    async def submit(self, action_type: str, payload: dict, context: dict) -> PendingAction:
        wf = self.workflows[action_type]
        approvers = await self._pick_approvers(wf, context)

        pending = PendingAction(
            action_id=str(uuid.uuid4()),
            action_type=action_type,
            payload=payload,
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(hours=wf.timeout_hours),
            required_approvers=approvers,
            priority=context.get("priority", 0),
        )
        await self.storage.save(pending)
        for a in approvers:
            await self.notifier.request_approval(pending, a)
        return pending

    async def respond(self, action_id: str, approver: str,
                       decision: str, edits: dict | None = None,
                       reason: str | None = None) -> PendingAction:
        pending = await self.storage.get(action_id)
        if pending.status != ApprovalStatus.PENDING:
            raise ValueError(f"Acción {action_id} ya no está pendiente ({pending.status})")

        if decision == "approved":
            pending.approvals_received.append(approver)
            if edits:
                pending.payload = self._apply_edits(pending.payload, edits)
                pending.modifications.append({"approver": approver, "edits": edits})
            wf = self.workflows[pending.action_type]
            if len(pending.approvals_received) >= wf.min_approvals:
                pending.status = ApprovalStatus.MODIFIED if edits else ApprovalStatus.APPROVED
        elif decision == "rejected":
            pending.status = ApprovalStatus.REJECTED
            pending.payload["rejection_reason"] = reason

        await self.storage.save(pending)
        return pending
```

### LangGraph: interrupt para pedir aprobación humana

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import interrupt, Command
from typing import TypedDict

class ReviewState(TypedDict):
    pr_number: int
    draft_review: str
    confidence: float
    human_decision: str | None
    final_review: str | None

def generate_review(state: ReviewState) -> ReviewState:
    # Llamar al LLM para producir el borrador
    draft = f"Review borrador para PR #{state['pr_number']}"
    return {"draft_review": draft, "confidence": 0.72}

def needs_approval(state: ReviewState) -> str:
    return "wait_human" if state["confidence"] < 0.85 else "auto_post"

def wait_human(state: ReviewState) -> ReviewState:
    # El grafo se pausa aquí; el checkpointer persiste el estado
    decision = interrupt({
        "question": "¿Publicar este review?",
        "draft": state["draft_review"],
        "confidence": state["confidence"],
    })
    return {"human_decision": decision["action"],
            "final_review": decision.get("edited_text") or state["draft_review"]}

def auto_post(state: ReviewState) -> ReviewState:
    return {"final_review": state["draft_review"], "human_decision": "auto"}

def publish(state: ReviewState) -> ReviewState:
    if state["human_decision"] in ("approve", "auto"):
        print(f"Publicando: {state['final_review']}")
    else:
        print("Rechazado por humano; nada se publica.")
    return state

graph = StateGraph(ReviewState)
graph.add_node("generate", generate_review)
graph.add_node("wait_human", wait_human)
graph.add_node("auto_post", auto_post)
graph.add_node("publish", publish)
graph.set_entry_point("generate")
graph.add_conditional_edges("generate", needs_approval,
                             {"wait_human": "wait_human", "auto_post": "auto_post"})
graph.add_edge("wait_human", "publish")
graph.add_edge("auto_post", "publish")
graph.add_edge("publish", END)

app = graph.compile(checkpointer=MemorySaver())

# Primera invocación: se pausa en interrupt
config = {"configurable": {"thread_id": "pr-42"}}
app.invoke({"pr_number": 42}, config)

# Más tarde (horas después, en otro proceso): resumir con decisión humana
app.invoke(Command(resume={"action": "approve", "edited_text": None}), config)
```

### Cola con timeout y escalation

```python
class ApprovalQueue:
    def __init__(self, storage, engine):
        self.storage = storage
        self.engine = engine

    async def process_timeouts(self):
        now = datetime.utcnow()
        for item in await self.storage.list_pending():
            if item.status != ApprovalStatus.PENDING or now <= item.expires_at:
                continue
            wf = self.engine.workflows[item.action_type]
            if wf.on_timeout == "escalate":
                item.status = ApprovalStatus.ESCALATED
                await self._escalate(item)
            elif wf.on_timeout == "auto_approve":
                item.status = ApprovalStatus.APPROVED
            else:
                item.status = ApprovalStatus.EXPIRED
            await self.storage.save(item)

    async def _escalate(self, item: PendingAction):
        # Buscar aprobador senior o manager
        new_approver = await self._find_escalation_target(item)
        await self.engine.notifier.escalate(item, new_approver)

class LoadBalancer:
    def __init__(self, storage):
        self.storage = storage

    async def pick(self, eligible: list[str], count: int) -> list[str]:
        loads = {}
        for a in eligible:
            loads[a] = len(await self.storage.pending_for(a))
        return sorted(eligible, key=lambda a: loads[a])[:count]
```

### UI de aprobación en Slack (Block Kit)

```python
def build_slack_approval(pending: PendingAction) -> dict:
    return {
        "blocks": [
            {"type": "header", "text": {"type": "plain_text",
                                         "text": f"Aprobación requerida: PR #{pending.payload['pr_number']}"}},
            {"type": "section", "text": {"type": "mrkdwn",
                                          "text": f"*Confianza:* {pending.payload['confidence']:.0%}\n"
                                                  f"*Expira:* <!date^{int(pending.expires_at.timestamp())}^{{time}}|pronto>"}},
            {"type": "section", "text": {"type": "mrkdwn",
                                          "text": f"```{pending.payload['draft_review'][:500]}```"}},
            {"type": "actions", "elements": [
                {"type": "button", "text": {"type": "plain_text", "text": "Aprobar"},
                 "style": "primary", "value": pending.action_id, "action_id": "approve"},
                {"type": "button", "text": {"type": "plain_text", "text": "Editar"},
                 "value": pending.action_id, "action_id": "edit"},
                {"type": "button", "text": {"type": "plain_text", "text": "Rechazar"},
                 "style": "danger", "value": pending.action_id, "action_id": "reject"},
            ]},
        ]
    }
```

## Errores comunes

- **Punto único de falla.** Solo una persona puede aprobar; cuando se enferma, todo se detiene. Define un **pool** y balancea carga.
- **Fatiga de aprobación por saturación.** Si el aprobador recibe 200 solicitudes al día, aprueba sin leer. Calibra el trigger y agrupa por batches.
- **Modificaciones perdidas.** El humano edita, el agente publica la versión editada, pero nadie guarda que hubo edición. Se pierde la señal de aprendizaje más valiosa.
- **Sin timeout.** Un item queda pendiente seis meses porque el aprobador olvidó la notificación. Siempre define `expires_at` y comportamiento post-timeout.
- **Timeout con `auto_approve` para acciones críticas.** Patrón peligroso: "si no responden en 10 minutos, se aprueba solo". Convierte el HITL en teatro.
- **Sin reasignación.** El aprobador designado está en PTO y nadie lo cubre. Detecta ausencia (Slack status, calendar) y reasigna automáticamente.
- **Contexto a destiempo.** Mostrar el diff completo de 5 mil líneas cuando el aprobador solo necesita saber que afecta `auth/`. Resume primero, expande bajo demanda.
- **Workflow único para todo.** `code review` y `database migration` tienen necesidades distintas de aprobación (1 vs. 2 aprobaciones, 2h vs. 24h de timeout). Workflow por tipo de acción.
- **No separar `approve` de `approve_with_edits`.** Si tratas ambos como "approved" en el audit log, pierdes la señal de que el humano no estaba de acuerdo con el borrador.
- **Olvidar auditoría.** Sin log inmutable de quién aprobó qué y cuándo, el workflow no sirve para regulación.

## Resumen

- Un workflow de aprobación define **trigger, routing, presentation, response, timeout y post-action** de forma explícita.
- El patrón técnico es **interrupt-and-resume**: el agente pausa su ejecución, persiste estado, notifica, y continúa cuando el humano responde. LangGraph `interrupt()`, OpenAI `required_action` y Temporal lo implementan.
- **Pools de aprobadores con load balancing** eliminan puntos únicos de falla.
- Las políticas de **timeout** (`escalate`, `auto_approve`, `auto_reject`) definen qué pasa cuando el humano no responde. Elige según el riesgo.
- **Capturar modificaciones** convierte las correcciones humanas en señal de entrenamiento para mejorar el agente.
- Errores recurrentes: fatiga por sobre-triggering, punto único de aprobador, modificaciones no registradas, timeouts peligrosos y workflows únicos para acciones de riesgos distintos.
- Buen workflow = **invisible cuando funciona, rastreable cuando falla**.
