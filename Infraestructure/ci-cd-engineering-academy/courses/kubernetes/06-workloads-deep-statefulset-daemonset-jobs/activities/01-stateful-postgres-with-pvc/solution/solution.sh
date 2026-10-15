#!/usr/bin/env bash
# Reference solution for k8s-06-01-stateful-postgres-with-pvc.
# Note: we deliberately do NOT enable `set -o pipefail`. Several commands below
# pipe into `grep -q`; if grep matches early, kubectl may receive SIGPIPE
# (exit 141) and pipefail would promote that to a false failure.

set -eu

WORK="/tmp/k8s-06-01"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$WORK"
cp "$HERE/postgres.yaml" "$WORK/postgres.yaml"

# Clean slate (safe if nothing exists)
kubectl delete statefulset pg --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pvc -l app=pg --ignore-not-found >/dev/null 2>&1 || true
kubectl delete svc pg --ignore-not-found >/dev/null 2>&1 || true

kubectl apply -f "$WORK/postgres.yaml"
kubectl rollout status statefulset/pg --timeout=240s

# Wait until pg_isready inside the Pod reports ok.
for i in $(seq 1 30); do
  if kubectl exec pg-0 -- pg_isready -U postgres -d demo >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

kubectl exec pg-0 -- psql -U postgres -d demo -c \
  "CREATE TABLE IF NOT EXISTS t (id serial primary key, msg text);" >/dev/null
kubectl exec pg-0 -- psql -U postgres -d demo -c \
  "INSERT INTO t(msg) VALUES ('hola k8s-06');" >/dev/null

cat > "$WORK/adr.md" <<'EOF'
# ADR — Postgres via StatefulSet en K8s

- Para startup pequeña en AWS: usar RDS; no vale la pena operar un StatefulSet.
- Para banco con DBA: operador maduro (CloudNativePG) o DB fuera del cluster.
- Para edge sin managed: StatefulSet con operador y backups a storage externo.
- Un StatefulSet da los primitivos (identidad, PVC) pero no reemplaza un DBA.
- Decision depende de criticidad del dato, equipo y existencia de managed.
EOF

echo "SETUP OK; corre tests/validate.sh ahora, ANTES de limpiar."
