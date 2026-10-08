# Deployment Decision Framework

## ¿Qué es?

Un **decision framework de deployment** es un conjunto estructurado de criterios y árboles de decisión que convierte el "¿cómo despliego este modelo?" de una conversación subjetiva a un procedimiento repetible. Reemplaza el "lo que me parece bien" con **tabla + umbrales + reglas**.

### Factores de decisión

Cinco ejes se evalúan antes de elegir pattern:

1. **Riesgo del fallo:** ¿cuánto cuesta un bug? Spam de recomendaciones malas vs. aprobar transacciones fraudulentas vs. diagnóstico médico incorrecto están en órdenes de magnitud distintos.
2. **Volumen de tráfico:** 10 req/día vs. 100k req/s cambia radicalmente la viabilidad del canary.
3. **Presupuesto de infra:** blue-green dobla costo durante deploy; shadow dobla costo por días.
4. **Madurez operacional:** ¿tienes Prometheus, Grafana, alertas, oncall rotativo, runbook? Si no, patterns sofisticados fallan por falta de observabilidad.
5. **Características del modelo:** determinístico vs. estocástico, métrica clara vs. subjetiva, latencia-sensitivo vs. offline.

## ¿Por qué importa?

Decisiones ad-hoc generan **inconsistencia entre equipos**: equipo A despliega con shadow completo mientras equipo B hace push a 100% directo. Cuando B causa un incidente, el blame se dispersa en lugar de atribuirlo al proceso.

Un framework explícito:

- **Reduce discusiones en revisiones:** la tabla responde "¿canary o blue-green?" sin debate.
- **Entrena a nuevos ingenieros** sin requerir mentorship 1-a-1 para cada deploy.
- **Hace auditable** el proceso (requisito en finanzas, salud, defensa).
- **Enfoca el error budget** en los riesgos reales, no en todos por igual.
- **Separa decisión técnica de decisión política:** si management quiere "ir rápido", el framework muestra el costo exacto en términos de riesgo.

El libro **Google SRE** y **Accelerate** (Nicole Forsgren) demuestran empíricamente que las organizaciones top performers deployan 200x más seguido con 2600x menos tiempo de recuperación — todo por tener procesos explícitos.

## ¿Cómo funciona?

### Árbol de decisión por tipo de sistema

```
¿Qué tan grave es un bug en producción?
│
├── CATASTRÓFICO (vidas, dinero >$1M, legal)
│   └── Shadow (1-4 semanas)
│       └── Canary muy lento (1% → 5% → 10% → 25% → 50% → 100%, 1 día por paso)
│           └── Monitoreo humano + automated analysis
│
├── ALTO (incidente P0, SLO budget quemado, revenue >$10k)
│   └── Shadow corto (3-7 días) opcional
│       └── Canary estándar (5% → 25% → 50% → 100%, 1-4h por paso)
│           └── Automated canary analysis (Flagger)
│
├── MEDIO (UX degradada, incidente P1-P2)
│   └── Canary rápido (10% → 50% → 100%, 15-60 min por paso)
│       └── Alertas automáticas + rollback manual
│
└── BAJO (feature interna, pocos usuarios, reversible fácil)
    └── Blue-Green o rolling update directo
        └── Smoke tests post-deploy
```

### Matriz: riesgo × tráfico → pattern

| | Tráfico bajo (<1k req/día) | Tráfico medio (1k-1M req/día) | Tráfico alto (>1M req/día) |
|---|---|---|---|
| **Riesgo bajo** | Rolling update | Rolling update + alertas | Blue-Green |
| **Riesgo medio** | Canary 50% manual | Canary automatizado (Flagger) | Canary automatizado + feature flag |
| **Riesgo alto** | Shadow + canary lento manual | Shadow + canary automatizado | Shadow + canary multi-región |
| **Riesgo catastrófico** | Shadow extendido + aprobación humana | Shadow + canary celular | Shadow + canary celular por región |

### Tabla comparativa de patterns con criterios de selección

| Criterio | Rolling | Blue-Green | Canary | Shadow | A/B |
|---|---|---|---|---|---|
| Tiempo deploy | 2-10 min | 2-5 min | horas-días | días-semanas | semanas |
| Costo infra extra | 0 | 1x | 0.05-0.5x | 1x | 0.05-0.5x |
| Riesgo usuario durante deploy | Bajo | Medio (si falla validación) | Muy bajo | Cero | Bajo |
| Rollback | kubectl rollout undo | Swap selector | Reset % | N/A | Reset % |
| Requiere observabilidad | Básica | Básica | Alta | Muy alta | Alta |
| Mide métricas de negocio | No | No | Opcional | Offline | Sí |

