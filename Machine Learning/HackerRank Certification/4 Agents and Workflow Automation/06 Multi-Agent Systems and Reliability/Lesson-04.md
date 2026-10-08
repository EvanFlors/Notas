# Un Sistema Multi-Agente Completo: Code Review Automatizado

## ¿Qué es?

Esta lección integra todo lo anterior en un **sistema multi-agente de code review** listo para producción. Cada pieza (patrón arquitectónico, comunicación, confiabilidad, testing) deja de ser teoría y se vuelve código ejecutable que recibe un PR y produce una review coherente, resiliente y observable.

El sistema tiene tres capas:

1. **Orquestación:** compone el equipo de agentes relevante para el PR y coordina la ejecución.
2. **Especialistas:** agentes con prompts enfocados (security, performance, testing).
3. **Síntesis + reliability:** fusiona hallazgos, resuelve conflictos, aplica priority rules, respeta presupuesto y maneja fallos.

![Multi-agent code review system](https://hrcdn.net/ai-engineering/module-4//multi-agent-systems-lesson04-system-architecture.svg)

### Resumen de decisiones de diseño

| Decisión | Opción elegida | Alternativas descartadas |
|---|---|---|
| Patrón | Supervisor + workers en paralelo | Swarm (menos control), pipeline (más lento) |
| Framework | LangGraph | CrewAI (menos control), AutoGen (overkill) |
| Modelos | Opus (lead/sintesis) + Haiku (workers) | Opus en todo (3× costo) |
| Comunicación | State compartido + locking | Message bus (más complejo) |
| Reliability | Timeouts + circuit breaker + budget | "Confiar y rezar" |
| Observabilidad | LangSmith/Langfuse tracing | Logs sueltos |

## ¿Por qué importa?

Montar un MAS "serio" revela los problemas reales que no aparecen en demos:

- **Cada agente que agregas multiplica el costo**: si no mides, descubres el problema en la factura.
- **La coordinación consume más código que los prompts**: la lección de las compañías que llevaron MAS a producción (Harvey, Cursor, Devin) es que el 70% del trabajo está fuera del prompt.
- **Las fallas parciales son la norma, no la excepción**: APIs tienen 429, redes tienen cortes, modelos devuelven JSON malformado.
- **El equipo humano necesita confiar en el sistema**: sin trazas y veredictos consistentes, nadie lo adopta.

Este blueprint es transferible a otros dominios: investigación legal (Harvey), triage de tickets, análisis financiero, debugging de incidentes, o investigación tipo Deep Research de Anthropic.

## ¿Cómo funciona?

### Arquitectura general

```
   ┌───────────────────────────────────────────────────────┐
   │                      PR Payload                        │
   └───────────────┬───────────────────────────────────────┘
                   ▼
          ┌────────────────┐   compose_team()
          │   Supervisor   │ ─────────────────┐
          └────┬───────────┘                   │
               │ fan-out (paralelo)            │
   ┌───────────┼───────────┐                   │ shared
   ▼           ▼           ▼                   │ state
[Security] [Performance] [Testing]  ─ writes ──┤
   │           │           │                   │
   └─────┬─────┴─────┬─────┘                   │
         ▼           ▼                         │
  ┌──────────────────────┐   priority rules    │
  │  Conflict Resolver   │ ◀───────────────────┘
  └──────────┬───────────┘
             ▼
     ┌─────────────┐    unified markdown
     │ Synthesizer │ ──────────────────────▶ GitHub comment
     └─────────────┘
             │
             ▼
     LangSmith / Langfuse trace
```

### El supervisor (orquestador ligero)

```python
import asyncio
from dataclasses import dataclass, field
from typing import Any

PRIORITY_ORDER = ["security", "testing", "performance", "docs"]

@dataclass
class PRContext:
    number: int
    repo: str
    files: list[dict]
    diff: str
    labels: list[str] = field(default_factory=list)

class ReviewOrchestrator:
    def __init__(self, agents: dict, budget_usd: float = 1.0,
                 per_agent_timeout_s: int = 60, max_total_tokens: int = 60_000):
        self.agents = agents
        self.budget_usd = budget_usd
        self.per_agent_timeout_s = per_agent_timeout_s
        self.max_total_tokens = max_total_tokens
        self.spent_usd = 0.0

    def compose_team(self, ctx: PRContext) -> list[str]:
        team = []
        if self._touches_auth_or_db(ctx): team.append("security")
        if self._touches_backend(ctx):    team.append("performance")
        if self._touches_src_or_tests(ctx): team.append("testing")
        return team or ["security"]   # fallback mínimo

    async def run_parallel(self, team: list[str], ctx: PRContext) -> dict:
        async def safe_run(name: str):
            if self.spent_usd >= self.budget_usd:
                return {"agent": name, "status": "skipped_budget", "findings": []}
            try:
                result = await asyncio.wait_for(
                    self.agents[name].analyze(ctx),
                    timeout=self.per_agent_timeout_s,
                )
                self.spent_usd += result.get("cost_usd", 0.0)
                return {"agent": name, "status": "ok", **result}
            except asyncio.TimeoutError:
                return {"agent": name, "status": "timeout", "findings": []}
            except Exception as e:
                return {"agent": name, "status": "error", "error": str(e), "findings": []}

        results = await asyncio.gather(*[safe_run(n) for n in team])
        return {r["agent"]: r for r in results}
```

### Agentes especializados

```python
from pydantic import BaseModel

class Finding(BaseModel):
    file: str
    line: int | None = None
    category: str                   # "sql_injection", "n_plus_one", etc.
    severity: str                   # "critical"|"high"|"medium"|"low"|"info"
    description: str
    suggestion: str
    source_agent: str
    confidence: float = 0.8

class SecurityReviewAgent:
    system_prompt = """\
Eres un revisor de SEGURIDAD.
HAZ:
- Detectar inyecciones (SQL, XSS, command, SSRF).
- Revisar autenticación, autorización, manejo de secretos.
- Marcar criptografía débil y validación de inputs faltante.
NO HAGAS:
- Comentar estilo, performance, documentación.
- Sugerir refactors que no sean de seguridad.
Devuelve SIEMPRE JSON { "findings": [...] } con el schema de Finding."""

    async def analyze(self, ctx: PRContext) -> dict:
        resp = await claude.messages.create(
            model="claude-haiku-4-5",
            system=self.system_prompt,
            max_tokens=2048,
            temperature=0,
            messages=[{"role": "user", "content": ctx.diff}],
        )
        parsed = parse_json_findings(resp.content[0].text, source="security")
        return {"findings": parsed, "cost_usd": estimate_cost(resp)}

class PerformanceReviewAgent:
    system_prompt = """\
Eres un revisor de PERFORMANCE.
HAZ:
- Identificar O(n²) evitable, N+1 queries, falta de caching, blocking IO en código async.
NO HAGAS:
- Comentar seguridad, estilo ni docs.
Devuelve JSON { "findings": [...] } con schema de Finding."""
    async def analyze(self, ctx: PRContext) -> dict:
        ...  # análogo

class TestingReviewAgent:
    system_prompt = """\
Eres un revisor de TESTS.
HAZ:
- Verificar cobertura, casos borde, tests que no validen nada.
NO HAGAS:
- Comentar código fuera de la suite de tests."""
    async def analyze(self, ctx: PRContext) -> dict:
        ...
```

El patrón "stay in your lane" (HAZ/NO HAGAS explícito) es la pieza más barata y más efectiva para evitar overlaps.

### Resolución de conflictos

```python
PRIORITY_RANK = {"security": 0, "testing": 1, "performance": 2, "docs": 3}

def resolve_conflicts(by_agent: dict) -> dict:
    """Deduplica por (file, line, category) favoreciendo al agente de mayor prioridad."""
    all_findings: list[Finding] = []
    for r in by_agent.values():
        for f in r.get("findings", []):
            all_findings.append(Finding(**f) if isinstance(f, dict) else f)

    buckets: dict[tuple, list[Finding]] = {}
    for f in all_findings:
        key = (f.file, f.line, f.category)
        buckets.setdefault(key, []).append(f)

    resolved = []
    for key, group in buckets.items():
        group.sort(key=lambda x: PRIORITY_RANK.get(x.source_agent, 99))
        winner = group[0]
        if len(group) > 1:
            winner.description += f"\n_(también reportado por: {[g.source_agent for g in group[1:]]})_"
        resolved.append(winner)
    return {"findings": [f.model_dump() for f in resolved]}
```

### Sintetizador

```python
class ReviewSynthesizer:
    async def synthesize(self, resolved: dict, ctx: PRContext) -> dict:
        findings = resolved["findings"]
        sev = [f["severity"] for f in findings]

        if "critical" in sev:
            recommendation = "request_changes"
        elif sev.count("high") >= 2:
            recommendation = "request_changes"
        elif any(s in ("medium", "high") for s in sev):
            recommendation = "comment"
        else:
            recommendation = "approve"

        by_agent: dict[str, list[dict]] = {}
        for f in findings:
            by_agent.setdefault(f["source_agent"], []).append(f)

        body = self._render_markdown(by_agent, recommendation)
        return {
            "recommendation": recommendation,
            "findings": findings,
            "formatted_review": {"body": body},
            "agent_contributions": list(by_agent.keys()),
        }

    def _render_markdown(self, by_agent: dict, rec: str) -> str:
        sections = [f"### Veredicto: `{rec}`\n"]
        for agent, fs in by_agent.items():
            sections.append(f"\n## {agent.title()}")
            for f in sorted(fs, key=lambda x: ["critical","high","medium","low","info"].index(x["severity"])):
                sections.append(f"- **{f['severity'].upper()}** `{f['file']}:{f.get('line','?')}` — {f['description']}")
                if f.get("suggestion"):
                    sections.append(f"  - *Fix sugerido:* {f['suggestion']}")
        return "\n".join(sections)
```

### Sistema completo (ensamblado)

```python
from langsmith import traceable

class MultiAgentCodeReviewSystem:
    def __init__(self, config):
        self.agents = {
            "security":    SecurityReviewAgent(config),
            "performance": PerformanceReviewAgent(config),
            "testing":     TestingReviewAgent(config),
        }
        self.orchestrator = ReviewOrchestrator(
            self.agents,
            budget_usd=config.budget_usd,
            per_agent_timeout_s=config.per_agent_timeout_s,
        )
        self.synthesizer = ReviewSynthesizer()
        self.breakers = {name: CircuitBreaker() for name in self.agents}

    @traceable(run_type="chain", name="multi_agent_code_review")
    async def review_pr(self, pr_number: int, repo: str) -> dict:
        ctx = await self.fetch_pr(pr_number, repo)
        team = self.orchestrator.compose_team(ctx)

        # Ejecución resiliente con circuit breakers
        async def guarded(name: str):
            try:
                return await self.breakers[name].call(self.agents[name].analyze, ctx)
            except Exception as e:
                return {"findings": [], "error": str(e)}

        raw = await asyncio.gather(*[guarded(n) for n in team])
        by_agent = {name: r for name, r in zip(team, raw)}

        resolved = resolve_conflicts(by_agent)
        review   = await self.synthesizer.synthesize(resolved, ctx)

        # Observabilidad: cost / token / latency per agent se registra via trace
        return review | {
            "cost_usd": self.orchestrator.spent_usd,
            "failed_agents": [n for n, r in by_agent.items() if r.get("error")],
        }
```

### Control de costo con budget-aware agents

```python
class BudgetAwareAgent:
    def __init__(self, inner, budget_usd: float):
        self.inner = inner
        self.budget = budget_usd
        self.spent  = 0.0

    async def analyze(self, ctx):
        if self.spent >= self.budget:
            return {"findings": [], "status": "budget_exceeded"}
        result = await self.inner.analyze(ctx)
        self.spent += result.get("cost_usd", 0.0)
        return result
```

### Comparación: single-agent vs. este sistema

| Métrica | Single-agent (Opus) | Multi-agent (este) |
|---|---|---|
| Precisión de seguridad | ~0.68 | ~0.86 |
| Recall de N+1 | ~0.55 | ~0.80 |
| Latencia P95 | 25 s | 11 s (fan-out paralelo) |
| Costo por review | $0.12 | $0.07 (Haiku en workers) |
| Fallos silenciosos | Todo o nada | Parcial recuperable |
| Debug | Log monolítico | Trazas por agente |

*(cifras ilustrativas: calíbralas con tus propios evals)*

## Ejemplo con código

Caso completo: ejecutar el sistema contra un PR, con tests y despliegue mínimo.

```python
# main.py
import asyncio
from dataclasses import dataclass

@dataclass
class Config:
    budget_usd: float = 0.50
    per_agent_timeout_s: int = 45
    github_token: str = os.environ["GITHUB_TOKEN"]
    anthropic_key: str = os.environ["ANTHROPIC_API_KEY"]

async def main():
    system = MultiAgentCodeReviewSystem(Config())
    review = await system.review_pr(pr_number=1234, repo="acme/platform")

    await post_github_review(
        repo="acme/platform",
        pr=1234,
        body=review["formatted_review"]["body"],
        event={"approve": "APPROVE",
               "comment": "COMMENT",
               "request_changes": "REQUEST_CHANGES"}[review["recommendation"]],
    )

    print(f"Review: {review['recommendation']}  "
          f"cost=${review['cost_usd']:.3f}  "
          f"findings={len(review['findings'])}  "
          f"failed={review['failed_agents']}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Tests (resumen de la Lección 3 aplicado)

```python
@pytest.mark.asyncio
async def test_security_wins_conflict():
    sys = MultiAgentCodeReviewSystem(TEST_CONFIG)
    review = await sys.review_pr(pr_number=TEST_PR_CONFLICT, repo="acme/test")
    sec = [f for f in review["findings"] if f["source_agent"] == "security"]
    assert sec and sec[0]["severity"] in {"critical", "high"}
    assert review["recommendation"] == "request_changes"

@pytest.mark.asyncio
async def test_partial_failure_still_posts_review(monkeypatch):
    sys = MultiAgentCodeReviewSystem(TEST_CONFIG)
    async def boom(_): raise RuntimeError("perf down")
    monkeypatch.setattr(sys.agents["performance"], "analyze", boom)
    review = await sys.review_pr(TEST_PR, "acme/test")
    assert review["recommendation"] in {"approve", "comment", "request_changes"}
    assert "performance" in review["failed_agents"]

@pytest.mark.asyncio
async def test_budget_cap_enforced():
    tight = Config(budget_usd=0.001)
    sys = MultiAgentCodeReviewSystem(tight)
    review = await sys.review_pr(TEST_PR, "acme/test")
    assert review["cost_usd"] <= 0.01   # con holgura mínima
```

### Despliegue mínimo (GitHub webhook → serverless)

```python
# handler.py (AWS Lambda / Cloud Run)
async def handle_webhook(event):
    if event["action"] not in ("opened", "synchronize"): return
    pr = event["pull_request"]
    system = MultiAgentCodeReviewSystem(Config())
    await system.review_pr(pr["number"], pr["base"]["repo"]["full_name"])
```

## Errores comunes

- **Orquestador que analiza:** si tu supervisor consume 50% de los tokens, perdiste el beneficio del paralelismo. Mantenlo en routing + síntesis.
- **No limitar presupuesto:** un bug de prompt puede 10×ar el costo por review y no te enteras hasta fin de mes. `budget_usd` por review y alertas en Langfuse.
- **Workers con Opus "por si acaso":** 80% de las tareas de un worker especializado las resuelve Haiku con el mismo F1. Mide antes de pagar por Opus.
- **Formato inconsistente entre agentes:** si cada uno devuelve findings con schema distinto, la deduplicación falla. Fuerza `Finding` con Pydantic desde todos.
- **Ignorar fallos parciales:** si un agente timeoutea, el sistema debe seguir y marcar `failed_agents`, no caerse entero.
- **No versionar prompts:** cambiar el prompt del agente de seguridad sin registrar la versión rompe la comparación con baselines. Prompt-as-code (versionar en git).
- **Sin circuit breaker:** si Anthropic devuelve 500s por 3 minutos, bombardeas tu propia API con reintentos y gastas en tokens que nunca ves. CB con `recovery_s=60`.
- **Sin trace por agente:** sin LangSmith/Langfuse, cuando un veredicto es raro no sabes cuál agente lo originó.
- **Over-engineering al día 1:** empieza simple (3 agentes, timeout global, log). Agrega complejidad cuando duela, no antes.

## Resumen

- Un **sistema multi-agente de producción** se compone de: **supervisor ligero** (compone equipo + enruta) + **workers especializados** (Haiku) + **resolver de conflictos** + **sintetizador** + **capa de reliability**.
- La resolución de conflictos por **prioridad** (security > testing > performance) es simple y efectiva; alternativas: debate o árbitro con un modelo superior.
- La **capa de reliability** no es opcional: `timeouts`, `max_steps`, `budget_usd`, **circuit breakers por agente** y **dead-letter queues**. Sin ellas, el sistema no sobrevive una semana en producción.
- Usar **modelos distintos por rol** (Opus lead, Haiku workers) suele reducir costo 3-5× con la misma calidad.
- La **observabilidad por agente** (LangSmith, Langfuse, Arize Phoenix) es lo que convierte un MAS en un sistema debuggeable y confiable.
- El patrón "stay in your lane" (HAZ/NO HAGAS explícito) y los **schemas Pydantic compartidos** son los dos trucos que más duplicados eliminan.
- Empieza con 3 agentes, timeout y budget. Agrega complejidad (bus, consenso, work stealing) solo cuando el dolor lo justifique.
- Este blueprint es transferible: cambiando prompts y heurísticas de `compose_team` sirve para research, legal, soporte, debugging, triage y cualquier dominio que se beneficie de especialización + paralelismo.
