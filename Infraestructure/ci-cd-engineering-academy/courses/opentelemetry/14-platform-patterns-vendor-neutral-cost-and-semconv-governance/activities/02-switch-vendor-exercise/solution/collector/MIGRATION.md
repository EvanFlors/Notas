# MIGRATION — Self-hosted (Tempo+Loki+Prometheus) -> Datadog

## 1. Context

El capstone emite OTLP a un Collector local. Hasta hoy el Collector exportaba a Tempo (traces), Prometheus remote-write (métricas) y Loki (logs) — todo self-hosted. La dirección aprobó evaluar Datadog como backend único durante Q1 2027 para medir reducción de carga operativa. Esta migración demuestra que el cambio es sólo en la configuración del Collector; no se toca el código de ningún servicio.

## 2. Decision

Reemplazar los tres exporters self-hosted por el exporter unificado `datadog` del Collector contrib. Mantener todos los processors de cost control (tail sampling, drop high-cardinality attributes, memory_limiter, batch, k8sattributes, resource). API key referenciada por `${env:DD_API_KEY}` desde un Secret montado en el Pod.

## 3. Steps

1. Crear Secret `k8s create secret generic dd-credentials --from-literal=DD_API_KEY=... --from-literal=DD_SITE=datadoghq.eu -n observability`.
2. Montar el Secret como env vars en el Deployment del Collector gateway.
3. `kubectl apply -f collector-datadog.yaml` sobre el ConfigMap del Collector en un namespace `observability-canary` primero.
4. Shift 10% del tráfico al canary via una Service con split (o duplicando el agent config a apuntar al canary).
5. Observar durante 24h en Datadog UI: validar que las 3 signals llegan, que `service.name` aparece como `service` de Datadog, que exemplars funcionan.
6. Promover el ConfigMap al Collector gateway principal.
7. Mantener Tempo/Loki/Prometheus en modo lectura durante 30 días (sin ingest) para consultas históricas.

## 4. Verification

- Datadog APM muestra traces con `service=payments-api`, `env=prod`.
- Métricas aparecen bajo `otel.*` namespace en Datadog Metrics Explorer.
- Logs llegan a Datadog Logs con atributo `trace_id` poblado (click-through log → trace OK).
- Collector meta-telemetry (`:8888/metrics`): `otelcol_exporter_sent_spans{exporter=datadog}` > 0, `otelcol_exporter_send_failed_spans` ≈ 0.
- `git diff` del PR toca sólo `collector/*.yaml` y, opcionalmente, `k8s/collector-deployment.yaml` para montar el Secret.

## 5. Rollback

Si Datadog muestra pérdida de datos o la factura se dispara:

1. `kubectl apply -f collector-self-hosted.yaml` sobre el ConfigMap.
2. `kubectl rollout restart deployment/otel-collector-gateway -n observability`.
3. Tempo/Loki/Prometheus siguen vivos; ingest se restaura en < 2 min.
4. Post-mortem: comparar costos y pérdidas; actualizar ADR vendor-neutrality con el aprendizaje.
