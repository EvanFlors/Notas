# Observabilidad, modos de falla y control de costos

## ¿Qué es?

Un sistema tradicional falla **ruidosamente**: tira un `500`, lanza una excepción, el pod muere. Un agente falla **silenciosamente**: completa su ejecución sin errores, devuelve un JSON perfectamente formado, y aun así aprueba un PR con una inyección SQL o gasta $200 en una sola conversación.

La **observabilidad de agentes** es el conjunto de prácticas que hacen visible el razonamiento, las decisiones y el costo de un sistema agéntico. Opera en tres capas:

| Capa | Pregunta que responde | Métricas típicas |
|---|---|---|
| **Infraestructura** | ¿Está corriendo? | Uptime, latencia, error rate, memoria |
| **Comportamiento** | ¿Qué hizo el agente? | Tool calls, inputs/outputs, trayectoria |
| **Razonamiento** | ¿Por qué decidió eso? | Chain-of-thought, evidencia, confianza |

Las tres son necesarias. Un agente con infraestructura verde pero sin trazas de razonamiento es una caja negra que no puedes depurar. Las herramientas de referencia hoy: **LangSmith** (tracing nativo de LangGraph), **Langfuse** (open-source), **Arize Phoenix**, **Helicone**, **OpenLLMetry** (OpenTelemetry para LLMs).

## ¿Por qué importa?

Los modos de falla específicos de agentes son invisibles sin observabilidad dedicada:

- **Reasoning failures.** El agente llega a una conclusión incorrecta con confianza. El código corrió bien, el tool devolvió datos, pero el LLM interpretó mal. Sin traza del razonamiento, nunca sabrás *por qué*.
- **Loops infinitos silenciosos.** El agente llama `get_file("auth.py")` 47 veces, cada una exitosa, cada una cobrada. Sin métricas de repetición de acciones, el monitor dice "todo OK".
- **Token explosion.** Un PR grande hace que el agente cargue 200 archivos completos en contexto. La review termina en 30 segundos y cuesta $50. Sin métricas de costo por ejecución, el pico se promedia y desaparece.
- **Goal drift.** Pediste revisión de seguridad, el agente terminó recomendando refactors de estilo. Cada paso parecía razonable; el agregado no lo es. Sin anclaje explícito del objetivo en cada iteración, el agente se dispersa.

El costo de no tener observabilidad: incidentes que descubres por reportes de usuarios días después, debugging a ciegas, y la imposibilidad de iterar sobre prompts porque no puedes medir si el cambio ayudó.

## ¿Cómo funciona?

### 1. Tracing jerárquico

Cada ejecución de agente se modela como un **trace**: un árbol de **spans** anidados. El trace raíz es la invocación completa; los hijos son nodos, tool calls y llamadas al LLM:

```
trace: review_pr(1247)                           duration=12.3s  cost=$0.42
├── span: node[security]                         duration=4.1s   cost=$0.18
│   ├── span: llm.call(sonnet-4-5)              tokens=4500/800
│   └── span: tool.scan_security(1247)          duration=1.2s
├── span: node[coverage]                         duration=3.8s   cost=$0.15
│   └── span: llm.call(sonnet-4-5)              tokens=3900/700
└── span: node[publish]                          duration=0.4s   cost=$0.01
```

LangSmith lo visualiza automáticamente para cualquier chain/graph de LangChain/LangGraph. Para stacks mixtos, **OpenLLMetry** emite spans OpenTelemetry compatibles con Datadog, Honeycomb o Jaeger.

### 2. Decision logging con contexto

Cada decisión relevante del agente debe loguearse con `(decisión, razonamiento, evidencia, confianza)`:

```json
{
  "ts": "2026-10-07T12:34:05Z",
  "review_id": "pr-1247",
  "decision": "approve",
  "reasoning": "Scanner reportó 0 vulnerabilidades; variable se llama safe_query.",
  "evidence": ["scan_result.vulns=[]", "diff:L47"],
  "confidence": 0.70
}
```

Cuando llegue el reporte "aprobó un PR vulnerable", esta línea te dice *exactamente* qué pensaba el agente al decidir. En este caso, revelaría que se dejó engañar por el nombre de la variable.

### 3. Métricas de calidad (no solo de disponibilidad)

Infra te dice si corre; calidad te dice si acierta:

| Métrica | Fuente | Alerta típica |
|---|---|---|
| Tasa de aprobación | Decisiones logueadas | > 95% en 2h → agente demasiado permisivo |
| Precisión / recall | Ground truth humano o reglas | Accuracy < 85% en 24h |
| Tokens por ejecución (p95, p99) | Trazas | p99 > 10x p50 → cola larga, probables loops |
| $ por ejecución (p99) | Trazas × tarifa | p99 > budget_item → alerta |
| Iteraciones por ejecución | Loop counter | p99 > N → probables loops |

