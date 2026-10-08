# Costos en Sistemas de IA: Right-Sizing, Spot y Monitoreo

## ¿Qué es?

**Cost optimization** en IA es el conjunto de prácticas para que la factura de infraestructura sea proporcional al valor que entregas, no al desperdicio que acumulas. En AI/ML esto es crítico porque **compute es 5-10× más caro que en software tradicional** por el requisito de GPUs.

Los drivers de costo típicos:

| Driver | Peso típico | Orden de magnitud |
|---|---|---|
| **Compute GPU (inferencia + entrenamiento)** | 50-80% | $3-32/h por instancia |
| **Compute CPU (API, workers, orquestación)** | 5-15% | $0.05-2/h |
| **Storage (datasets, checkpoints, logs)** | 5-15% | $0.023/GB-mes |
| **Egress de red** | 5-20% | $0.09/GB entre regiones |
| **Data labeling** | variable | $5-50/h humano |
| **APIs de terceros (OpenAI, Anthropic)** | variable | $0.25-75 / 1M tokens |

Un servicio de LLM a escala moderada quema fácil **$10,000-100,000/mes** solo en GPUs si no optimizas; el mismo workload bien optimizado baja a $2,000-20,000/mes.

## ¿Por qué importa?

Un ejemplo real: equipo despliega 20× A100 ($3/h cada una) para servir 10K QPS → **$1,440/día = $43,200/mes** solo compute. Un sprint de optimización típico (cuantización INT8 + continuous batching + routing cascade + spot para batch) suele bajar esto 50-70%. Son **$20K-30K/mes de ahorro recurrente**, cifra que paga sobradamente dos ingenieros senior.

Además, en modelos con **costos variables por request** (APIs tipo Anthropic/OpenAI), el margen del producto depende directamente del costo por request. Un chatbot que te cuesta $0.05/conversación es inviable si cobras $0.01; el mismo chatbot con prompt caching + modelo cascade a $0.003/conversación es un negocio sano.

Finalmente, **monitoreo por cliente** es clave para SaaS: sin él, un enterprise customer con comportamiento abusivo consume toda tu capacidad y margen sin que te enteres.

## ¿Cómo funciona?

### Right-sizing

Dimensionar instancias y réplicas según uso real, no según el peor caso imaginado. Pasos:

1. **Profiling.** Mide CPU, RAM, GPU util, VRAM, latencias por endpoint.
2. **Objetivo:** 60-80% de utilización sostenida (menos → sobredimensionado; más → riesgo en picos).
3. **Benchmark cost/req:** no mires `$/hora`, mira `$/1000 requests` o `$/1M tokens`.
4. **Right-size dev/stage:** entornos no-prod deben ser 10-100× más chicos.

### Spot / preemptible instances

Capacidad excedente del cloud con **descuento 60-90%** a cambio de posible interrupción con 2 minutos de aviso. Ideal para:

- **Entrenamiento** con checkpointing frecuente.
- **Batch inference** con retry logic.
- **Jobs de evaluación**, ETL, data processing.
- **Dev/stage** no críticos.

No ideal para: serving productivo síncrono con SLA estricto.

Ejemplo: training nocturno 6h × $50/h = $300/noche. Con spot (70% off) baja a $90/noche. Ahorro: **$6,300/mes** solo por checkbox + checkpointing.

### Reserved / Savings Plans

Compromiso de uso de 1 o 3 años → descuento 30-72%. Reserva solo el **baseline** (lo que estás seguro de consumir 24/7); usa on-demand para el delta variable y spot para batch.

```
Capacidad = Reserved (baseline) + On-demand (pico) + Spot (batch)
            └──  30% off  ──┘   └── precio lista ─┘  └── 70% off ─┘
```

### Autoscaling agresivo hacia abajo

El 95% del ahorro de autoscaling está en escalar **a cero** o cerca de cero en horas valle. Un servicio con 10 réplicas 24/7 cuesta igual que 10 réplicas en horas pico + 2 en valle si no scaleas abajo. Políticas útiles:

- `scaleDown.stabilizationWindowSeconds: 300-600` (más lento que scale-up).
- Scheduled scaling para patrones predecibles (noches/fines de semana).
- Scale-to-zero para servicios de bajo tráfico (Knative, KEDA, Modal).

### Model routing / cascade

