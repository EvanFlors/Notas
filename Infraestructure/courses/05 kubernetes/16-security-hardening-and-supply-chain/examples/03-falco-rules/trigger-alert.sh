#!/usr/bin/env bash
# Spawn a Pod in 'app' and exec a shell inside it to trigger the custom rule.
set -euo pipefail

kubectl create ns app --dry-run=client -o yaml | kubectl apply -f -

kubectl -n app apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shell-target
  namespace: app
  labels: { app: shell-target }
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: box
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        capabilities: { drop: ["ALL"] }
      resources:
        requests: { cpu: "10m", memory: "16Mi" }
        limits:   { cpu: "100m", memory: "64Mi" }
EOF

kubectl -n app wait --for=condition=Ready pod/shell-target --timeout=60s

echo "Disparando shell dentro del container (esto activa la regla Falco)..."
kubectl -n app exec shell-target -- sh -c "id; ls /" || true

sleep 3
echo
echo "Logs de Falco (buscando la alerta):"
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=100 | grep -iE "shell|Warning" || echo "(nada todavia; a veces tarda unos segundos mas)"
