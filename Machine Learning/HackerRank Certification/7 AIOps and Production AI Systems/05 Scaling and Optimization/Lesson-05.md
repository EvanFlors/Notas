# Framework de Decisión para Optimización en Producción

## ¿Qué es?

Un **framework de optimización** es un proceso sistemático para decidir **qué** optimizar, **cuándo**, **cuánto** y **a qué costo**. Sin él, los equipos caen en dos extremos: optimizar prematuramente lo que no importa, o no optimizar lo que les sangra la factura.

El proceso canónico tiene seis pasos:

1. **Baseline:** mide el estado actual (latencia p50/p95/p99, throughput, $/req, utilización).
2. **Profile:** identifica el cuello de botella (compute, memoria, red, I/O, feature retrieval).
3. **Define goal:** meta cuantificable (`p99 < 200ms`, `$/req < 0.001`).
4. **Priorize:** matriz impacto × esfuerzo; empieza por alto impacto / bajo esfuerzo.
5. **Implement + measure:** aplica un cambio a la vez, mide impacto real.
6. **Document + iterate:** registra qué funcionó, qué no, por qué.

## ¿Por qué importa?

La optimización sin framework es un casino: inviertes semanas en algo que suena cool pero no mueve la aguja, mientras lo que de verdad pesa (feature retrieval lento, falta de caching, instancias sobredimensionadas) sigue sangrando. Un framework asegura que el esfuerzo de ingeniería tenga ROI positivo.

Además, un framework hace **tradeoffs explícitos**: cada decisión de optimización sacrifica algo (calidad por velocidad, flexibilidad por costo, latencia por throughput). Explicitarlo evita sorpresas de negocio ("¡el modelo bajó 3% de accuracy sin avisarnos!") y permite alinear decisiones técnicas con prioridades de producto.

## ¿Cómo funciona?

### 1. Baseline obligatorio

Antes de optimizar, mide:

| Métrica | Cómo | Herramienta |
|---|---|---|
| **Latencia** p50/p95/p99 | Instrumentar cada endpoint | Prometheus + Grafana, Datadog |
| **Throughput** (QPS) | Contador de requests/s | Prometheus |
| **Utilización** CPU/GPU/VRAM | Node/DCGM exporter | Prometheus + DCGM |
| **Cost per request** | `cost_usd_total / requests_total` | Kubecost, Vantage |
| **Hit rate** cache | `hits / (hits + misses)` | Métricas custom |
| **Error rate** | `5xx + 4xx / total` | Logs + Prometheus |

Sin baseline no puedes probar que una optimización ayudó. Sin baseline, cualquier regresión parece normal.

### 2. Profile para encontrar el cuello

Preguntas clave:

- ¿Compute-bound o memory-bound? (nvtop, `nvidia-smi dmon`)
- ¿Dónde se va la latencia? (tracing distribuido: OpenTelemetry, Jaeger)
- ¿Qué endpoint pesa más en facture? (cost per endpoint)
- ¿El modelo o el pipeline alrededor? (`py-spy`, `pyinstrument`, PyTorch Profiler)

Regla: **la mejora de un no-cuello no mejora el sistema.** Ley de Amdahl.

### 3. Tradeoffs principales

| Tradeoff | Palanca | Cuándo priorizar X |
|---|---|---|
| **Latencia vs costo** | Instancias más grandes / más réplicas | User-facing: latencia; batch: costo |
| **Throughput vs latencia** | Batch size | Serving background: throughput; interactive: latencia |
| **Calidad vs velocidad** | Quantization, modelo más chico, distilación | Si -1% calidad = -50% costo: casi siempre vale |
| **Complejidad vs flexibilidad** | TensorRT custom vs vLLM genérico | Scale enorme: complejidad vale; MVP: flexibilidad |
| **CapEx vs OpEx** | Reserved vs On-demand | Workload estable: reserved; incierto: on-demand |
| **Esfuerzo eng vs hardware** | Optimizar vs comprar GPU más grande | $500/mes extra < 2 semanas de un senior |
| **Velocidad de desarrollo vs eficiencia prod** | Equipo invierte en features vs infra | Pre-PMF: features; post-PMF: infra |

### 4. Matriz de priorización

```
                      Impacto
            Bajo              Alto
Esfuerzo ┌────────────────┬────────────────┐
   Bajo  │  Quick wins    │  Hazlo YA      │
         │  (siempre)     │  (prioridad 1) │
         ├────────────────┼────────────────┤
   Alto  │  Ignorar       │  Planificar    │
         │  (nunca)       │  (prioridad 2) │
         └────────────────┴────────────────┘
```

Ejemplos reales:

| Optimización | Impacto | Esfuerzo | Verdict |
|---|---|---|---|
| Activar `enable_prefix_caching=True` en vLLM | Alto (↓30-70% prefill) | Mínimo | HAZLO YA |
| Prediction cache con Redis | Alto (↓40-80% repeat traffic) | Bajo | HAZLO YA |
| Autoscaling scale-to-zero en stage | Medio ($) | Bajo | Quick win |
| Cuantizar INT4 con AWQ | Alto (2-4×) | Medio (eval) | Planificar |
| Reescribir pipeline en Rust | Medio | Altísimo | Ignorar hasta justificar |
| Entrenar modelo distilado propio | Alto | Muy alto | Planificar si escala lo justifica |

### 5. Checklist de producción

**Monitoreo y observabilidad**
- [ ] Métricas de latencia p50/p95/p99 por endpoint
- [ ] Métricas de utilización CPU/GPU/VRAM por pod
- [ ] Tracing distribuido activo (OpenTelemetry)
- [ ] Dashboards de costo por servicio/cliente/modelo
- [ ] Alertas de SLO y de budget

**Feature engineering y datos**
- [ ] Feature cache en Redis para features caros
- [ ] Precompute de features offline donde se pueda
- [ ] Deduplicación de llamadas en el request path

**Modelo**
- [ ] Modelo cuantizado (FP16/INT8/INT4 según hardware)
- [ ] Serving en runtime optimizado (vLLM/TGI/TensorRT-LLM/ONNX)
- [ ] Batching (continuous o dynamic) activado
- [ ] Flash Attention 2 habilitado
- [ ] Prefix caching / prompt caching activo
- [ ] Model cascade / routing para queries triviales

**Infraestructura**
- [ ] Right-sizing: utilización en 60-80%
- [ ] Autoscaling HPA por métrica relevante (GPU util, queue depth)
- [ ] Scale-down agresivo configurado
- [ ] Spot/preemptible para batch y training
- [ ] Reserved para baseline
- [ ] Co-locación compute-datos en misma AZ

**Caching**
- [ ] Multinivel: in-process + Redis + CDN
- [ ] Hit rate monitoreado y >70% objetivo
- [ ] Invalidación por evento donde la freshness importa
- [ ] TTLs tuneados por volatilidad

**Red y storage**
- [ ] Egress reduction (compresión, CDN)
- [ ] Lifecycle policies (S3 → Glacier → delete)
- [ ] Payloads comprimidos (gzip/zstd/brotli)

**Procesos**
- [ ] Revisión trimestral de costos y optimización
- [ ] Playbooks de incidente de costo/latencia
- [ ] Postmortems documentados

### 6. Decisión: cuándo parar de optimizar

Para cuando:

- El SLO se cumple con margen cómodo (ej. p99 100ms vs objetivo 200ms).
- El próximo 10% de mejora requiere 10× el esfuerzo del anterior (retornos decrecientes).
- El costo mensual del servicio es << el valor que entrega.
- Hay trabajo de producto con mayor ROI pendiente.

Reoptimiza cuando el tráfico se duplica, el modelo cambia, o el precio del cloud se mueve.

## Ejemplo con código

### Script de baseline + load test (locust + reporte)

```python
# locustfile.py
from locust import HttpUser, task, between

class LLMUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def ask(self):
        with self.client.post(
            "/v1/predict",
            json={"prompt": "Resume el documento adjunto en 3 bullets"},
            catch_response=True,
        ) as r:
            if r.status_code != 200:
                r.failure(f"status {r.status_code}")

# locust -f locustfile.py --host https://api.example.com \
#        --users 500 --spawn-rate 50 --run-time 10m --headless --csv baseline
```

El CSV emitido da p50/p95/p99/throughput/error rate para comparar antes vs después de cada cambio.

### Profiling con PyTorch Profiler

```python
import torch
from torch.profiler import profile, record_function, ProfilerActivity

with profile(
    activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA],
    record_shapes=True,
    profile_memory=True,
    with_stack=True,
) as prof:
    with record_function("inference"):
        _ = model(input_ids)

print(prof.key_averages().table(sort_by="cuda_time_total", row_limit=20))
prof.export_chrome_trace("trace.json")   # abrir en chrome://tracing
```

### Comparador antes/después (A/B de optimización)

```python
import time, statistics as st

def benchmark(fn, inputs, warmup=10, n=200):
    for x in inputs[:warmup]: fn(x)
    times = []
    for x in inputs[:n]:
        t0 = time.perf_counter()
        fn(x)
        times.append((time.perf_counter() - t0) * 1000)
    return {
        "p50": st.median(times),
        "p95": sorted(times)[int(n*0.95)],
        "p99": sorted(times)[int(n*0.99)],
        "mean": st.mean(times),
    }

base = benchmark(lambda x: baseline_model.predict(x), test_inputs)
opt  = benchmark(lambda x: optimized_model.predict(x), test_inputs)

print(f"p50: {base['p50']:.1f}ms -> {opt['p50']:.1f}ms  ({(1-opt['p50']/base['p50'])*100:+.1f}%)")
print(f"p99: {base['p99']:.1f}ms -> {opt['p99']:.1f}ms  ({(1-opt['p99']/base['p99'])*100:+.1f}%)")
```