### Pitfalls comunes

- **Training-serving skew:** las features en training se calcularon con un pipeline Spark offline; en serving las calcula un microservicio distinto. Pequeñas diferencias (encoding, defaults, orden de ops) generan degradación silenciosa. **Mitigación:** usar el mismo código (feature store compartido, Feast/Tecton).
- **Monitoreo insuficiente:** deploy sin métricas pre-registradas. "Lo veremos si falla" → no se detecta. **Mitigación:** definir y crear dashboards + alertas **antes** de iniciar el rollout.
- **Rollout agresivo:** 5% → 100% en 10 minutos. No da tiempo a que métricas afectadas por latencia (conversiones, abandono) se materialicen. **Mitigación:** pasos de al menos 30-60 min para sistemas user-facing.
- **No rollback plan:** se asume que "no va a fallar". **Mitigación:** rollback test en staging cada sprint; runbook explícito.
- **No capacity planning:** v2 requiere 2x memoria; descubres en rollout a 50%. **Mitigación:** load test en staging con tráfico realista antes de prod.
- **Deploy en horario pico / viernes PM:** si falla, el impacto es máximo y el equipo mínimo. **Mitigación:** deploy windows (martes-jueves, 10am-2pm) salvo hotfixes P0.
- **Falta de automatización:** 23 pasos manuales → humano se equivoca en el paso 17. **Mitigación:** pipeline CI/CD + GitOps.
- **No business metrics:** error rate OK, latencia OK, pero el nuevo modelo recomienda productos no comprables → revenue cae 15%. **Mitigación:** alertar sobre revenue, conversiones, engagement.
- **Falta de blameless post-mortems:** mismos errores se repiten porque nadie documenta ni comparte. **Mitigación:** retro obligatorio para todo incidente >P2.

### Best practices (checklist general)

Pre-deploy:
- [ ] Modelo validado en staging con tráfico shadow al menos 24h.
- [ ] Load test en staging a 2x el peak esperado.
- [ ] Métricas y alertas creadas (error rate, latency p50/p99, business metrics).
- [ ] Runbook de rollback escrito y verificado por un segundo humano.
- [ ] Capacity plan (replicas, GPU, memoria) confirmado.
- [ ] Dependencies verificadas (feature store, auth, logging).

Durante deploy:
- [ ] Deploy en horario de bajo tráfico.
- [ ] Oncall notificado y disponible.
- [ ] Dashboard de métricas abierto en pantalla.
- [ ] Avanzar al siguiente % solo tras significancia estadística.

Post-deploy:
- [ ] Monitorear 24-48h a 100% antes de cerrar el ticket.
- [ ] Retro (incluso si fue exitoso).
- [ ] Decommissioning de v1 (liberar recursos, limpiar feature flags).
- [ ] Documentar lecciones aprendidas en el runbook.

### Fórmulas

**Error budget burn rate (Google SRE):**

```
burn_rate = (errores_en_ventana / budget_para_ventana)
# Alertas típicas:
#   burn > 14.4x por 1h  → page (quemarías mes en 2d)
#   burn > 6x por 6h     → page
#   burn > 3x por 24h    → ticket
#   burn > 1x por 3d     → investigar tendencia
```

**Criterio de promoción canary:**

```python
def promote(v1_metrics, v2_metrics, min_n=10_000):
    if v2_metrics["n"] < min_n:
        return "wait"
    if v2_metrics["error_rate"] > v1_metrics["error_rate"] * 1.1:
        return "rollback"
    if v2_metrics["p99_latency"] > v1_metrics["p99_latency"] * 1.2:
        return "rollback"
    if not statistically_significant(v1_metrics, v2_metrics, alpha=0.05):
        return "wait"
    return "promote"
```

**Sample size necesario para detectar diferencia:**

```
n ≈ 16 × p × (1 - p) / delta²
# p = baseline rate (ej. 0.01 = 1% error)
# delta = diferencia mínima detectable (ej. 0.002 = 0.2% absoluto)
# Ejemplo: n = 16 × 0.01 × 0.99 / 0.002² ≈ 39,600 requests
```

## Ejemplo con código

### Decision tree en Python

