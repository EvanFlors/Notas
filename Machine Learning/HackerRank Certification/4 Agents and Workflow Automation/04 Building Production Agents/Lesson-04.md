# Testing, evaluación y despliegue seguro de agentes

## ¿Qué es?

Desplegar un servicio tradicional es un problema resuelto: tests → CI → staging → prod → rollback si algo peta. Desplegar un **agente** es diferente porque el software "pasa todos los tests" y aun así puede estar tomando malas decisiones en producción silenciosamente.

Un pipeline de despliegue de agentes combina:

- **Evaluation datasets:** conjuntos de inputs con respuestas correctas conocidas. Son los "unit tests" del comportamiento decisional.
- **Regression testing:** comparar el nuevo prompt/modelo/tool contra un baseline sobre el eval dataset.
- **Shadow mode:** correr la nueva versión en paralelo con la vieja sobre tráfico real, sin servir sus respuestas.
- **Progressive rollout (canary):** liberar al 5%, 10%, 25%, 50%, 100% con quality gates en cada paso.
- **Rollback rápido:** cuando una métrica cruza un umbral, volver atrás en segundos, respetando las ejecuciones en vuelo.

La idea central: en agentes **los cambios de prompt son cambios de código**. Una coma añadida al system prompt puede cambiar el comportamiento del 20% de las ejecuciones. Trátalos con la misma rigurosidad que un deploy de backend.

## ¿Por qué importa?

Los agentes rompen el supuesto fundamental del testing clásico: *"si pasa los tests, se comporta igual en prod"*. Razones:

1. **Non-determinismo del LLM.** El mismo input puede producir outputs distintos. Un test que pasa 9 de cada 10 veces no es "flaky", es la naturaleza del sistema.
2. **Sensibilidad al contexto.** Un cambio en una tool, un modelo nuevo, un prompt reordenado — todo puede cambiar el comportamiento sin señales claras.
3. **Fallas silenciosas.** No hay HTTP 500; hay "approve" cuando debió ser "request_changes". El sistema está "verde" y aun así roto.
4. **Costo de fallo distribuido.** Un bug no afecta un endpoint: afecta cada decisión que el agente tomó mientras estuvo mal.

Shadow mode + canary + eval datasets son la respuesta de la industria a esto. Es lo que Anthropic, OpenAI, GitHub (Copilot), Cursor y Replit usan internamente para shippear cambios de modelo o prompt sin romper usuarios.

## ¿Cómo funciona?

### 1. Eval dataset: el contrato de calidad

Un buen eval dataset tiene:

- **Ground truth verificado** (humanos revisaron la respuesta correcta).
- **Cobertura diversa**: categorías, dificultades, edge cases, incidentes históricos.
- **Etiquetas estructuradas**: `category`, `difficulty`, `must_find`, `must_not_find`.
- **Tamaño razonable**: 50-200 ejemplos. Calidad > cantidad.

Fuentes para construirlo:
- **Incidentes históricos**: cada vez que el agente se equivoca y un humano corrige, ese caso entra al eval set.
- **CVEs / OWASP** para seguridad.
- **Casos sintéticos** diseñados para probar comportamientos específicos.
- **Muestreo de producción** con verificación humana.

### 2. Scoring: más allá del match exacto

Para outputs libres, el `assert output == expected` no sirve. Técnicas comunes:

| Scorer | Cuándo |
|---|---|
| Exact match / regex | Verdicts cerrados (`approve` / `request_changes`) |
| Set inclusion (`must_find ⊆ findings`) | Hallazgos de seguridad, extracciones |
| Rubric-based LLM-as-judge | Respuestas abiertas (resumen, explicación) |
| Human review (sampling) | Dominios de alto riesgo |
| Code execution | Agentes de código: ¿pasa los tests el código generado? |

### 3. Shadow mode: pruebas con tráfico real sin riesgo

El nuevo agente procesa cada request real **en paralelo** con el actual, pero su respuesta se **loguea en vez de devolverse**. Permite:

- Medir *agreement rate* (¿coinciden las decisiones?).
- Detectar sesgos (¿la nueva versión aprueba más o menos?).
- Medir costo y latencia real.
- Encontrar categorías donde difieren.

Guía de interpretación:

| Observación | Lectura |
|---|---|
| Agreement > 95% | Comportamiento similar; probablemente seguro promover |
| Shadow más estricto | Más hallazgos — valida que no sean falsos positivos |
| Shadow más permisivo | ⚠️ puede estar perdiendo problemas reales |
| Agreement < 90% | Cambio significativo; revisar manualmente categorías |

### 4. Progressive rollout con quality gates

Nunca pases de 0% a 100%. Esquema típico:

```
Día 1:  5%   →  revisar métricas 24h
Día 2:  10%  →  agreement rate estable, no alertas
Día 3:  25%  →  calidad estable, costo dentro de banda
Día 4:  50%  →  monitoreo continuo
Día 5:  100% →  rollout completo
```