Como en la lección anterior: la mayoría de queries no necesitan el modelo tope. Un router que mande 70% a Haiku, 25% a Sonnet, 5% a Opus baja el costo medio al 15-25% de usar siempre Opus.

### Cost monitoring por cliente / feature

Instrumenta cada request con `customer_id`, `feature`, `model`, `tokens_in`, `tokens_out`. Agrega en Prometheus/BigQuery para ver:

- **$/customer:** ¿quién es rentable, quién no?
- **$/feature:** ¿qué funcionalidad quema el margen?
- **$/request:** ¿subió esta semana? ¿por qué?
- **Alertas de budget:** aviso cuando un cliente/entorno excede N× su media.

### Storage y egress

- **Lifecycle policies:** mueve a S3 Glacier a los 30 días, borra logs crudos a los 90.
- **Compresión:** parquet + zstd baja storage 5-10× vs CSV.
- **Co-locación:** compute y datos en la **misma AZ** evita egress inter-AZ ($0.01-0.02/GB) y latencia.
- **Egress a internet caro:** usa CloudFront/Cloudflare como caché frontal.

### Checklist rápido

| Técnica | Ahorro típico | Esfuerzo |
|---|---|---|
| Apagar entornos dev de noche | 50-70% dev | Bajo |
| Spot para training/batch | 60-90% esos jobs | Bajo |
| Reserved para baseline | 30-50% baseline | Bajo |
| Autoscaling con scale-down agresivo | 20-40% serving | Medio |
| Cuantización INT8/INT4 | 2-4× throughput | Medio |
| Prompt caching + prefix caching | 50-80% prefill | Bajo |
| Model cascade / routing | 60-80% vs todo-top | Medio |
| Right-sizing con profiling | 20-40% | Medio |
| Co-locación + egress reduction | 5-20% red | Bajo |

## Ejemplo con código

### Cost tracker por request (middleware FastAPI)

```python
import time, json
from fastapi import FastAPI, Request
from prometheus_client import Counter, Histogram

TOKENS_IN  = Counter("llm_tokens_in_total",  "Prompt tokens",     ["customer", "model"])
TOKENS_OUT = Counter("llm_tokens_out_total", "Completion tokens", ["customer", "model"])
COST_USD   = Counter("llm_cost_usd_total",   "Dollar cost",       ["customer", "model"])
LAT        = Histogram("llm_latency_seconds","Latency",           ["customer", "model"])

# $ / 1M tokens (ejemplo, precios ilustrativos)
PRICING = {
    "claude-haiku-4-5":  {"in": 0.25, "out": 1.25},
    "claude-sonnet-4-5": {"in": 3.00, "out": 15.00},
    "claude-opus-4-5":   {"in": 15.00, "out": 75.00},
}

def record_usage(customer: str, model: str, tokens_in: int, tokens_out: int, dt: float):
    p = PRICING[model]
    cost = (tokens_in * p["in"] + tokens_out * p["out"]) / 1_000_000
    TOKENS_IN.labels(customer, model).inc(tokens_in)
    TOKENS_OUT.labels(customer, model).inc(tokens_out)
    COST_USD.labels(customer, model).inc(cost)
    LAT.labels(customer, model).observe(dt)
    return cost
```

### Alertas de budget (Prometheus Rule)

```yaml
# cost-alerts.yaml
groups:
- name: llm-cost
  interval: 1m
  rules:
  - alert: CustomerDailyBudgetExceeded
    expr: |
      sum by (customer) (increase(llm_cost_usd_total[1d]))
        > on(customer) group_left customer_daily_budget_usd
    for: 5m
    labels: {severity: warning}
    annotations:
      summary: "Cliente {{ $labels.customer }} excedio presupuesto diario"
  - alert: CostSpike
    expr: |
      sum(rate(llm_cost_usd_total[5m]))
        > 3 * sum(rate(llm_cost_usd_total[1h] offset 1h))
    for: 10m
    labels: {severity: critical}
    annotations:
      summary: "Costo 3x sobre el baseline horario"
```

### K8s HPA con scale-to-zero via KEDA

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: batch-inference-scaler
spec:
  scaleTargetRef:
    name: batch-inference
  minReplicaCount: 0           # a cero cuando no hay trabajo
  maxReplicaCount: 20
  cooldownPeriod: 300
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka:9092
      topic: inference-batch
      consumerGroup: workers
      lagThreshold: "10"
