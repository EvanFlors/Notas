#!/usr/bin/env bash
# Envia 100 spans al Service del agent (DaemonSet). El agent los reenvia al gateway.
set -eu
NS="observability"

skip() { echo "SKIP: $1"; exit 0; }
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
kubectl version --request-timeout=5s >/dev/null 2>&1 || skip "sin apiserver"

kubectl -n "$NS" delete job telemetrygen --ignore-not-found >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: telemetrygen
  namespace: observability
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: telemetrygen
          image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.109.0
          args:
            - traces
            - --otlp-endpoint=otel-agent.observability.svc.cluster.local:4317
            - --otlp-insecure
            - --traces=100
            - --service=demo-app
YAML

kubectl -n "$NS" wait --for=condition=complete job/telemetrygen --timeout=90s || true
echo "send-traces done."