**Quality gates** entre cada paso: si alguna métrica cruza un umbral (error rate > 1%, quality < 0.80, costo > 150% baseline), se **pausa** el rollout; no se escala. Herramientas: feature flags (LaunchDarkly, Flagsmith, GrowthBook) o routing en el propio código del agente.

### 5. Rollback que respeta ejecuciones en vuelo

Un rollback tradicional cambia el binario y listo. En agentes, una ejecución puede estar a mitad de un loop de 15 iteraciones. Dos reglas:

- **Lock-in por ejecución:** cada run queda ligado a la versión con la que empezó; el rollback afecta solo a *nuevas* ejecuciones.
- **Invalidación de caches** si la versión vieja cacheaba decisiones de la nueva.

### 6. Prompt y tool changes = code changes

Un cambio de una línea en el system prompt puede:

- Hacer que el agente deje de llamar una tool crítica.
- Cambiar el tono de las respuestas.
- Alterar las tasas de aprobación.

Trata cada prompt como código: en Git, con PR, con eval en CI, con shadow test antes de merge. Lo mismo para cambios de schema de tool: añadir un campo que el agente no espera puede desorientar al LLM.

## Ejemplo con código

Pipeline de evaluación + shadow + canary rollout.

```python
import asyncio
import random
import hashlib
from dataclasses import dataclass, field

# ────────────────────────────────────────────────────────────
# 1. Eval dataset
# ────────────────────────────────────────────────────────────
EVAL_DATASET = [
    {
        "id": "eval-001",
        "pr": {"diff": "query = f\"SELECT * FROM u WHERE id={id}\""},
        "expected": {"verdict": "request_changes",
                     "must_find": ["sql_injection"]},
        "category": "security", "difficulty": "medium",
    },
    {
        "id": "eval-002",
        "pr": {"diff": "def add(a, b): return a + b"},
        "expected": {"verdict": "approve", "must_find": []},
        "category": "refactor", "difficulty": "easy",
    },
    # ... 50-200 casos ...
]

@dataclass
class EvalReport:
    passed: set[str] = field(default_factory=set)
    failed: set[str] = field(default_factory=set)
    by_category: dict = field(default_factory=dict)

async def evaluar(agent, dataset) -> EvalReport:
    report = EvalReport()
    for ex in dataset:
        actual = await agent.review(ex["pr"])
        verdict_ok = actual["verdict"] == ex["expected"]["verdict"]
        found = {f["type"] for f in actual.get("findings", [])}
        found_ok = set(ex["expected"]["must_find"]).issubset(found)
        if verdict_ok and found_ok:
            report.passed.add(ex["id"])
        else:
            report.failed.add(ex["id"])
        cat = ex["category"]
        report.by_category.setdefault(cat, {"pass": 0, "fail": 0})
        report.by_category[cat]["pass" if verdict_ok and found_ok else "fail"] += 1
    return report

# ────────────────────────────────────────────────────────────
# 2. Regression gate: no deploy si hay regresiones
# ────────────────────────────────────────────────────────────
def regression_gate(baseline: EvalReport, candidate: EvalReport) -> dict:
    regresiones = baseline.passed - candidate.passed
    mejoras     = candidate.passed - baseline.passed
    return {
        "regresiones": sorted(regresiones),
        "mejoras":     sorted(mejoras),
        "safe_to_deploy": len(regresiones) == 0,
    }

# ────────────────────────────────────────────────────────────
# 3. Shadow mode
# ────────────────────────────────────────────────────────────
class ShadowRouter:
    def __init__(self, prod_agent, shadow_agent, logger):
        self.prod, self.shadow, self.log = prod_agent, shadow_agent, logger

    async def review(self, pr):
        prod_result = await self.prod.review(pr)
        # Fire-and-forget: el shadow no bloquea ni afecta al usuario
        asyncio.create_task(self._shadow(pr, prod_result))
        return prod_result

    async def _shadow(self, pr, prod_result):
        try:
            shadow_result = await self.shadow.review(pr)
            agreement = (prod_result["verdict"] == shadow_result["verdict"])
            self.log("shadow_compare", pr_id=pr.get("id"),
                     prod=prod_result["verdict"],
                     shadow=shadow_result["verdict"],
                     agreement=agreement)
        except Exception as e:
            self.log("shadow_error", error=str(e))

# ────────────────────────────────────────────────────────────
# 4. Progressive rollout con gate
# ────────────────────────────────────────────────────────────
class ProgressiveRollout:
    def __init__(self, old, new):
        self.old, self.new = old, new
        self.new_pct = 0
        self.in_flight: dict[str, str] = {}   # review_id -> version

    def _bucket(self, pr_id: str) -> int:
        return int(hashlib.sha1(pr_id.encode()).hexdigest(), 16) % 100

    def select(self, pr_id: str):
        version = "new" if self._bucket(pr_id) < self.new_pct else "old"
        self.in_flight[pr_id] = version   # lock-in para rollback seguro
        return (self.new if version == "new" else self.old), version

    def set_pct(self, pct: int):
        self.new_pct = max(0, min(100, pct))

    def rollback(self, reason: str):
        print(f"[ROLLBACK] {reason}; nuevas ejecuciones usarán 'old'")
        self.new_pct = 0
        # Las ejecuciones en self.in_flight terminan con su versión original

# ────────────────────────────────────────────────────────────
# 5. Pipeline completo (lo que correrías en CI)
# ────────────────────────────────────────────────────────────
async def pipeline(agente_actual, agente_candidato):
    print("1) Baseline eval...")
    baseline = await evaluar(agente_actual, EVAL_DATASET)
    print(f"   baseline: {len(baseline.passed)}/{len(EVAL_DATASET)} pass")

    print("2) Candidate eval...")
    candidate = await evaluar(agente_candidato, EVAL_DATASET)
    print(f"   candidate: {len(candidate.passed)}/{len(EVAL_DATASET)} pass")

    print("3) Regression gate...")
    gate = regression_gate(baseline, candidate)
    if not gate["safe_to_deploy"]:
        print(f"   ❌ REGRESIONES: {gate['regresiones']}")
        return "BLOCKED"
    print(f"   ✅ sin regresiones; {len(gate['mejoras'])} mejoras")

    print("4) Shadow mode durante 24-48h (manual check en dashboard)")
    print("5) Canary: 5% → 10% → 25% → 50% → 100% con quality gates")
    return "READY"
```

