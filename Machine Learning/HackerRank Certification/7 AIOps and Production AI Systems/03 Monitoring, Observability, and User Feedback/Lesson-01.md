# Fundamentos del Monitoreo de Sistemas de IA

## ¿Qué es?

El **monitoreo de sistemas de IA** es la práctica continua de observar, medir y alertar sobre el comportamiento de modelos de machine learning y LLMs en producción. A diferencia del monitoreo tradicional de software (que se centra en si el servicio responde), el monitoreo de IA debe responder una pregunta más sutil: **¿el modelo sigue siendo útil y correcto?**

Un servicio puede estar devolviendo respuestas HTTP 200 con latencia perfecta y, aun así, estar generando predicciones silenciosamente erróneas, respuestas alucinadas o recomendaciones irrelevantes. Esa clase de fallo —el **fallo silencioso del modelo**— es la razón por la que el monitoreo de IA es una disciplina propia.

### Las tres capas que se monitorean

1. **Infraestructura**: CPU, GPU, memoria, red, disco, saturación de colas.
2. **Aplicación / Servicio**: latencia p50/p95/p99, throughput (RPS), tasa de errores, tamaño de payloads.
3. **Modelo**: distribución de inputs, distribución de outputs, confianza, calidad de predicción, costo por request, uso de tokens, tasa de alucinación.

Un sistema de IA en producción está sano **solo si las tres capas están sanas**. Las tres pueden fallar de forma independiente.

## ¿Por qué importa?

### Los modelos degradan en silencio

El código no se oxida solo, pero los modelos sí. El mundo cambia: cambian los usuarios, los patrones de búsqueda, el inventario, los precios, las modas lingüísticas. Un modelo entrenado hace seis meses puede estar sirviendo predicciones basadas en una realidad que ya no existe. Esto se llama **data drift** (deriva de datos) o **concept drift** (deriva de concepto) y es el principal enemigo de un modelo en producción.

### Los LLMs introducen fallos nuevos

Los LLMs añaden categorías de fallo que no existían en ML clásico:

- **Alucinaciones** (texto fluido pero factualmente incorrecto).
- **Degradación por cambios upstream** (el proveedor actualiza el modelo y el comportamiento cambia sin aviso).
- **Explosión de costos** (un prompt mal diseñado consume 10x más tokens).
- **Prompt injection** y abuso de usuarios.
- **Latencia variable** por streaming y por longitud de respuesta.

### Costo real del no-monitoreo

| Fallo | Impacto típico |
|---|---|
| Modelo de recomendación degradado | Caída de CTR del 10-30%, pérdida de ingresos directa |
| LLM con alucinaciones no detectadas | Daño reputacional, pérdida de confianza del usuario |
| Fuga de costos por tokens | Facturas de API 5-10x el presupuesto |
| Latencia creciente sin alerta | Churn silencioso, abandono de sesiones |

## ¿Cómo funciona?

### Las cuatro señales doradas (SRE Golden Signals)

Google SRE popularizó cuatro métricas universales que todo servicio debe medir:

1. **Latency (Latencia)**: cuánto tarda cada request. Medir separadamente latencia de requests exitosos y fallidos.
2. **Traffic (Tráfico)**: demanda sobre el sistema (RPS, QPS, tokens/s).
3. **Errors (Errores)**: tasa de requests fallidos (HTTP 5xx, excepciones, timeouts).
4. **Saturation (Saturación)**: qué tan "lleno" está el sistema (uso de GPU, cola de inferencia, memoria).

Para IA se añade una quinta señal implícita: **calidad del output**.

### Infraestructura vs. Modelo: dos planos distintos

```
Métricas de infraestructura        Métricas de modelo
----------------------------       ------------------------------
cpu_usage_percent                  prediction_confidence_mean
gpu_memory_bytes                   input_feature_distribution
request_latency_seconds            output_class_distribution
http_requests_total                hallucination_rate
error_rate                         tokens_per_request
                                   cost_per_1k_requests
                                   retrieval_recall@k
```

