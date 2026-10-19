# Ejemplo 01 — OpenTelemetry → Cloud Trace vía Collector (ADOT)

> Walkthrough. Lectura y análisis. Sin ejecución en GCP. Objetivo: dejar fijo el **patrón de instrumentación vendor-neutral** donde la app solo conoce OTLP y el Collector decide los destinos.

## 1. Topología de referencia

```
┌──────────────────────────────┐
│  App (Cloud Run / GKE)       │
│                              │
│  OpenTelemetry SDK           │
│  - traces (spans)            │
│  - metrics (opcional)        │
│                              │
│  OTLP exporter → gRPC :4317  │
└───────────────┬──────────────┘
                │ OTLP/gRPC
                ▼
┌──────────────────────────────────────────────┐
│  OTel Collector (ADOT distro o upstream)     │
│                                              │
│  receivers:  otlp                            │
│  processors: memory_limiter, batch, resource │
│  exporters:  googlecloud (Cloud Trace)       │
│              otlp/jaeger (dev local)         │
│              prometheusremotewrite (opt)     │
└───────────────┬──────────────┬───────────────┘
                │ gRPC         │ OTLP
                ▼              ▼
       ┌────────────┐    ┌─────────────┐
       │ Cloud Trace│    │ Jaeger /    │
       │ (GCP)      │    │ Grafana     │
       └────────────┘    │ Tempo       │
                         └─────────────┘
```

## 2. Por qué el Collector en medio (y no exporter directo)

| Opción | Ventaja | Problema |
|--------|---------|----------|
| App → **exporter googlecloud directo** | Un salto menos; menos infra. | Acoplamiento al vendor en el código. Cambiar a Jaeger/Honeycomb = refactor en todas las apps. |
| App → **Collector** → Cloud Trace | Vendor-neutral; fan-out trivial; procesamiento centralizado (sampling, resource attrs). | Un componente más que operar. En Cloud Run se puede desplegar como sidecar; en GKE como DaemonSet o Deployment. |

Regla: el Collector gana en cuanto hay más de una app o se prevé un cambio de vendor. En práctica, siempre.

## 3. Config del Collector (anotada)

```yaml
# collector-config.yaml  — walkthrough; NO se aplica en este módulo.
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317     # OTLP/gRPC default
      http:
        endpoint: 0.0.0.0:4318     # OTLP/HTTP para apps que no hablan gRPC

processors:
  memory_limiter:                  # protege ante bursts
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100

  batch:                           # reduce RPCs al exporter
    send_batch_size: 512
    timeout: 5s

  resource:                        # añade atributos a cada span
    attributes:
      - key: deployment.environment
        value: prod
        action: upsert
      - key: service.namespace
        value: checkout
        action: upsert

  tail_sampling:                   # keeps slow traces, drops the rest
    decision_wait: 10s
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: latency-high
        type: latency
        latency: { threshold_ms: 500 }
      - name: baseline
        type: probabilistic
        probabilistic: { sampling_percentage: 1 }

exporters:
  googlecloud:                     # Cloud Trace exporter
    project: PROJECT_ID            # placeholder — no project real
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

  otlp/jaeger:                     # fan-out opcional para dev
    endpoint: jaeger-collector:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [memory_limiter, batch, resource, tail_sampling]
      exporters:  [googlecloud]
```

Comentarios clave:

- **`memory_limiter` siempre primero**. Si el collector queda OOM, la app bloquea en el export y degrada.
- **`batch` reduce coste** (menos RPCs a Cloud Trace = menos spans facturables si los agrupas antes de muestrear mal).
- **`tail_sampling`** es la joya. En vez de "1% de todo" (y perder los traces de error), guardas el 100% de los traces lentos o con error y 1% del resto.
- **`project: PROJECT_ID`** es placeholder. En un deploy real se inyectaría por env var; aquí usamos literal `PROJECT_ID` para dejar claro que no corresponde a un project real.

## 4. Instrumentación en la app (snippet Python)

```python
# app.py — walkthrough. NO se ejecuta.
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

resource = Resource.create({
    "service.name": "checkout-api",
    "service.version": "1.4.2",
})

provider = TracerProvider(resource=resource)
exporter = OTLPSpanExporter(
    endpoint="otel-collector.observability.svc.cluster.local:4317",
    insecure=True,
)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("process_payment"):
    ...  # business logic
```

**Nota**: la app **no** importa ningún exporter Google. Solo OTLP. Si mañana el Collector reconfigura su exporter, la app no cambia.

## 5. Patrón de despliegue

| Entorno | Collector dónde | Notas |
|---------|-----------------|-------|
| **GKE** | Deployment + Service `otel-collector`, o DaemonSet si quieres bajar latencia (span → nodo local). | Usar `OpenTelemetry Operator` si se gestiona declarativamente. |
| **Cloud Run** | Sidecar container en el mismo service (soporte de multi-container ya GA). | La app apunta a `localhost:4317`. |
| **Compute Engine** | Collector como systemd service en la VM, o en una VM central. | DaemonSet-like con MIG. |

## 6. ADOT vs upstream OTel Collector

**ADOT** (AWS Distro for OpenTelemetry) es un *build* firmado y curado del upstream con un subset de receivers/exporters/processors probado por AWS. **No es exclusivo de AWS** — su binario corre igual en GCP y multi-cloud. Se usa cuando:

- Quieres soporte comercial via AWS.
- Prefieres un distro con release cadence predecible.
- Tu stack ya es cross-cloud y el ADOT exporter list cubre tus destinos (incluye `googlecloud` para Cloud Trace).

Si no, el **upstream `otel/opentelemetry-collector-contrib`** sirve igual.

## 7. Preguntas de autocomprobación

1. ¿Por qué `memory_limiter` va antes que `batch` en la lista de processors? ¿Qué pasa si los invierto?
2. En el `tail_sampling`, si un trace tiene un span con `ERROR` y 10 spans OK, ¿se guarda el trace entero?
3. Si la app apunta directo a `cloudtrace.googleapis.com` (sin Collector), ¿qué pierdes además del vendor-neutral?
4. ¿Qué ventaja tiene desplegar el Collector como **sidecar** en Cloud Run vs un Deployment compartido en GKE?
5. ¿Cuál es la diferencia operativa entre ADOT y upstream OTel Collector cuando el destino es Cloud Trace?
