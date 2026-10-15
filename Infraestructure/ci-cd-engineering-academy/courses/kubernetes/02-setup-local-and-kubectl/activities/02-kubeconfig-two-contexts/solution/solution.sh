#!/usr/bin/env bash
# Solution de referencia para k8s-02-02-kubeconfig-two-contexts.
# Deliberadamente SIN `set -o pipefail` (ver nota en validate.sh).
set -eu

WORK="/tmp/k8s-02-02"
mkdir -p "$WORK"

for env in dev stg; do
  cluster="lab-$env"
  ns="apps-$env"
  ctx="kind-$cluster"

  if ! kind get clusters 2>/dev/null | grep -qx "$cluster"; then
    kind create cluster --name "$cluster"
  fi

  # Namespace idempotente.
  kubectl --context "$ctx" create namespace "$ns" --dry-run=client -o yaml \
    | kubectl --context "$ctx" apply -f -

  # Namespace por default del contexto.
  kubectl config set-context "$ctx" --namespace="$ns"

  # ConfigMap marker.
  cat <<YAML | kubectl --context "$ctx" -n "$ns" apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-marker
data:
  env: "$env"
YAML
done

# Switch script.
cat > "$WORK/switch.sh" <<'EOF'
#!/usr/bin/env bash
# Cambia entre kind-lab-dev y kind-lab-stg y confirma dónde quedaste.
set -eu

if [ "$#" -ne 1 ] || { [ "$1" != "dev" ] && [ "$1" != "stg" ]; }; then
  echo "uso: $0 <dev|stg>" >&2
  exit 2
fi

env="$1"
ctx="kind-lab-$env"
ns="apps-$env"

kubectl config use-context "$ctx" >/dev/null
current="$(kubectl config current-context)"
current_ns="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
marker="$(kubectl -n "$ns" get cm env-marker -o jsonpath='{.data.env}' 2>/dev/null || echo '<missing>')"

printf "context : %s\n" "$current"
printf "ns      : %s\n" "$current_ns"
printf "env     : %s\n" "$marker"
EOF
chmod +x "$WORK/switch.sh"

echo
echo "Solution aplicada. Prueba:"
echo "  $WORK/switch.sh dev"
echo "  $WORK/switch.sh stg"
echo "Correr validator:"
echo "  bash courses/kubernetes/02-setup-local-and-kubectl/activities/02-kubeconfig-two-contexts/tests/validate.sh"
