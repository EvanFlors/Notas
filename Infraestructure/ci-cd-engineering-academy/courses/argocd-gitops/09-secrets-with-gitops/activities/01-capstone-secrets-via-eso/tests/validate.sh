#!/usr/bin/env bash
# Validate argo-09-01-capstone-secrets-via-eso.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q` or `grep -c`; `grep -q` can short-circuit and cause SIGPIPE
# (exit 141) upstream, which pipefail would wrongly turn into a pipeline
# failure (false negative).

NS="${NAMESPACE:-capstone}"
STORE="${STORE:-capstone-store}"
ES="${ES:-capstone-db}"
SECRET="${SECRET:-capstone-db}"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: 'kubectl' no está instalado."
  exit 0
fi

if ! kubectl version --client >/dev/null 2>&1; then
  echo "SKIP: 'kubectl version --client' falló."
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible (crea el kind primero)."
  exit 0
fi

# --- Checks ------------------------------------------------------------------

# 1. CRDs ESO presentes
if kubectl api-resources 2>/dev/null | grep -q "externalsecrets.external-secrets.io"; then
  ok "CRDs de ESO instalados"
else
  bad "CRDs de ESO ausentes (helm install external-secrets)"
fi

# 2. Controller available
if kubectl -n external-secrets get deploy external-secrets >/dev/null 2>&1; then
  avail=$(kubectl -n external-secrets get deploy external-secrets \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  if [ "${avail:-0}" -ge 1 ]; then
    ok "Deployment external-secrets Available"
  else
    bad "Deployment external-secrets no Available (replicas=$avail)"
  fi
else
  bad "Deployment external-secrets no existe en ns external-secrets"
fi

# 3. Namespace capstone
if kubectl get ns "$NS" >/dev/null 2>&1; then
  ok "Namespace $NS existe"
else
  bad "Namespace $NS no existe"
fi

# 4. ClusterSecretStore Ready
if kubectl get clustersecretstore "$STORE" >/dev/null 2>&1; then
  ready=$(kubectl get clustersecretstore "$STORE" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [ "$ready" = "True" ]; then
    ok "ClusterSecretStore $STORE Ready"
  else
    bad "ClusterSecretStore $STORE no Ready (status=$ready)"
  fi
else
  bad "ClusterSecretStore $STORE no existe"
fi

# 5. ExternalSecret Ready
if kubectl -n "$NS" get externalsecret "$ES" >/dev/null 2>&1; then
  ready=$(kubectl -n "$NS" get externalsecret "$ES" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [ "$ready" = "True" ]; then
    ok "ExternalSecret $ES Ready"
  else
    bad "ExternalSecret $ES no Ready (status=$ready)"
  fi
else
  bad "ExternalSecret $ES no existe en ns $NS"
fi

# 6. Secret nativo con 2 keys (username, password)
if kubectl -n "$NS" get secret "$SECRET" >/dev/null 2>&1; then
  keys=$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data}' 2>/dev/null)
  has_user=0; has_pass=0
  echo "$keys" | grep -q '"username"' && has_user=1
  echo "$keys" | grep -q '"password"' && has_pass=1
  if [ "$has_user" = "1" ] && [ "$has_pass" = "1" ]; then
    ok "Secret $SECRET tiene keys username + password"
  else
    bad "Secret $SECRET no tiene las 2 keys (user=$has_user pass=$has_pass)"
  fi
else
  bad "Secret $SECRET no existe (ESO no lo materializó)"
fi

# 7. Rotación: valor actual del password es alguno de los esperados
if kubectl -n "$NS" get secret "$SECRET" >/dev/null 2>&1; then
  pw=$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data.password}' 2>/dev/null \
      | base64 -d 2>/dev/null)
  case "$pw" in
    s3cr3t-v1|s3cr3t-v2|s3cr3t-v*)
      ok "Password materializado ($pw)"
      ;;
    *)
      bad "Password materializado inesperado ('$pw')"
      ;;
  esac
fi

# --- Report ------------------------------------------------------------------
echo
echo "=== argo-09-01 validation ==="
printf "%b" "$report"
echo "-----"
echo "passed=$passed failed=$failed"

if [ "$failed" -eq 0 ]; then
  echo "All checks passed"
  exit 0
fi
exit 1
