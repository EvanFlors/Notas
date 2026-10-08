# SLOs, SLIs y observabilidad para sistemas de IA

## ¿Qué es?

Un **SLI (Service Level Indicator)** es una medida cuantitativa de un aspecto del servicio: latencia p95, tasa de errores, costo por request, etc. Un **SLO (Service Level Objective)** es el objetivo numérico sobre un SLI (por ejemplo, "latencia p95 < 200ms en el 95% del tiempo"). Un **SLA (Service Level Agreement)** es el contrato legal con penalizaciones si no se cumplen los SLOs (por ejemplo, créditos a clientes).

En sistemas de IA, los SLIs tradicionales (latencia, errores, uptime) no bastan. Se agregan SLIs específicos:

- **Costo por request** o costo por 1000 tokens.
- **Calidad de predicción** (accuracy, F1, CTR, factualidad en LLMs).
- **Deriva de datos** (data drift) y de concepto (concept drift).
- **Confianza del modelo** y proporción de predicciones de baja confianza.

> **Fórmula central:** `SLO = 1 - (bad_events / total_events)`. El **error budget** = `(1 - SLO) × total_events` es la cantidad "permitida" de fallas en una ventana de tiempo. Cuando se agota, se congelan despliegues y se prioriza estabilidad.

### Las señales doradas extendidas para IA

El libro *Site Reliability Engineering* de Google definió las cuatro señales doradas. Para sistemas de IA agregamos dos más:

| Señal | Qué mide | SLI típico | Ejemplo de SLO |
|---|---|---|---|
| **Latencia** | Tiempo de respuesta | p50, p95, p99 | p95 < 200ms, 99% del tiempo |
| **Tráfico** | Volumen de requests | Requests/segundo, tokens/segundo | Soportar 5K RPS en pico |
| **Errores** | Fallos del servicio | Rate de 5xx, timeouts, OOM | Error rate < 1% |
| **Saturación** | Uso de recursos | GPU %, VRAM, cola de batching | GPU < 85% utilizado en p95 |
| **Costo** (IA) | $ por unidad servida | $/request, $/1K tokens | $0.001/request en p95 |
| **Calidad** (IA) | Qué tan correctas son las predicciones | Accuracy, F1, CTR, factualidad | F1 > 0.85 en ventana de 7 días |

### SLI vs SLO vs SLA

| Concepto | Qué es | Audiencia | Ejemplo |
|---|---|---|---|
| **SLI** | Métrica medible | Equipo técnico | Latencia p95 de inferencia |
| **SLO** | Objetivo interno sobre un SLI | Equipo + producto | p95 < 200ms, 99% del tiempo |
| **SLA** | Contrato con penalización | Clientes externos / legal | 99.5% uptime o crédito 10% |

Un SLA siempre debe ser **más laxo** que el SLO interno, para dar margen de maniobra.

## ¿Por qué importa?

Sin SLOs, cada incidente genera discusiones sin fin sobre si "el sistema está bien" o no. Con SLOs, la respuesta es objetiva: "estamos a 73% del error budget mensual, se puede desplegar".

El **error budget** convierte la confiabilidad en un recurso finito y gestionable:

- Si el error budget sobra, el equipo puede experimentar más agresivamente (nuevos modelos, cambios de infra).
- Si el error budget se está consumiendo rápido, se congelan despliegues y se prioriza estabilidad.
- Si se agota, hay un *post-mortem* obligatorio.

### Un ejemplo cuantitativo

Supongamos SLO = 99.5% de disponibilidad mensual. En un mes de 30 días (43,200 minutos):

- Error budget mensual = `(1 - 0.995) × 43,200 = 216 minutos ≈ 3.6 horas` de downtime permitidas.
- Si un incidente dura 2 horas, consumiste 55% del budget en un solo evento.
- Si quedan 10 días del mes y ya consumiste 90% del budget → **congelar despliegues**.

Para IA, el mismo cálculo aplica a calidad: si tu SLO es "accuracy > 90%" medido sobre 1M predicciones semanales, el budget es "100K predicciones incorrectas por semana".

## ¿Cómo funciona?

