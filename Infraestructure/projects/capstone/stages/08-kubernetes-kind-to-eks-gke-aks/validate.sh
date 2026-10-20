#!/usr/bin/env bash
# Validador final de la stage 08. Agrega checks estructurales + delega
# a cada activity/tests/validate.sh.
#
# NOTE: deliberately NO `set -o pipefail`. Grep en pipelines con
# pipefail reportaria SIGPIPE (141) espurio cuando grep sale pronto.
set -eu

STAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
fail=0

note_ok()   { echo "  OK   -- $1"; }
note_fail() { echo "  FAIL -- $1"; fail=$((fail+1)); }

echo "== Validating capstone stage 08 (dir=$STAGE_DIR) =="

# --- Estructura basica ---
for f in \
  "README.md" \
  "kind/kind-config.yaml" \
  "k8s/base/kustomization.yaml" \
  "k8s/base/deployment.yaml" \
  "k8s/base/service.yaml" \
  "k8s/base/ingress.yaml" \
  "k8s/base/hpa.yaml" \
  "k8s/base/pdb.yaml" \
  "k8s/base/networkpolicy.yaml" \
  "k8s/base/serviceaccount.yaml" \
  "k8s/base/configmap.yaml" \
  "k8s/overlays/dev/kustomization.yaml" \
  "k8s/overlays/staging/kustomization.yaml" \
  "k8s/overlays/prod/kustomization.yaml" \
  "terraform/aws/eks/main.tf" \
  "terraform/gcp/gke/main.tf" \
  "terraform/azure/aks/main.tf" \
  "resources/links.md" \
  ; do
  if [ -f "$STAGE_DIR/$f" ]; then
    note_ok "existe $f"
  else
    note_fail "falta $f"
  fi
done

# --- kustomize/kubectl dry-run por overlay ---
for env in dev staging prod; do
  if command -v kubectl >/dev/null 2>&1; then
    if kubectl kustomize "$STAGE_DIR/k8s/overlays/$env" >/dev/null 2>&1; then
      note_ok "kubectl kustomize overlay=$env"
    else
      note_fail "kubectl kustomize overlay=$env"
    fi
  elif command -v kustomize >/dev/null 2>&1; then
    if kustomize build "$STAGE_DIR/k8s/overlays/$env" >/dev/null 2>&1; then
      note_ok "kustomize build overlay=$env"
    else
      note_fail "kustomize build overlay=$env"
    fi
  else
    echo "  SKIP -- ni kubectl ni kustomize disponibles para overlay=$env"
  fi
done

# --- Terraform validate por nube ---
if command -v terraform >/dev/null 2>&1; then
  for cloud in aws/eks gcp/gke azure/aks; do
    (
      cd "$STAGE_DIR/terraform/$cloud"
      terraform init -backend=false -input=false -no-color >/dev/null 2>&1
      terraform validate -no-color >/dev/null 2>&1
    ) && note_ok "terraform init+validate $cloud" || note_fail "terraform init+validate $cloud"
  done
else
  echo "  SKIP -- terraform no instalado"
fi

# --- Actividades ---
for act in "$STAGE_DIR"/activities/*/; do
  name="$(basename "$act")"
  ay="$act/activity.yaml"
  if [ ! -f "$ay" ]; then
    note_fail "actividad $name sin activity.yaml"
    continue
  fi
  grep -Eq "^id:\s*cap-08-" "$ay"                       && note_ok  "activity.yaml $name id=cap-08-*"            || note_fail "activity.yaml $name id no cap-08-*"
  grep -Eq "^technology:\s*capstone\s*$" "$ay"          && note_ok  "activity.yaml $name technology=capstone"    || note_fail "activity.yaml $name technology!=capstone"
  grep -Eq "^module:\s*08-kubernetes-kind-to-eks-gke-aks" "$ay" && note_ok "activity.yaml $name module OK" || note_fail "activity.yaml $name module incorrecto"
  vs="$act/tests/validate.sh"
  ss="$act/tests/smoke.sh"
  [ -x "$vs" ] && note_ok "actividad $name validate.sh ejecutable" || note_fail "actividad $name validate.sh no ejecutable"
  [ -x "$ss" ] && note_ok "actividad $name smoke.sh ejecutable"    || note_fail "actividad $name smoke.sh no ejecutable"
  grep -q "NO \`set -o pipefail\`" "$vs" 2>/dev/null && note_ok "actividad $name validate.sh tiene nota SIGPIPE" || note_fail "actividad $name validate.sh sin nota SIGPIPE"
done

# --- No ANALYSIS.md ---
if find "$STAGE_DIR" -name 'ANALYSIS.md' | grep -q .; then
  note_fail "ANALYSIS.md presente (prohibido por reglas)"
else
  note_ok "sin ANALYSIS.md"
fi

# --- No secretos reales ---
if grep -R -nE '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35})' "$STAGE_DIR" >/dev/null 2>&1; then
  note_fail "posible secret real detectado"
else
  note_ok "sin secretos reales plausibles"
fi

# --- Smoke doble (idempotencia) ---
for i in 1 2; do
  if bash "$STAGE_DIR/activities/01-kind-apply-and-smoke/tests/smoke.sh" >/dev/null 2>&1; then
    note_ok "smoke actividad 01 pase #$i"
  else
    note_fail "smoke actividad 01 pase #$i"
  fi
done

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s)."
exit 0