```python
# deployment_advisor.py
from dataclasses import dataclass
from enum import Enum

class Pattern(Enum):
    ROLLING = "rolling"
    BLUE_GREEN = "blue-green"
    CANARY_MANUAL = "canary-manual"
    CANARY_AUTO = "canary-automated"
    SHADOW_CANARY = "shadow + canary"
    SHADOW_CELULAR = "shadow + canary celular por región"

@dataclass
class Context:
    risk: str                  # low | medium | high | catastrophic
    daily_requests: int
    cost_sensitive: bool
    has_observability: bool
    has_feature_store: bool
    model_type: str            # realtime | batch | streaming

def recommend(ctx: Context) -> tuple[Pattern, list[str]]:
    reasons = []
    if not ctx.has_observability:
        reasons.append("Observabilidad insuficiente: usar pattern simple hasta remediar.")
        return Pattern.ROLLING, reasons

    if ctx.risk == "catastrophic":
        reasons.append("Riesgo catastrófico exige shadow extendido.")
        if ctx.daily_requests > 1_000_000:
            return Pattern.SHADOW_CELULAR, reasons
        return Pattern.SHADOW_CANARY, reasons

    if ctx.risk == "high":
        reasons.append("Riesgo alto: shadow + canary automatizado.")
        return Pattern.SHADOW_CANARY, reasons

    if ctx.risk == "medium":
        if ctx.daily_requests > 100_000:
            return Pattern.CANARY_AUTO, reasons
        return Pattern.CANARY_MANUAL, reasons

    # risk == low
    if ctx.daily_requests > 1_000_000 and not ctx.cost_sensitive:
        return Pattern.BLUE_GREEN, reasons
    return Pattern.ROLLING, reasons

# Uso
ctx = Context(risk="high", daily_requests=500_000, cost_sensitive=False,
              has_observability=True, has_feature_store=True, model_type="realtime")
pattern, why = recommend(ctx)
print(f"Recomendación: {pattern.value}\nRazones: {why}")
```

### Feature flag wrapper para modelos

```python
# model_router.py
import ldclient, httpx
from ldclient import Context

class ModelRouter:
    def __init__(self, flag_key: str, routes: dict[str, str], default: str):
        self.flag_key = flag_key
        self.routes = routes            # {"v1": "http://sentiment-v1", ...}
        self.default = default
        self.ld = ldclient.get()
        self.client = httpx.AsyncClient(timeout=2.0,
                                        limits=httpx.Limits(max_connections=200))

    async def predict(self, user_id: str, payload: dict) -> dict:
        ctx = Context.builder(user_id).kind("user").build()
        version = self.ld.variation(self.flag_key, ctx, self.default)
        url = self.routes.get(version, self.routes[self.default])
        resp = await self.client.post(f"{url}/predict", json=payload)
        resp.raise_for_status()
        out = resp.json()
        out["served_version"] = version
        return out
```

### Pre-deploy validation con pytest

```python
# tests/test_pre_deploy.py
import pytest, httpx

STAGING = "https://sentiment-staging.ml.corp"
GOLDEN = [
    ("I love this product", "positive", 0.9),
    ("Terrible service, awful", "negative", 0.85),
    ("It is okay I guess", "neutral", 0.6),
    # ... 100+ casos de golden set
]

@pytest.mark.parametrize("text,expected,min_conf", GOLDEN)
def test_golden_set(text, expected, min_conf):
    r = httpx.post(f"{STAGING}/predict", json={"text": text}, timeout=5).json()
    assert r["label"] == expected, f"got {r['label']} for '{text}'"
    assert r["confidence"] >= min_conf

def test_latency_p99():
    import time, statistics
    latencies = []
    for _ in range(200):
        t0 = time.perf_counter()
        httpx.post(f"{STAGING}/predict", json={"text": "test"}, timeout=5)
        latencies.append((time.perf_counter() - t0) * 1000)
    p99 = statistics.quantiles(latencies, n=100)[98]
    assert p99 < 300, f"p99 {p99:.0f}ms excede 300ms"

def test_schema_stability():
    r = httpx.post(f"{STAGING}/predict", json={"text": "x"}).json()
    assert set(r.keys()) >= {"label", "confidence", "model_version"}
```

Falla el pipeline si cualquier assert no pasa → rollout bloqueado.

### Rollback script Bash

```bash
#!/usr/bin/env bash
# rollback.sh — invocable por humano o automation
set -euo pipefail

SERVICE="${1:?usage: rollback.sh <service>}"
NS="${2:-ml-prod}"
STRATEGY="${3:-helm}"   # helm | argo | git

case "$STRATEGY" in
  helm)
    helm history "$SERVICE" -n "$NS" | tail -5
    helm rollback "$SERVICE" -n "$NS"
    ;;
  argo)
    kubectl argo rollouts abort "$SERVICE" -n "$NS"
    kubectl argo rollouts undo "$SERVICE" -n "$NS"
    ;;
  git)
    LAST_GOOD=$(git log --oneline -n 20 -- values.prod.yaml | sed -n '2p' | awk '{print $1}')
    git revert --no-edit "$LAST_GOOD"
    git push origin main
    echo "ArgoCD aplicará revert en ~1 min"
    ;;
esac

# Notificar
curl -X POST "$SLACK_WEBHOOK" -d "{\"text\":\":arrows_counterclockwise: Rollback de $SERVICE ejecutado\"}"
```