La trampa clásica: dashboards llenos de métricas de infraestructura y **cero visibilidad del modelo**. El sistema parece sano hasta que un cliente avisa que las recomendaciones son absurdas.

### Breakdown de la latencia en un pipeline de LLM

Un request a un chatbot RAG puede descomponerse así:

```
total_latency =
    auth_latency                 # 5 ms
  + input_validation             # 2 ms
  + embedding_generation         # 40 ms
  + vector_search                # 60 ms
  + rerank                       # 30 ms
  + prompt_construction          # 5 ms
  + llm_inference (streaming)    # 1200 ms
  + output_validation            # 10 ms
  + logging/telemetry            # 3 ms
```

Sin instrumentación por etapas, al ver una latencia p99 de 2 segundos no se sabe **dónde** optimizar. Con breakdown, se ve que el 85% del tiempo está en la inferencia del LLM y que vale la pena probar un modelo más pequeño o caching semántico.

### Diseño de alertas: síntomas, no causas

Regla fundamental: **alertar sobre síntomas visibles al usuario**, no sobre causas internas. Alertas malas:

- "CPU > 80%" (al usuario no le importa).
- "Memoria > 70%" (puede ser normal).

Alertas buenas:

- "p99 de latencia > 2s durante 5 minutos" (el usuario lo siente).
- "Tasa de errores > 1% durante 3 minutos".
- "Costo por hora > $50 (3x el baseline)".
- "Confianza media del modelo < 0.6 durante 15 minutos".

### Niveles de severidad

| Nivel | Respuesta | Ejemplo |
|---|---|---|
| **P0 / Critical** | Paginar 24/7 | Servicio caído, pérdida de datos |
| **P1 / High** | Paginar en horario laboral | Degradación grave de calidad |
| **P2 / Medium** | Ticket al equipo | Drift detectado, costos subiendo |
| **P3 / Low** | Review semanal | Métricas de experimentación |

## Ejemplo con código

### Instrumentación básica con Prometheus más tracking de tokens y costos

```python
from prometheus_client import Counter, Histogram
import time
import math
import openai

REQUEST_COUNT = Counter(
    "llm_requests_total",
    "Total de requests al LLM",
    ["model", "status"],
)
REQUEST_LATENCY = Histogram(
    "llm_request_latency_seconds",
    "Latencia de requests al LLM",
    ["model"],
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0),
)
TOKENS_USED = Counter(
    "llm_tokens_total",
    "Tokens consumidos",
    ["model", "type"],  # type = prompt | completion
)
COST_USD = Counter(
    "llm_cost_usd_total",
    "Costo acumulado en USD",
    ["model"],
)
CONFIDENCE = Histogram(
    "model_confidence",
    "Distribución de confianza (exp(logprob) promedio)",
    ["model"],
)

PRICING = {
    "gpt-4o":      {"prompt": 2.5 / 1_000_000, "completion": 10.0 / 1_000_000},
    "gpt-4o-mini": {"prompt": 0.15 / 1_000_000, "completion": 0.6 / 1_000_000},
}

def call_llm_instrumented(prompt: str, model: str = "gpt-4o-mini") -> str:
    start = time.time()
    status = "success"
    try:
        resp = openai.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            logprobs=True,
        )
        u = resp.usage
        TOKENS_USED.labels(model=model, type="prompt").inc(u.prompt_tokens)
        TOKENS_USED.labels(model=model, type="completion").inc(u.completion_tokens)

        price = PRICING[model]
        cost = u.prompt_tokens * price["prompt"] + u.completion_tokens * price["completion"]
        COST_USD.labels(model=model).inc(cost)

        lp = resp.choices[0].logprobs
        if lp and lp.content:
            avg = sum(math.exp(t.logprob) for t in lp.content) / len(lp.content)
            CONFIDENCE.labels(model=model).observe(avg)

        return resp.choices[0].message.content
    except Exception:
        status = "error"
        raise
    finally:
        REQUEST_LATENCY.labels(model=model).observe(time.time() - start)
        REQUEST_COUNT.labels(model=model, status=status).inc()
```

