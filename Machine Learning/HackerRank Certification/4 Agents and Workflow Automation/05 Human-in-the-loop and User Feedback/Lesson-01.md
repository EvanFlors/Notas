# Por qué importa la supervisión humana

## ¿Qué es?

**Human-in-the-Loop (HITL)** es un patrón de diseño en el que un humano participa en puntos específicos del ciclo de decisión de un agente autónomo. En lugar de dejar que el modelo ejecute todas las acciones sin intervención, HITL inserta **checkpoints de supervisión** donde una persona aprueba, corrige, rechaza o retroalimenta la propuesta del agente antes (o después) de que tenga efecto en el mundo real.

> **Definición operativa:** Un sistema es HITL si, para al menos una clase de acción, la ejecución está condicionada o puede ser modificada por una decisión humana registrada.

La supervisión humana no es desconfianza hacia el agente: es **confianza calibrada**. Nadie despliega software sin pruebas, monitoreo y la capacidad de intervenir. Los agentes no son la excepción; son software probabilístico cuyos errores no se eliminan completamente con testing.

### El espectro de autonomía

Los agentes no son "manuales" o "autónomos" en blanco y negro. Existen al menos cuatro niveles claros, y un sistema maduro combina varios según el tipo de acción:

| Nivel | Quién decide | Quién ejecuta | Ejemplo (code review agent) |
|---|---|---|---|
| **Totalmente manual** | Humano | Humano | El agente solo analiza y presenta hallazgos; el humano escribe el review |
| **Human-initiated** | Humano aprueba propuesta | Agente ejecuta tras aprobación | El agente redacta el comentario y espera "approve" antes de publicarlo |
| **Agent-initiated con override** | Agente decide, humano puede revertir | Agente ejecuta, humano edita/retracta | El agente publica reviews automáticos; el humano puede borrarlos o editarlos |
| **Totalmente autónomo** | Agente | Agente | El agente revisa, comenta y mergea PRs sin intervención |