### Instrumentación: de código a métricas

Toda señal observable viene de **instrumentar** el código. Los tres pilares son:

1. **Métricas** (Prometheus, StatsD): números agregados por intervalo. Baratos de almacenar.
2. **Logs** (Loki, Elasticsearch, CloudWatch): eventos textuales. Caros a volumen.
3. **Traces** (Jaeger, Tempo, Honeycomb): seguimiento de un request a través de servicios.

Para sistemas de IA, agregar:

4. **Evaluaciones continuas**: muestras aleatorias de predicciones evaluadas offline (manualmente o con LLM-as-judge).
5. **Monitoreo de distribución**: histogramas de features de input y de outputs del modelo.

### Métricas Prometheus típicas en un endpoint de IA

| Métrica | Tipo | Para qué sirve |
|---|---|---|
| `inference_duration_seconds` | Histogram | Calcular p50/p95/p99 de latencia |
| `inference_requests_total` | Counter | Rate de tráfico |
| `inference_errors_total` | Counter | Error rate |
| `model_predictions_total{label}` | Counter | Distribución de predicciones (detectar drift) |
| `model_confidence` | Histogram | Distribución de confianza |
| `gpu_utilization_percent` | Gauge | Saturación de GPU |
| `inference_cost_usd_total` | Counter | Costo acumulado |
| `data_drift_score` | Gauge | Detección de drift (PSI, KL, KS) |

### Métodos para detectar drift

| Método | Qué detecta | Ventajas | Limitaciones |
|---|---|---|---|
| **KS test (Kolmogorov-Smirnov)** | Diferencias en features continuos | Simple, sin asunción paramétrica | Univariado |
| **PSI (Population Stability Index)** | Cambios en features categóricos o binned | Estándar en finanzas | Requiere binning |
| **KL divergence** | Diferencia entre distribuciones | Teóricamente sólido | Sensible a bins vacíos |
| **Chi-cuadrado** | Features categóricos | Simple | Solo categóricos |
| **Model-based (classifier two-sample test)** | Drift multivariado complejo | Captura interacciones | Caro de entrenar |

Herramientas que automatizan esto: **Evidently**, **Arize**, **WhyLabs**, **Fiddler**, **NannyML**.

### Observabilidad: logs, métricas y traces

| Pilar | Cardinalidad | Costo | Casos de uso |
|---|---|---|---|
| Métricas | Baja (agregadas) | Barato | Dashboards, alerting, SLOs |
| Logs | Alta (por evento) | Caro | Debugging post-mortem |
| Traces | Media (sampleado) | Medio | Latencia distribuida, dependencias |

Un error común es confiar solo en logs. Para alerting usa métricas; para debugging usa logs y traces.

## Ejemplo con código

### Instrumentar un endpoint con Prometheus

```python
# pip install prometheus-client fastapi
from fastapi import FastAPI, Request
from prometheus_client import Counter, Histogram, Gauge, make_asgi_app
import time
import numpy as np

app = FastAPI()

# ============================================================
# Definición de métricas
# ============================================================
REQUESTS = Counter(
    "inference_requests_total",
    "Total de requests de inferencia",
    ["model_version", "endpoint"],
)
ERRORS = Counter(
    "inference_errors_total",
    "Total de errores",
    ["model_version", "endpoint", "error_type"],
)
LATENCY = Histogram(
    "inference_duration_seconds",
    "Tiempo de inferencia",
    ["model_version", "endpoint"],
    buckets=[0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0],
)
CONFIDENCE = Histogram(
    "model_confidence",
    "Distribución de confianza del modelo",
    ["model_version"],
    buckets=[0.1, 0.3, 0.5, 0.7, 0.9, 0.95, 0.99],
)
DRIFT_SCORE = Gauge(
    "data_drift_score",
    "Score de drift respecto a baseline",
    ["feature"],
)
COST = Counter(
    "inference_cost_usd_total",
    "Costo acumulado en USD",
    ["model", "tenant"],
)

# Exponer /metrics
app.mount("/metrics", make_asgi_app())


# ============================================================
# Endpoint instrumentado
# ============================================================
MODEL_VERSION = "v2.3.1"

@app.post("/predict")
async def predict(request: Request):
    start = time.perf_counter()
    REQUESTS.labels(MODEL_VERSION, "/predict").inc()
    try:
        body = await request.json()
        features = np.array(body["features"])

        # Inferencia real
        prediction, confidence = run_model(features)

        CONFIDENCE.labels(MODEL_VERSION).observe(confidence)
        COST.labels("recommender", body.get("tenant", "unknown")).inc(0.0002)

        return {"prediction": prediction, "confidence": confidence,
                "model_version": MODEL_VERSION}
    except ValueError as e:
        ERRORS.labels(MODEL_VERSION, "/predict", "invalid_input").inc()
        raise
    except Exception as e:
        ERRORS.labels(MODEL_VERSION, "/predict", "internal").inc()
        raise
    finally:
        LATENCY.labels(MODEL_VERSION, "/predict").observe(
            time.perf_counter() - start
        )


def run_model(features):
    # Simulación
    return int(features.sum() > 0), float(np.random.uniform(0.5, 0.99))
```