### Reglas de alerta Prometheus (`alerts.yaml`)

```yaml
groups:
  - name: llm_production
    interval: 30s
    rules:
      - alert: LLMLatencyP99High
        expr: histogram_quantile(0.99, rate(llm_request_latency_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: P1
        annotations:
          summary: "p99 de latencia del LLM > 5s"
          runbook: "https://wiki/runbooks/llm-latency"

      - alert: LLMErrorRateHigh
        expr: |
          sum(rate(llm_requests_total{status="error"}[5m]))
          / sum(rate(llm_requests_total[5m])) > 0.02
        for: 3m
        labels:
          severity: P0
        annotations:
          summary: "Tasa de errores LLM > 2%"

      - alert: LLMCostSpike
        expr: rate(llm_cost_usd_total[10m]) * 3600 > 50
        for: 10m
        labels:
          severity: P1
        annotations:
          summary: "Costo proyectado > $50/hora"
          description: "Posible loop, prompt bloat o abuso de usuario."

      - alert: ModelConfidenceDrop
        expr: histogram_quantile(0.5, rate(model_confidence_bucket[15m])) < 0.55
        for: 15m
        labels:
          severity: P2
        annotations:
          summary: "Confianza mediana del modelo cayó por debajo de 0.55"
```

## Errores comunes

- **Monitorear solo infraestructura**. CPU, memoria y uptime verdes mientras el modelo entrega basura.
- **Monitorear solo latencia y olvidar la calidad**. Un modelo rápido y erróneo es peor que uno lento y correcto.
- **Alertas ruidosas (alert fatigue)**. Si saltan 50 alertas por hora, el equipo deja de leerlas. Toda alerta debe ser accionable.
- **No instrumentar por etapas** del pipeline. Imposible saber qué optimizar sin breakdown de latencia.
- **No capturar prompts y respuestas** para postmortem. Cuando un usuario reporta un error, no hay forma de reproducirlo.
- **Retención de datos sin considerar PII**. Guardar prompts crudos durante meses puede violar GDPR o HIPAA.
- **No distinguir confianza del modelo de probabilidad real**. Un modelo mal calibrado puede tener confianza 0.95 y acertar el 60%.
- **Mezclar métricas de negocio con técnicas sin correlación**. La caída de ingresos puede ser el único síntoma de drift.
- **Umbrales estáticos para tráfico estacional**. Un umbral válido a las 3 PM es ruidoso a las 3 AM.
- **No tener runbook asociado a cada alerta**. Despertar a alguien sin decirle qué hacer es cruel e ineficiente.

## Resumen

- El monitoreo de IA cubre tres planos: **infraestructura, servicio y modelo**; los tres pueden fallar independientemente.
- Las **cuatro señales doradas** (latencia, tráfico, errores, saturación) aplican a IA, más una quinta: **calidad del output**.
- Los **fallos silenciosos del modelo** son la amenaza principal; no se detectan con uptime ni HTTP 200.
- **Alertar sobre síntomas visibles al usuario**, no sobre causas internas; cada alerta debe ser accionable y tener runbook.
- El **breakdown de latencia por etapa** convierte un dashboard contemplativo en una herramienta de optimización.
- En LLMs es imprescindible **medir tokens, costo y confianza** además de latencia; los costos pueden explotar en minutos.
- Niveles de severidad bien definidos (**P0-P3**) reducen el alert fatigue y protegen al equipo de guardia.
- Un buen sistema de monitoreo responde tres preguntas en segundos: **¿está roto?**, **¿para quién?** y **¿dónde está el problema?**.