### 4. Detección de loops y goal drift

Dos chequeos baratos que previenen el 80% de los runaway runs:

```python
def detectar_loop(historial: list[dict], ventana: int = 5) -> bool:
    """Si las últimas N acciones son idénticas, hay loop."""
    if len(historial) < ventana:
        return False
    ultimas = [(a["tool"], tuple(sorted(a["args"].items())))
               for a in historial[-ventana:]]
    return len(set(ultimas)) == 1

def anclar_objetivo(messages: list, goal: str) -> list:
    """Reinyecta el goal en cada iteración (contra goal drift)."""
    return messages + [{"role": "system",
                        "content": f"Recuerda: tu objetivo es {goal}."}]
```

### 5. Token budgets y circuit breakers de calidad

El circuit breaker clásico se abre con errores. Para agentes necesitas uno que también se abra cuando la **calidad** cae:

```python
class QualityCircuitBreaker:
    def __init__(self, min_quality=0.80, window=20):
        self.scores: list[float] = []
        self.min_quality = min_quality
        self.window = window
        self.state = "closed"   # closed | degraded | open

    def record(self, quality: float):
        self.scores.append(quality)
        self.scores = self.scores[-self.window:]
        avg = sum(self.scores) / len(self.scores)
        if avg < self.min_quality:
            self.state = "degraded"   # enruta a revisión humana
```

### 6. Control de costos: diffs, routing y caching

| Técnica | Ahorro típico | Cuándo |
|---|---|---|
| Diff en vez de archivo completo | 10-20× | Code review, refactors |
| Progressive context (cargar bajo demanda) | 3-5× | Agentes con muchos archivos |
| Model routing (haiku para fácil, sonnet para complejo) | 5-10× | Workloads heterogéneos |
| Prompt caching (Anthropic / OpenAI) | hasta 90% en input repetido | System prompts largos, documentos grandes |
| Resumir historia vieja | Evita crecimiento cuadrático | Agentes de muchas iteraciones |

## Ejemplo con código

Agente instrumentado con tracing explícito, decision logging, loop detection y token budget.

```python
import time
import json
from dataclasses import dataclass, field
from anthropic import Anthropic

client = Anthropic()

# ────────────────────────────────────────────────────────────
# 1. Logger de decisiones + spans mínimos
# ────────────────────────────────────────────────────────────
@dataclass
class Span:
    name: str
    start: float = field(default_factory=time.time)
    attrs: dict = field(default_factory=dict)

    def end(self, **kv):
        self.attrs.update(kv)
        self.attrs["duration_s"] = round(time.time() - self.start, 3)
        print(json.dumps({"span": self.name, **self.attrs}))

def log_decision(review_id, decision, reasoning, evidence, confidence):
    print(json.dumps({
        "type": "decision",
        "review_id": review_id,
        "decision": decision,
        "reasoning": reasoning,
        "evidence": evidence,
        "confidence": confidence,
    }))

# ────────────────────────────────────────────────────────────
# 2. Token budget
# ────────────────────────────────────────────────────────────
class TokenBudget:
    def __init__(self, max_input: int, max_output: int):
        self.max_in, self.max_out = max_input, max_output
        self.used_in = self.used_out = 0

    def can_continue(self, est_in=3000, est_out=500) -> bool:
        return (self.used_in + est_in <= self.max_in and
                self.used_out + est_out <= self.max_out)

    def record(self, in_t: int, out_t: int):
        self.used_in += in_t
        self.used_out += out_t

# ────────────────────────────────────────────────────────────
# 3. Loop detection
# ────────────────────────────────────────────────────────────
def es_loop(historial: list[tuple], ventana: int = 4) -> bool:
    if len(historial) < ventana:
        return False
    return len(set(historial[-ventana:])) == 1

# ────────────────────────────────────────────────────────────
# 4. Agent con todas las defensas
# ────────────────────────────────────────────────────────────
def review_pr(pr_number: int, max_iter: int = 15) -> dict:
    review_id = f"pr-{pr_number}"
    goal = f"Revisar PR #{pr_number} buscando vulnerabilidades de seguridad."
    budget = TokenBudget(max_input=50_000, max_output=8_000)
    historial: list[tuple] = []

    trace = Span("review_pr", attrs={"pr_number": pr_number})
    messages = [{"role": "user", "content": goal}]

    for i in range(max_iter):
        # ── Guards ──
        if not budget.can_continue():
            trace.end(status="budget_exhausted", iter=i)
            return {"status": "partial", "reason": "budget"}

        if es_loop(historial):
            trace.end(status="loop_detected", iter=i)
            return {"status": "partial", "reason": "loop"}

        # ── Reinyectar goal (anti goal-drift) ──
        msgs = messages + [{"role": "system",
                            "content": f"Objetivo: {goal}"}]

        span = Span(f"llm.call[iter={i}]")
        resp = client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=1024,
            messages=msgs,
        )
        budget.record(resp.usage.input_tokens, resp.usage.output_tokens)
        span.end(
            tokens_in=resp.usage.input_tokens,
            tokens_out=resp.usage.output_tokens,
            stop_reason=resp.stop_reason,
        )

        # Simulamos extracción de tool call para loop detection
        accion = ("llm_call", resp.stop_reason)
        historial.append(accion)

        if resp.stop_reason == "end_turn":
            texto = resp.content[0].text
            log_decision(
                review_id=review_id,
                decision="approve" if "LGTM" in texto else "request_changes",
                reasoning=texto[:200],
                evidence=["iter=" + str(i)],
                confidence=0.75,
            )
            trace.end(status="done", iter=i,
                      cost_tokens=budget.used_in + budget.used_out)
            return {"status": "done", "verdict": texto}

        messages.append({"role": "assistant", "content": resp.content})

    trace.end(status="max_iter", iter=max_iter)
    return {"status": "partial", "reason": "max_iter"}
```