```

### Spot instances con checkpointing (training)

```python
# train.py — resiliente a interrupciones de spot
import torch, os, signal, time
from pathlib import Path

CKPT_DIR = Path("/mnt/efs/checkpoints")
CKPT_DIR.mkdir(parents=True, exist_ok=True)

def save_ckpt(model, optim, step):
    tmp = CKPT_DIR / f"ckpt-{step}.pt.tmp"
    torch.save({"model": model.state_dict(), "optim": optim.state_dict(), "step": step}, tmp)
    tmp.rename(CKPT_DIR / f"ckpt-{step}.pt")   # rename atomico

def load_latest(model, optim):
    ckpts = sorted(CKPT_DIR.glob("ckpt-*.pt"), key=lambda p: int(p.stem.split("-")[1]))
    if not ckpts: return 0
    data = torch.load(ckpts[-1])
    model.load_state_dict(data["model"])
    optim.load_state_dict(data["optim"])
    return data["step"]

# Handler para SIGTERM (AWS avisa 2 min antes de reclamar spot)
_should_stop = False
def handle_term(signum, frame):
    global _should_stop
    _should_stop = True
signal.signal(signal.SIGTERM, handle_term)

step = load_latest(model, optim)
while step < TOTAL_STEPS and not _should_stop:
    train_one_step(...)
    step += 1
    if step % 100 == 0:
        save_ckpt(model, optim, step)

if _should_stop:
    save_ckpt(model, optim, step)   # checkpoint final antes de morir
```

### Cost report automatizado (BigQuery)

```sql
-- Top 10 clientes por costo esta semana
SELECT
  customer_id,
  SUM(cost_usd)                                   AS cost_usd,
  SUM(tokens_in + tokens_out)                     AS total_tokens,
  COUNTIF(model = 'claude-opus-4-5') / COUNT(*)   AS pct_opus,
  SUM(cost_usd) / COUNT(*)                        AS avg_cost_per_req
FROM `prod.llm_usage`
WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY customer_id
ORDER BY cost_usd DESC
LIMIT 10;
```

## Errores comunes

- **No usar spot para batch.** Es el ahorro más grande por el menor esfuerzo (60-90% off con checkpointing simple).
- **Autoscaling solo scale-up.** Olvidar scale-down agresivo: pagas pico 24/7.
- **No monitorear costo por cliente.** Un enterprise abusivo consume 80% de tu capacidad; sin métricas no lo detectas hasta ver la factura.
- **Reservas excesivas.** Comprometerse 3 años con un workload que puede cambiar es un boomerang. Reserva solo lo seguro.
- **Dev y stage del mismo tamaño que prod.** Multiplicas la factura por 3 sin razón.
- **Egress inter-región/inter-AZ no visto.** Un pipeline multi-región "simple" puede añadir $5,000/mes solo en transferencias.
- **Logs no truncados.** Guardar prompts y completions completos en Elasticsearch/S3 por años → terabytes. Trunca después de 30-90 días.
- **No tag resources.** Sin `project`, `env`, `team` tags, la factura es ilegible y nadie puede imputar costos.
- **Optimizar prematuramente.** Dedicar 2 meses a bajar costo de un servicio con $500/mes de factura es destruir valor. Optimiza lo que pesa.
- **No usar prompt/prefix caching.** 50-80% del prefill en LLMs se puede evitar con un flag; pocos lo activan.

## Resumen

- Compute GPU es el **~70%** de la factura de un sistema de IA; es ahí donde está el ahorro.
- **Right-sizing** (profiling → 60-80% util) suele devolver 20-40% sin tocar código.
- **Spot/preemptible** ahorra 60-90% para training/batch con checkpointing.
- **Reserved + On-demand + Spot** es el combo óptimo: reserva el baseline, flexiona el pico, abarata el batch.
- **Autoscaling con scale-to-zero** (KEDA, Knative, Modal) elimina pago en horas valle.
- **Prompt caching + prefix caching + cascade** son wins baratos en LLMs.
- **Cost monitoring por cliente, feature y modelo** es obligatorio en SaaS: sin ello, pierdes margen sin saberlo.
- **Lifecycle policies** y **co-locación** reducen storage y egress silenciosos.
- Objetivo medible: **$ por 1000 requests** o **$ por 1M tokens**, no $ por hora de instancia.
- Herramientas: AWS Cost Explorer, GCP Billing, Kubecost, Vantage, OpenCost, Infracost, FOCUS spec.