### Checklist de un cambio de prompt antes de merge

```markdown
- [ ] Eval dataset con >= 50 casos corrido sobre el nuevo prompt
- [ ] Regression gate aprobado (0 regresiones vs baseline)
- [ ] Diff del prompt revisado en el PR
- [ ] Shadow mode 24-48h sobre tráfico real
- [ ] Agreement rate >= 95% o diferencias justificadas
- [ ] Costo p99 dentro del 150% del baseline
- [ ] Canary plan + umbrales de rollback definidos
```

### Testing de cambios en tools

Un cambio en el schema o en el output de una tool puede romper el razonamiento del agente incluso si la tool funciona perfectamente. Prueba en cuatro niveles:

1. **Unit test** de la tool en aislamiento.
2. **Contract test**: el output cumple el schema que el agente espera (campos, tipos).
3. **Integration test** con el agente: una ejecución end-to-end que use la tool.
4. **Shadow test** sobre tráfico real antes del rollout.

## Errores comunes

- **"Pasa los tests, deploy."** Los tests unitarios de código no capturan calidad de decisiones. Sin eval dataset, estás volando a ciegas.
- **Eval dataset sesgado.** Solo casos fáciles → tu agente parece perfecto hasta que ve producción. Incluye incidentes históricos y casos difíciles.
- **Cambiar prompt sin PR ni review.** El prompt vive en un `.yaml` que nadie revisa. El día que algo falla, Git blame apunta a un commit de "fix typos" que silenciosamente cambió el comportamiento.
- **Rollout directo a 100%.** Un canary de 24h detecta problemas que un deploy big-bang expone a todo el tráfico.
- **Shadow sin métricas accionables.** Loguear comparaciones sin dashboards ni alertas = guardar basura. Define *de antemano* las métricas que decidirán el rollout.
- **Rollback que corta ejecuciones en vuelo.** Un agente a mitad de iteración 7 de 15 que súbitamente cambia de versión produce resultados inconsistentes. Haz lock-in por `thread_id`.
- **Olvidar invalidar caches.** El agente nuevo escribe en el mismo cache que el viejo; tras un rollback, el viejo lee decisiones del nuevo. Namespace tu cache por versión.
- **Confundir "exitoso" con "correcto".** HTTP 200 con JSON válido no significa buena decisión. Mide calidad, no solo disponibilidad.
- **No tener un "freeze de prompts" en incidentes.** Durante un incidente, nadie debería estar cambiando prompts. Define reglas de change-freeze como con cualquier otro servicio crítico.

## Resumen

- Agentes requieren un pipeline de despliegue diferente: **eval datasets** + **regression tests** + **shadow mode** + **canary** + **rollback con lock-in**.
- Un **eval dataset** de 50-200 casos con ground truth es el contrato de calidad; aliméntalo con incidentes históricos.
- **Shadow mode** valida comportamiento con tráfico real sin exponer usuarios. Mide **agreement rate** y mira categorías con disenso.
- **Progressive rollout** (5 → 10 → 25 → 50 → 100%) con **quality gates** entre cada paso detecta problemas temprano.
- Un **cambio de prompt es un cambio de código**: PR, review, eval, shadow, canary. Igual que un deploy de backend.
- Los **cambios de tools** pueden romper el razonamiento aunque la tool funcione: valida contrato + integración.
- El **rollback** debe respetar ejecuciones en vuelo (lock-in por `thread_id`) e invalidar caches contaminados.
- "Pasa los tests" ≠ "funciona bien". Mide **calidad de decisiones**, no solo exit code.
- Herramientas útiles: feature flags (LaunchDarkly, GrowthBook) para rollout, LangSmith/Langfuse para dataset y eval, pytest + hypothesis para contract tests de tools.