![Espectro de autonomía: del control humano a la independencia del agente](https://hrcdn.net/ai-engineering/module-4/light/hitl-lesson01-autonomy-spectrum.svg)

### HITL en el ecosistema actual

- **Anthropic Claude Code** pide confirmación antes de ejecutar comandos destructivos (`rm -rf`, `git push --force`). El modelo propone, el humano acepta.
- **OpenAI Assistants API** expone `required_action` cuando una tool call necesita input humano para continuar (`submit_tool_outputs` pausa el run hasta recibir respuesta).
- **GitHub Copilot Workspace** genera un plan completo antes de modificar código; el usuario revisa y edita antes de la ejecución.
- **RLHF (Reinforcement Learning from Human Feedback)** es HITL aplicado al *entrenamiento*: humanos rankean salidas para alinear el modelo base.

## ¿Por qué importa?

Un agente de code review desplegado sin supervisión eventualmente auto-aprobará un PR con un bypass de autenticación sutil. Lo analizará, concluirá que es seguro, y se equivocará. Sin HITL, la vulnerabilidad llega a producción. Este patrón se repite en todos los dominios: el modelo tiene un desempeño alto en promedio pero su cola de errores es inaceptablemente costosa.

HITL importa porque:

- **Los agentes alucinan.** Un LLM puede inventar APIs, tablas o políticas de seguridad con tono convincente. Sin humano, el error se propaga.
- **El costo de errores es asimétrico.** Un falso positivo en un comentario de review molesta a un dev; un falso negativo en un chequeo de seguridad compromete el sistema entero.
- **El contexto completo rara vez está en el prompt.** El agente no sabe que el repo `legacy-auth` está congelado hasta que la migración termine. Un humano sí.
- **La regulación lo exige.** GDPR Art. 22 (decisiones automatizadas), EU AI Act (sistemas de alto riesgo), HIPAA, SOX. En muchos dominios, acción autónoma sin human review es ilegal.
- **Habilita la mejora continua.** Las correcciones humanas son la fuente más rica de datos para fine-tuning, prompt engineering y evaluación.

### Cuándo NO poner humano en el loop

- **Acciones triviales y reversibles de alto volumen:** un humano revisando mil tags de "necesita triaje" por hora produce fatiga y rubber-stamping.
- **Latencia crítica:** un sistema anti-fraude en el checkout no puede esperar 30 segundos a que un humano apruebe.
- **Dominio bien calibrado con telemetría densa:** si tienes 6 meses de datos mostrando >99% precisión en una clase, el humano agrega ruido más que señal.

## ¿Cómo funciona?

### Identificar decisiones de alto riesgo

No toda acción del agente necesita supervisión. Tres dimensiones determinan el riesgo:

| Dimensión | Pregunta | Bajo riesgo | Alto riesgo |
|---|---|---|---|
| **Reversibilidad** | ¿Qué tan fácil es deshacer esto? | Postear comentario (se borra) | `DROP TABLE` en producción |
| **Impacto (blast radius)** | ¿A cuántas personas o sistemas afecta? | Un archivo | Todos los usuarios |
| **Confianza del agente** | ¿Qué tan seguro está el modelo? | 0.95 en caso rutinario | 0.4 en caso novedoso |

**Regla práctica:** `requiere_humano = (reversibilidad == baja) OR (impacto == alto) OR (confianza < umbral)`.

### Patrones HITL comunes

| Patrón | Momento del humano | Caso de uso |
|---|---|---|
| **Approval** | Antes de ejecutar | Acciones costosas o irreversibles (deploy, pago, merge a main) |
| **Review** | Después de ejecutar | Acciones reversibles donde queremos auditoría (comentarios publicados) |
| **Correction / Edit** | Durante la ejecución | Humano modifica la propuesta del agente antes de que surta efecto |
| **Teaching** | Fuera de línea | Humano etiqueta ejemplos para mejorar prompt o entrenar |
| **Escalation** | Cuando el agente duda | El agente decide pedir ayuda explícitamente (low confidence) |

### Presentación de contexto para humanos

Un `"Approve?"` sin contexto fuerza al humano a investigar por su cuenta. Una buena solicitud de aprobación incluye:

- Resumen de la acción propuesta y por qué.
- Confianza y señales que la respaldan (o la debilitan).
- Efectos de aprobar vs. rechazar.
- Deadline (`expires_at`) y comportamiento default si no se responde.
- Link al contexto completo (PR, log, trace) por si el humano quiere profundizar.

### Canales: encontrar al humano donde trabaja

Un ingeniero vive en Slack; un gerente en email; un operador on-call en PagerDuty. El sistema debe soportar múltiples canales de notificación con el mismo backend de aprobación.

## Ejemplo con código

### Policy Engine: decidir cuándo requerir humano

```python
from dataclasses import dataclass
from enum import Enum
from typing import Any

class Autonomy(str, Enum):
    MANUAL = "manual"
    HUMAN_INITIATED = "human_initiated"
    AGENT_INITIATED = "agent_initiated"
    AUTONOMOUS = "autonomous"

@dataclass
class ActionPolicy:
    autonomy: Autonomy
    requires_approval: bool
    confidence_threshold: float = 0.0  # si confianza < umbral, forzar humano

class PolicyEngine:
    def __init__(self):
        self.policies: dict[str, ActionPolicy] = {
            "post_comment":    ActionPolicy(Autonomy.AGENT_INITIATED, False, 0.6),
            "request_changes": ActionPolicy(Autonomy.HUMAN_INITIATED, True,  0.8),
            "approve_pr":      ActionPolicy(Autonomy.HUMAN_INITIATED, True,  0.9),
            "auto_merge":      ActionPolicy(Autonomy.MANUAL,          True,  1.0),
            "delete_branch":   ActionPolicy(Autonomy.MANUAL,          True,  1.0),
        }

    def requires_human(self, action: str, context: dict[str, Any]) -> bool:
        policy = self.policies.get(action)
        if policy is None:
            # Default conservador: desconocido = pedir humano
            return True
        if policy.requires_approval:
            return True
        if context.get("agent_confidence", 1.0) < policy.confidence_threshold:
            return True
        return False
```

### Risk Assessor: combinar reversibilidad, impacto y confianza

```python
class RiskAssessor:
    REVERSIBILITY = {
        "post_comment":  "low",       # fácil de deshacer
        "approve_pr":    "medium",
        "merge_pr":      "high",
        "delete_branch": "critical",  # casi irreversible
    }

    def assess(self, action: str, context: dict) -> dict:
        reversibility = self.REVERSIBILITY.get(action, "medium")
        impact = self._impact(context)
        confidence = context.get("agent_confidence", 0.5)

        score = 0
        score += {"low": 0, "medium": 1, "high": 2, "critical": 3}[reversibility]
        score += {"low": 0, "medium": 1, "high": 2}[impact]
        score += 2 if confidence < 0.6 else (1 if confidence < 0.8 else 0)

        level = "low" if score <= 2 else ("medium" if score <= 4 else "high")
        return {
            "risk": level,
            "reversibility": reversibility,
            "impact": impact,
            "confidence": confidence,
            "requires_human": level != "low",
        }

    def _impact(self, context: dict) -> str:
        files = context.get("files_changed", 0)
        if context.get("touches_auth") or context.get("touches_payments"):
            return "high"
        if files > 20:
            return "high"
        return "medium" if files > 5 else "low"
```

### Solicitud de aprobación con contexto rico

```python
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass
class ApprovalRequest:
    request_id: str
    action: str
    pr_number: int
    summary: str
    proposed_action: str
    confidence: float
    key_findings: list[str]
    approval_effect: str
    rejection_effect: str
    expires_at: datetime
    channel: str  # "slack" | "email" | "pagerduty"

def build_request(action: str, pr: dict, review: dict, confidence: float) -> ApprovalRequest:
    return ApprovalRequest(
        request_id=f"req-{pr['number']}-{int(datetime.utcnow().timestamp())}",
        action=action,
        pr_number=pr["number"],
        summary=f"PR #{pr['number']}: {pr['title']} ({pr['files_changed']} archivos)",
        proposed_action=review["recommendation"],
        confidence=confidence,
        key_findings=review["findings"][:3],  # top 3
        approval_effect="El review se publica como comentario bloqueante",
        rejection_effect="El review se descarta; nada se publica",
        expires_at=datetime.utcnow() + timedelta(hours=4),
        channel="slack" if pr["author_role"] == "engineer" else "email",
    )
```

## Errores comunes

- **Pedir confirmación en todo.** Produce **fatiga de aprobación**: el humano empieza a hacer rubber-stamp sin leer. Peor que no pedir, porque genera falsa sensación de control. Solución: calibra para que solo las decisiones genuinamente de alto riesgo lleguen al humano.
- **No pedir confirmación en nada.** El agente ejecuta acciones irreversibles con 0.4 de confianza en un caso que nunca vio. Daño silencioso.
- **Contexto insuficiente en la solicitud.** `"¿Apruebas este PR review?"` sin findings, confianza ni resumen fuerza al humano a investigar. Terminan aprobando por desgaste.
- **Sin timeout definido.** Si el aprobador está de vacaciones, la acción queda pendiente para siempre. Define `on_timeout`: `escalate`, `auto_approve` (solo para bajo riesgo) o `auto_reject`.
- **Un solo aprobador.** Punto único de falla. Define pools de aprobadores elegibles con load balancing.
- **No capturar la razón del rechazo.** El humano rechaza pero no explica por qué; el agente comete el mismo error mañana. Habilita campo libre `rejection_reason` y úsalo para refinar prompts.
- **Mezclar niveles de autonomía en una sola política global.** `requires_approval: True` para todo el agente es demasiado grueso. Define política por tipo de acción.
- **Olvidar la observabilidad.** Si no mides tasa de aprobación, tiempo de respuesta y tasa de modificación, no puedes calibrar el sistema.
- **HITL cosmético.** Mostrar un botón "Approve" que, si no responden en 2 segundos, auto-aprueba. Es teatro de seguridad, no supervisión.

## Resumen

- **Human-in-the-loop** inserta checkpoints humanos en el ciclo de decisión del agente para capturar errores antes de que causen daño.
- Los agentes existen en un **espectro de autonomía**: manual, human-initiated, agent-initiated con override, totalmente autónomo. Sistemas maduros mezclan niveles por tipo de acción.
- Tres dimensiones determinan si una acción necesita humano: **reversibilidad**, **impacto** y **confianza del agente**.
- Patrones HITL clave: **approval** (antes), **review** (después), **correction** (durante), **teaching** (offline), **escalation** (el agente pide ayuda).
- Una buena solicitud de aprobación incluye **contexto rico**: resumen, confianza, efectos de aprobar/rechazar, deadline y canal apropiado.
- Errores clásicos: fatiga por sobre-aprobación, daño silencioso por sub-aprobación, contexto pobre, timeouts indefinidos y aprobador único.
- HITL es **confianza calibrada**, no desconfianza: libera al humano del trabajo rutinario para enfocarlo donde su juicio es insustituible.
