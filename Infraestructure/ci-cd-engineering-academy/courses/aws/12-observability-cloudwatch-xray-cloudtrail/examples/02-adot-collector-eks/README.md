# Ejemplo 02 — ADOT Collector en EKS como DaemonSet (dual-write a CloudWatch y Prometheus)

> Lectura y análisis del manifiesto `config.yaml`. No se despliega en un clúster real; sirve de referencia para la actividad `01-instrument-fastapi-with-adot`.

## 1. ¿Por qué DaemonSet?

Un **DaemonSet** garantiza un pod del Collector **por nodo**. Las apps envían OTLP a `localhost:4317` (gRPC) o `:4318` (HTTP) y el Collector del nodo:

- Añade atributos de nodo (`k8s.node.name`, zona, instancia EC2).
- Hace **batching** antes de enviar a AWS → reduce número de llamadas y coste.
- Puede caerse sin afectar más que a su nodo (vs un **gateway** central, SPoF).

Para volúmenes grandes se combinan: **agent (DaemonSet) → gateway (Deployment)** central para enrutamiento complejo.

## 2. El pipeline en una vista

```
   App pod ─── OTLP gRPC :4317 ──► ADOT Collector (DaemonSet)
                                       │
                                       ├── traces  ──► awsxray         ──► X-Ray
                                       ├── metrics ──► awsemf          ──► CloudWatch Metrics (via Logs)
                                       │            └► prometheusremotewrite ──► Prometheus/Mimir
                                       └── logs    ──► awscloudwatchlogs ──► CloudWatch Logs
```

Observa:

- **traces** solo van a X-Ray (podrían ir también a Tempo con un segundo exporter OTLP).
- **metrics** van a **dos sitios** (dual-write): CloudWatch via EMF *y* Prometheus. Útil durante migración.
- **logs** van a CloudWatch (podrían ir también a Loki con `exporter/loki`).

## 3. Config comentada (`config.yaml`)

Mira `./config.yaml` en este mismo directorio. Puntos a observar:

- `receivers.otlp.protocols.{grpc,http}` — ambos activos para flexibilidad.
- `processors.batch` — crítico para no spamear la API de CloudWatch.
- `processors.memory_limiter` — recomendado siempre: el Collector OOM-ea feo.
- `exporters.awsemf.log_group_name` — las métricas EMF **se escriben como logs** en un log group; CloudWatch los extrae a métricas.
- `service.pipelines` — tres pipelines (traces, metrics, logs), cada uno con sus exporters.

## 4. IAM: cómo autoriza el Collector

Vía **IRSA (IAM Roles for Service Accounts)** o **Pod Identity** (ver `aws-11`). El ServiceAccount del DaemonSet tiene un rol IAM con política mínima:

```
cloudwatch:PutMetricData
logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents, logs:DescribeLogStreams
xray:PutTraceSegments, xray:PutTelemetryRecords, xray:GetSamplingRules, xray:GetSamplingTargets
```

**Nunca** keys estáticas. Nunca `*` recursos: scope por log group y por región.

## 5. Qué NO está en este ejemplo

- Deployment real a EKS (ver `aws-10` y futuro `aws-16` para el pipeline completo).
- Métricas de clúster (Container Insights) — se añade un `receiver.awscontainerinsight` aparte.
- Tail sampling de X-Ray — pertenece a `opentelemetry-10`.

El objetivo aquí es el **pipeline estático**: receiver → processor → exporter, en un YAML que el Collector binario valida.