## Errores comunes

- **"Deploy ya, veremos si funciona."** El clásico. Sin criterios predefinidos se decide bajo presión → errores.
- **No tener shadow para sistemas críticos.** Fraude/salud sin validación en producción = ruleta rusa.
- **Checklist muerto en Confluence.** Si no está automatizado en el pipeline, se saltea.
- **Métricas solo técnicas.** Sin conversion/revenue, un modelo "sano" puede destruir negocio.
- **Rollback complejo o no probado.** El runbook de 15 pasos nunca ejecutado en producción falla la primera vez.
- **Deploys bloqueados por burocracia.** El extremo opuesto: 3 semanas de approval para un cambio trivial → equipos agrupan cambios → deploys gigantes → riesgo mayor.
- **Error budget ignorado.** Equipos siguen deployando con el budget al 150% quemado → SLO perdido → cliente perdido.
- **Sin ownership claro.** "¿Quién monitorea el canary?" → nadie → degradación pasa desapercibida.
- **Feature flags que nunca se eliminan.** 300 flags activas = complejidad combinatoria imposible de testear.
- **Deploy el viernes a las 5pm.** Si falla, equipo oncall sufre el fin de semana. "Read-only Friday" es una regla sana.

## Contexto industrial

- **Google SRE book** (gratis en sre.google/books): formaliza error budget, SLO, blameless post-mortems. Lectura obligatoria.
- **DORA / Accelerate (Nicole Forsgren):** las 4 métricas clave de equipos top (deploy frequency, lead time, MTTR, change failure rate).
- **Netflix Spinnaker + Kayenta:** stack open-source de progressive delivery, usado hoy por centenas de empresas (incluyendo Target, American Express).
- **Meta "deploy windows":** solo deployan en ventanas específicas; hotfixes requieren approval multi-nivel.
- **Stripe "deploy anytime":** más de 1000 deploys/día; posible por canary agresivo + feature flags + observabilidad extrema.
- **Anthropic/OpenAI:** combinan evals pre-deploy (safety, capability), canary a cohortes internas, rollout gradual a público, con **model deprecation policies** publicadas.
- **AWS/GCP/Azure:** deployan upgrades de servicios cell-by-cell (aislamiento geográfico), nunca globally simultáneo.
- **Chaos engineering (Netflix Chaos Monkey, Gremlin):** inyecta fallos deliberadamente para validar que los rollbacks y degradaciones funcionen.

Herramientas: **Spinnaker**, **ArgoCD**, **Argo Rollouts**, **Flagger**, **LaunchDarkly**, **Unleash**, **Statsig**, **Harness**, **CodeFresh**, **Octopus Deploy**, **PagerDuty**, **Grafana**, **Prometheus**, **Datadog**, **Honeycomb**.

## Resumen

- Un **decision framework** convierte deployment de arte a ingeniería: criterios explícitos, árboles de decisión, umbrales medibles.
- Cinco ejes de decisión: **riesgo, volumen, costo, madurez operacional, características del modelo**.
- La **matriz riesgo × tráfico** da una recomendación de pattern directa: desde rolling update para low-risk/low-traffic hasta shadow + canary celular para catastrophic/high-traffic.
- Los **pitfalls más caros**: training-serving skew, monitoreo insuficiente, rollout agresivo, no rollback plan, no business metrics, deploy en viernes PM.
- **Best practices**: checklist automatizado, deploy windows, oncall activo, business metrics, blameless post-mortems.
- **Error budget** (SRE) formaliza cuánto riesgo aceptas por período; `burn_rate` dispara alertas y pausa deploys.
- **Automation first**: pipeline CI/CD + GitOps + Flagger/Argo Rollouts > procedimientos manuales.
- **Default a gradual rollout + rollback plan**, incluso cuando "estás seguro". La seguridad viene de los sistemas, no de la confianza.
- Métricas DORA (deploy frequency, lead time, MTTR, change failure rate) miden la salud del proceso.
- Cultura: aprender de cada incidente, no castigar errores, mejorar el **sistema** no al individuo.
