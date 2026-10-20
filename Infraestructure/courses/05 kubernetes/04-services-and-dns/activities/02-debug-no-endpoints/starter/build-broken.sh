#!/usr/bin/env bash
# Build the broken scenario for k8s-04-02-debug-no-endpoints.
#
# Deployment labels Pods with   app=web
# Service selector matches on   app=webapp     <-- intentional mismatch
#
# Student task: discover the mismatch via `kubectl get endpoints web` (empty),
# then fix the Service selector so endpoints populate.
set -euo pipefail

NS="${NS:-default}"

cat <<YAML | kubectl -n "$NS" apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: ClusterIP
  selector:
    app: webapp     # <-- BUG: Pods expose 'app: web', not 'app: webapp'
  ports:
    - port: 80
      targetPort: 80
YAML

kubectl -n "$NS" rollout status deploy/web --timeout=90s
echo
echo "== Starter listo. Prueba que el Service NO responde =="
kubectl -n "$NS" get svc web
kubectl -n "$NS" get endpoints web
echo
echo "Lee README.md > Paso 3 para empezar el diagnóstico."