### Reglas de Prometheus para SLOs

```yaml
# prometheus-slo-rules.yaml
groups:
  - name: ai_inference_slos
    interval: 30s
    rules:
      # ------------------------------------------------------
      # SLI: latencia p95
      # ------------------------------------------------------
      - record: sli:inference_latency_p95:5m
        expr: |
          histogram_quantile(0.95,
            sum(rate(inference_duration_seconds_bucket[5m])) by (le)
          )

      # ------------------------------------------------------
      # SLI: tasa de errores
      # ------------------------------------------------------
      - record: sli:error_rate:5m
        expr: |
          sum(rate(inference_errors_total[5m]))
          / sum(rate(inference_requests_total[5m]))

      # ------------------------------------------------------
      # Error budget consumido (ventana de 30 días)
      # SLO: 99% success rate
      # ------------------------------------------------------
      - record: slo:error_budget_remaining:30d
        expr: |
          1 - (
            sum(increase(inference_errors_total[30d]))
            /
            (sum(increase(inference_requests_total[30d])) * (1 - 0.99))
          )

      # ------------------------------------------------------
      # Alertas basadas en burn rate (SRE workbook)
      # ------------------------------------------------------
      - alert: ErrorBudgetBurnFast
        # Consumir 2% del budget en 1 hora = quemando 14x más rápido
        expr: |
          (
            sum(rate(inference_errors_total[1h]))
            / sum(rate(inference_requests_total[1h]))
          ) > (14.4 * 0.01)
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Error budget quemándose rápido"
          runbook: "https://runbooks.internal/ai/error-budget"

      - alert: ErrorBudgetBurnSlow
        expr: |
          (
            sum(rate(inference_errors_total[6h]))
            / sum(rate(inference_requests_total[6h]))
          ) > (6 * 0.01)
        for: 15m
        labels:
          severity: warning
```

### Detección de drift con Evidently

```python
# pip install evidently
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, TargetDriftPreset
import pandas as pd

def check_drift(reference: pd.DataFrame, current: pd.DataFrame) -> dict:
    report = Report(metrics=[
        DataDriftPreset(),
        TargetDriftPreset(),
    ])
    report.run(reference_data=reference, current_data=current)

    result = report.as_dict()
    drifted = [
        m["result"]["column_name"]
        for m in result["metrics"]
        if m.get("result", {}).get("drift_detected", False)
    ]
    return {
        "drift_detected": len(drifted) > 0,
        "drifted_features": drifted,
        "report": report,
    }


# Uso diario
reference = pd.read_parquet("s3://ml/baselines/features_training.parquet")
current = pd.read_parquet(f"s3://ml/features/{today}.parquet")

result = check_drift(reference, current)
if result["drift_detected"]:
    # Dispara alerta y actualiza gauge en Prometheus
    for feat in result["drifted_features"]:
        DRIFT_SCORE.labels(feat).set(1.0)
```

### Dashboard de Grafana (snippet)

