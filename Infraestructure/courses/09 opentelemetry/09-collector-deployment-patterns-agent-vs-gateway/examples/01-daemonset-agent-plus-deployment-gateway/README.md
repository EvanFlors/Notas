# Example 01 — DaemonSet agent + Deployment gateway

Despliega en **kind** la topología de referencia: un `otel-agent` como DaemonSet (uno por nodo) que envía telemetría a un `otel-gateway` como Deployment detrás de un Service. El gateway exporta a un sink `debug` (log) para que puedas ver los spans que llegan.

```
┌──────────────┐    OTLP (grpc)      ┌──────────────┐    debug (stdout)
│ otel-agent   │ ──────────────────► │ otel-gateway │ ──────────────────► kubectl logs
│ (DaemonSet)  │  to otel-gateway    │ (Deployment) │
└──────────────┘  svc:4317           └──────────────┘
```

## Qué demuestra

- Separación de responsabilidades agent vs gateway.
- El agent **enriquece** con `k8s.node.name` y `host.name` por `resourcedetection`.
- El gateway hace `batch` grande y expone `health_check`.
- Service DNS: `otel-gateway.observability.svc.cluster.local:4317`.

## Prerrequisitos

- `kind` ≥ 0.22, `kubectl` ≥ 1.29, Docker corriendo. Si no están, el script hace **SKIP**.

## Archivos

- `kind-config.yaml` — cluster de 2 nodos (control-plane + worker).
- `agent-daemonset.yaml` — ConfigMap + DaemonSet del agent.
- `gateway-deployment.yaml` — ConfigMap + Deployment + Service + HPA skeleton.
- `generate-traces.yaml` — Job con `telemetrygen` que emite 100 spans al agent local.
- `run.sh` — up & smoke test (idempotente).
- `cleanup.sh` — tira el cluster y limpia `/tmp/otel-09-ex01`.

## Ejecutar

```bash
bash run.sh
# ... verás spans en el log del gateway
bash cleanup.sh
```

## Verificar manualmente

```bash
kubectl -n observability logs deploy/otel-gateway | grep -c 'ResourceSpans'
```

Debe ser > 0.

## Limpieza

```bash
bash cleanup.sh
```