### ADR plantilla para documentar decisiones

```markdown
# ADR-012: Migrar serving LLM a vLLM con INT4 (AWQ)

## Contexto
P99 de /v1/chat es 2.4s con TGI + FP16. SLO objetivo: 1s. Factura mensual: $34k.

## Decisión
Migrar a vLLM 0.6 con AWQ-INT4, prefix caching y continuous batching.

## Alternativas evaluadas
- TensorRT-LLM: 2x mejor, pero lock-in NVIDIA y complejidad +.
- Mantener TGI: no cumple SLO.
- Modelo distilado 8B: pierde 6% MMLU, inaceptable.

## Impacto medido (A/B 2 semanas)
- p99:   2400ms -> 820ms (-66%)
- $/req: $0.0043 -> $0.0014 (-67%)
- MMLU: 72.1 -> 71.6 (-0.5%, aceptable)

## Riesgos
- Primeras versiones de AWQ en vLLM tuvieron bugs en multi-GPU; se mitigó pinning version 0.6.3.

## Fecha / Autor
2026-02-15 / Equipo Platform-ML
```

### Dashboard mínimo (Grafana PromQL)

```promql
# Latencia p99 por endpoint
histogram_quantile(0.99, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket[5m])))

# Throughput
sum(rate(http_requests_total[1m])) by (endpoint)

# GPU utilization promedio
avg(DCGM_FI_DEV_GPU_UTIL) by (pod)

# $/request rolling 1h
sum(rate(llm_cost_usd_total[1h])) / sum(rate(http_requests_total[1h]))

# Cache hit rate
sum(rate(cache_hits_total[5m])) / (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))
```

## Errores comunes

- **Optimizar sin baseline.** No puedes probar la mejora si no sabes de dónde partiste.
- **Optimizar el no-cuello.** 2 semanas haciendo el modelo 2× más rápido cuando el 80% de la latencia es feature retrieval.
- **Cambiar varias cosas a la vez.** No sabes cuál ayudó, cuál empeoró. Un cambio, una medición.
- **Olvidar la calidad.** Celebras -40% latencia pero bajaste 5% accuracy y nadie lo mide.
- **No fijar SLO.** Sin "cuándo es suficiente", optimizas eternamente sin entregar valor.
- **Overengineering pre-PMF.** Startup pre-tracción optimizando a nivel Google es destruir runway. Primero valida, luego escala.
- **Benchmarks irrealistas.** Load test con un solo prompt sintético no refleja producción. Usa prompts/inputs reales (sampleados y anonimizados).
- **Ignorar el p99.** Promedio bonito, p99 catastrófico. Los usuarios recuerdan la peor experiencia, no la media.
- **No documentar.** 6 meses después nadie recuerda por qué `max_batch_size = 48` y lo cambian, rompiendo todo.
- **No reoptimizar.** Lo que era óptimo hace un año puede estar obsoleto (hardware nuevo, modelos nuevos, patrones de tráfico distintos).

## Resumen

- Framework canónico: **baseline → profile → goal → prioritize → implement → document**.
- **Métricas obligatorias:** latencia p50/p95/p99, throughput, utilización GPU/CPU/VRAM, $/request, hit rate, error rate.
- Prioriza por **impacto × esfuerzo**: cache y batching son casi siempre quick wins; reescrituras masivas rara vez.
- Tradeoffs explícitos: latencia↔costo, throughput↔latencia, calidad↔velocidad, complejidad↔flexibilidad. Haz la elección consciente.
- **Checklist de producción**: monitoreo, feature caching, modelo cuantizado+batched+prefix-cached, right-sizing, spot+reserved, scale-to-zero.
- **Un cambio, una medición.** Comparar antes/después con el mismo load test.
- **Documenta decisiones (ADRs)**. Es la única manera de evitar re-descubrir las mismas conclusiones.
- Para de optimizar cuando el SLO sobra, los retornos decrecen o hay trabajo con mayor ROI.
- Reoptimiza trimestralmente o cuando el contexto cambie (10× tráfico, modelo nuevo, hardware nuevo).
- Herramientas: Prometheus+Grafana, OpenTelemetry+Jaeger, py-spy/pyinstrument, PyTorch Profiler, Locust/k6, Kubecost, Vantage.