**Qué observar:** cada iteración emite spans estructurados; cada decisión final queda logueada con razonamiento; tres guards (`budget`, `loop`, `max_iter`) convierten el peor caso en un *partial result* conocido en vez de una factura sorpresa.

### Integración con LangSmith (ejemplo real)

Para proyectos LangGraph/LangChain, el tracing es automático con dos variables de entorno:

```bash
export LANGSMITH_TRACING=true
export LANGSMITH_API_KEY=lsv2_pt_...
export LANGSMITH_PROJECT=code-review-agent
```

A partir de ahí, cada `app.invoke(...)` aparece en el dashboard de LangSmith con el grafo completo, inputs/outputs por nodo, tokens, costo estimado y latencias.

## Errores comunes

- **No observability (agent fallando silenciosamente).** El síntoma: te enteras del bug por un usuario, no por una alerta. Instala tracing *antes* del primer deploy; es 10× más barato que debuggear a ciegas después.
- **Timeout de agent loops.** Confiar solo en el `timeout` HTTP del request. Un agente puede terminar "en tiempo" y aun así haber gastado $50. Defiende con `max_iterations` + `token_budget` + loop detection, no solo con `timeout`.
- **Métricas promediadas que esconden colas largas.** El "costo promedio por review" es $0.05, pero el p99 es $12. El promedio miente. Monitorea p50, p95, p99 por separado y alerta sobre p99/p50 > 20×.
- **Loguear outputs crudos del LLM sin estructura.** 10GB de JSON diario que nadie puede consultar. Loguea decisiones estructuradas (campos tipados) y resúmenes; guarda el raw solo con sampleo (ej. 1% o todas las que fallan).
- **No capturar el razonamiento.** Loguear "approved" sin el "why" te deja sin forma de depurar. El payload mínimo es `(decision, reasoning, evidence, confidence)`.
- **PII y secretos en las trazas.** El contenido de un ticket puede incluir datos de clientes. Redacta/anonimiza antes de enviar a LangSmith/Langfuse, o usa deployment self-hosted de la herramienta.
- **Alertar solo sobre errores HTTP.** El agente que aprueba el 100% de los PRs no lanza errores; es exitoso según el status code. Alerta sobre **cambios de distribución** (approval rate, duración p99, tokens p99).
- **No tener un "quality circuit breaker".** Cuando la calidad cae, el agente debe degradar a humano, no seguir sirviendo malas decisiones a todo el tráfico.

## Resumen

- Observabilidad de agentes opera en **tres capas**: infraestructura (¿corre?), comportamiento (¿qué hizo?), razonamiento (¿por qué?).
- Modos de falla específicos: **reasoning failures**, **loops silenciosos**, **token explosion**, **goal drift**. Ninguno aparece en métricas infra tradicionales.
- Modela cada ejecución como un **trace** con spans anidados por nodo, tool y llamada al LLM. Herramientas: **LangSmith**, **Langfuse**, **Arize Phoenix**, **Helicone**, **OpenLLMetry**.
- Loguea decisiones con **razonamiento, evidencia y confianza** — no solo el verdict.
- Métricas de calidad > métricas de disponibilidad: approval rate, p99 de tokens, p99 de costo, iteraciones por ejecución.
- Defensas contra runaway: **token budget**, **loop detection**, **goal anchoring**, **quality circuit breaker**, **max_iterations**.
- Control de costo: **diffs** en vez de archivos completos (10-20×), **model routing** (haiku para fácil, sonnet para complejo), **prompt caching**, **resumir historia vieja**.
- Alerta sobre **cambios de distribución** (p99, approval rate), no solo errores HTTP. Un agente que nunca falla puede estar fallando siempre.
- PII y secretos: redacta antes de enviar a plataformas externas de observabilidad.
