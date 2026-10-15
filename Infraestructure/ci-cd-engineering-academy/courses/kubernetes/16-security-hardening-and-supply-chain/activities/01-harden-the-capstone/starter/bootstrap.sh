#!/usr/bin/env bash
# Bootstrap para k8s-16-01-harden-the-capstone.
# Crea /tmp/.../work con PLACEHOLDERS inseguros que el estudiante debe reescribir.
set -euo pipefail

BASE="${1:-/tmp/k8s-16-01}"

if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi

WORK="$BASE/work"
mkdir -p "$WORK"

# --- namespace.yaml: SIN labels PSA. Editar. ---
cat > "$WORK/namespace.yaml" <<'EOF'
# TODO: añadir labels Pod Security Admission = restricted
apiVersion: v1
kind: Namespace
metadata:
  name: app
EOF

# --- deploy.yaml: deliberadamente laxo. Reescribir. ---
cat > "$WORK/deploy.yaml" <<'EOF'
# TODO: reescribir con securityContext productivo completo.
# Debe pasar PSA restricted en el namespace 'app'.
# Imagen sugerida: nginxinc/nginx-unprivileged:1.27-alpine
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: app
  labels: { app: web }
spec:
  replicas: 2
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      containers:
        - name: web
          image: nginx:1.27
          # Sin securityContext: root + fs escribible + capabilities todas.
          # PSA restricted rechazara esto.
EOF

# --- pod-bad.yaml: prueba negativa. NO modificar. ---
cat > "$WORK/pod-bad.yaml" <<'EOF'
# Pod intencionalmente laxo. Debe ser RECHAZADO por PSA restricted.
apiVersion: v1
kind: Pod
metadata:
  name: bad
  namespace: app
spec:
  containers:
    - name: bad
      image: busybox:1.36
      command: ["sh","-c","sleep 3600"]
      securityContext:
        privileged: true
        runAsUser: 0
EOF

echo "Bootstrap OK en $WORK"
echo "Siguiente paso: editar namespace.yaml y deploy.yaml."
