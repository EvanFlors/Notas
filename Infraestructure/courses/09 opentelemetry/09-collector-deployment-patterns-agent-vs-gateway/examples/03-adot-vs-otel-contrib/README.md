# Example 03 — ADOT vs OTel Contrib vs Alloy

Comparativa narrativa + fragmentos de config equivalentes para orientarte a elegir **distro** del Collector.

## Mapa mental

```
┌───────────────── Core (otel/opentelemetry-collector) ─────────────────┐
│  OTLP, batch, memory_limiter, logging/debug, prometheusremotewrite    │
└───────────────────────────────────────────────────────────────────────┘
          │                                 │
          ▼                                 ▼
┌─────── Contrib ────────┐          ┌─────── Vendor distros ───────┐
│ + k8sattributes        │          │  ADOT (AWS)                  │
│ + tail_sampling        │          │   + awsxrayexporter          │
│ + filelog, hostmetrics │          │   + awsemfexporter           │
│ + loki, tempo, datadog │          │   + awsprometheusremotewrite │
│ + routing, transform…  │          │   + SigV4 auth               │
│   (todo lo "oficial"   │          │  Grafana Alloy               │
│    de la comunidad)    │          │   (lineage Collector+Agent+  │
└────────────────────────┘          │    Promtail; config River)   │
                                    └──────────────────────────────┘
```

## Tabla de decisión

| Pregunta | Core | Contrib | ADOT | Alloy |
|----------|:----:|:-------:|:----:|:-----:|
| ¿Solo OTLP → OTLP? | OK | OK | OK | OK |
| ¿Necesito `k8sattributes`? | — | OK | OK (via contrib components) | OK |
| ¿Necesito `tail_sampling`? | — | OK | OK | OK |
| ¿Backend es AWS X-Ray / CloudWatch EMF? | — | — | **Preferido** | — |
| ¿Backend es Grafana Mimir/Tempo/Loki? | — | OK | — | **Preferido** |
| ¿SigV4 auth hacia Amazon Managed Prometheus? | — | parcial | **Preferido** | parcial |
| ¿Quiero config YAML idéntica a upstream? | OK | OK | OK | **No** (River) |
| ¿Soporte formal del vendor? | — | — | AWS | Grafana Labs |

## Fragmentos equivalentes

### Core / Contrib: exporter OTLP a Tempo

```yaml
exporters:
  otlp/tempo:
    endpoint: tempo.observability.svc.cluster.local:4317
    tls: { insecure: true }
```

### ADOT: exporter a AWS X-Ray

```yaml
# imagen: public.ecr.aws/aws-observability/aws-otel-collector
exporters:
  awsxray:
    region: us-east-1
  awsemf:
    region: us-east-1
    log_group_name: /otel/metrics
    namespace: AppMetrics
service:
  pipelines:
    traces:  { receivers: [otlp], exporters: [awsxray] }
    metrics: { receivers: [otlp], exporters: [awsemf]  }
```

### Grafana Alloy (sintaxis River)

```river
otelcol.receiver.otlp "default" {
  grpc { endpoint = "0.0.0.0:4317" }
  output {
    traces = [otelcol.processor.batch.default.input]
  }
}

otelcol.processor.batch "default" {
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo:4317"
    tls { insecure = true }
  }
}
```

Observa cómo el **modelo** (receiver → processor → exporter) es idéntico; cambia la gramática del archivo.

## Recomendación por entorno

| Entorno | Default razonable |
|---------|-------------------|
| On-prem / self-hosted, Prometheus + Tempo + Loki | **otelcol-contrib** o **Alloy** |
| AWS EKS, backend AWS nativo | **ADOT** |
| AWS EKS, backend self-hosted (Tempo…) | **otelcol-contrib** |
| GCP GKE, backend Cloud Trace / Cloud Monitoring | **otelcol-contrib** con exporters `googlecloud` |
| Multi-cloud, "ninguno de arriba" | **otelcol-contrib** |

## Ejecutar (opcional, docker)

Este example es de lectura. Si quieres probar que `otelcol-contrib` arranca con la config del Example 01, basta:

```bash
docker run --rm -p 4317:4317 \
  -v "$(pwd)/../01-daemonset-agent-plus-deployment-gateway/gateway-deployment.yaml":/tmp/g.yaml \
  otel/opentelemetry-collector-contrib:0.109.0 --help
```

No requiere limpieza.