```json
{
  "panels": [
    {
      "title": "Latencia p95 (SLO: < 200ms)",
      "targets": [{"expr": "sli:inference_latency_p95:5m"}],
      "thresholds": [{"value": 0.2, "color": "red"}]
    },
    {
      "title": "Error budget restante (30d)",
      "targets": [{"expr": "slo:error_budget_remaining:30d"}],
      "thresholds": [
        {"value": 0.1, "color": "red"},
        {"value": 0.5, "color": "yellow"}
      ]
    },
    {
      "title": "Costo acumulado por tenant",
      "targets": [{"expr": "sum by (tenant) (inference_cost_usd_total)"}]
    }
  ]
}
```

## Errores comunes

- **No definir SLOs antes de desplegar.** Sin umbral acordado, cualquier incidente genera debate subjetivo. Define SLOs con producto antes del lanzamiento.
- **SLOs demasiado estrictos.** Prometer 99.999% ("cinco nueves") sin la infra para sostenerlo lleva a agotar el error budget en días y a bloquear innovación.
- **No distinguir SLI de SLO de SLA.** Un SLA es un contrato con penalización; un SLO es un objetivo interno. El SLO siempre debe ser más estricto que el SLA.
- **Alertar sobre causas en vez de síntomas.** Alertar sobre "CPU > 90%" en lugar de "latencia p95 > SLO" genera ruido: a los usuarios no les importa la CPU.
- **Burn rate alerts mal calibradas.** Alertar sobre error rate instantáneo genera false positives. Usa multi-window multi-burn-rate según el SRE Workbook de Google.
- **Monitorear solo infraestructura.** CPU/RAM/uptime no detectan degradación de calidad. Agrega monitoreo de distribución de predicciones y de drift.
- **No baseline para drift.** Comparar contra "la semana pasada" oculta drift gradual. Compara siempre contra el dataset de training.
- **Logs sin cardinalidad controlada.** Loggear objetos JSON con millones de valores únicos revienta el presupuesto de observabilidad en días.
- **No instrumentar costo.** Sin tracking de `$/request` y `$/tenant`, descubres el problema cuando llega la factura.
- **Dashboards sin thresholds visibles.** Un panel sin línea de SLO no comunica si estás bien o mal. Pinta siempre el objetivo.

## Contexto y referencias

- **Google SRE Book y SRE Workbook** (sre.google): origen de las señales doradas, SLIs/SLOs, error budgets y multi-window alerting.
- **Prometheus & Grafana docs**: stack de observabilidad open source más usado.
- **Evidently (evidentlyai.com), Arize, WhyLabs, Fiddler, NannyML:** herramientas de monitoreo ML.
- **OpenTelemetry (opentelemetry.io):** estándar emergente para instrumentación cross-lenguaje.
- **"Implementing Service Level Objectives"** (Alex Hidalgo, O'Reilly): libro práctico sobre SLOs.

## Resumen

- **SLI** mide, **SLO** fija el objetivo, **SLA** es el contrato. SLO siempre más estricto que SLA.
- Fórmula central: `SLO = 1 - (bad / total)`. **Error budget** = `(1 - SLO) × total`.
- Las **señales doradas** (latencia, tráfico, errores, saturación) se extienden en IA con **costo** y **calidad**.
- La observabilidad descansa en **métricas, logs y traces**, más **evaluaciones continuas** y **monitoreo de distribución** en IA.
- Prometheus + Grafana es el stack open source estándar; Evidently/Arize/WhyLabs/Fiddler cubren el monitoreo específico de ML.
- Detectar drift usa KS, PSI, KL o classifier-based tests, siempre contra un **baseline del dataset de training**.
- Las alertas deben basarse en **síntomas que afectan al usuario** (latencia, error rate, calidad), no en causas internas (CPU, RAM).
- **Multi-window multi-burn-rate** alerting (SRE Workbook) reduce ruido y detecta tanto incidentes rápidos como lentos.
- Instrumenta **costo** desde el día uno, atribuido por modelo, endpoint, feature y cliente.
- Sin SLOs, la discusión sobre "si el sistema está bien" nunca termina; con SLOs, se vuelve objetiva y accionable.
