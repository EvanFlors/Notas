#!/usr/bin/env bash
# Reference solution for k8s-04-02-debug-no-endpoints.
#
# The bug: Service.spec.selector.app = "webapp"
# The real Pod label:               app = "web"
#
# Minimal fix: patch the Service so its selector matches reality,
# without touching the Deployment.
set -euo pipefail

NS="${NS:-default}"

kubectl -n "$NS" patch svc web --type=merge -p '{"spec":{"selector":{"app":"web"}}}'

echo "== endpoints tras el fix =="
kubectl -n "$NS" get endpoints web

echo "== prueba HTTP =="
kubectl -n "$NS" run tmp-check-$RANDOM --image=curlimages/curl:8.9.1 \
  --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://web

# Diagnóstico de referencia (plantilla)
mkdir -p /tmp/k8s-04-02
cat > /tmp/k8s-04-02/diagnostico.md <<'MD'
# Diagnóstico — k8s-04-02

- Síntoma observado: `curl http://web` desde un Pod cliente cuelga y supera el timeout.
- Comando que reveló la causa: `kubectl get endpoints web` → sin backends.
- Causa raíz: el Service tenía `selector.app=webapp`, pero los Pods del Deployment llevan la label `app=web`. El controlador de endpoints no encontró ningún Pod que matchee y dejó la slice vacía.
- Arreglo mínimo aplicado: `kubectl patch svc web --type=merge -p '{"spec":{"selector":{"app":"web"}}}'`.
- Evidencia de que ahora funciona: `kubectl get endpoints web` lista 3 IP:80 y `curl http://web` devuelve HTTP 200.
MD
echo "Diagnóstico de referencia escrito en /tmp/k8s-04-02/diagnostico.md"
