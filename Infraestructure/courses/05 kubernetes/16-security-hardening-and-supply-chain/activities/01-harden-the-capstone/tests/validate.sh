#!/usr/bin/env bash
# Validate k8s-16-01-harden-the-capstone.
#
# Checks 7 controles via `kubectl ... jsonpath` sobre un Deployment admitido,
# ademas de la prueba negativa (apiserver debe rechazar un Pod inseguro).
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks hacen
# `kubectl ... | grep -q ...` y pipefail reportaria SIGPIPE (141) espurio
# cuando grep sale al primer match.

NS="${NS:-app}"
DEPLOY="${DEPLOY:-web}"
BAD_POD_PATH="${BAD_POD_PATH:-/tmp/k8s-16-01/work/pod-bad.yaml}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating k8s-16-01-harden-the-capstone (ns=$NS, deploy=$DEPLOY) =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl no instalado" >&2
  exit 1
fi

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "FAIL: kubectl no puede alcanzar al apiserver (contexto activo?)" >&2
  exit 1
fi

# ---- Check 1: namespace existe y tiene enforce=restricted ----
enforce="$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo '')"
if [ "$enforce" = "restricted" ]; then
  note_ok "Namespace '$NS' con pod-security.kubernetes.io/enforce=restricted"
else
  note_fail "Namespace '$NS' enforce='$enforce' (esperado 'restricted')"
fi

# ---- Check 2: Deployment existe y esta Available ----
avail="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo '')"
if [ "$avail" = "True" ]; then
  note_ok "Deployment $NS/$DEPLOY Available=True"
else
  note_fail "Deployment $NS/$DEPLOY no Available (status: '$avail')"
fi

# Precalcula el PodSpec del template para el resto de checks.
pod_json="$(kubectl -n "$NS" get deploy "$DEPLOY" -o json 2>/dev/null || echo '{}')"

# ---- Check 3: pod.securityContext.runAsNonRoot=true ----
rnr="$(printf '%s' "$pod_json" | jq -r '.spec.template.spec.securityContext.runAsNonRoot // false')"
if [ "$rnr" = "true" ]; then
  note_ok "Pod securityContext.runAsNonRoot=true"
else
  note_fail "Pod securityContext.runAsNonRoot=$rnr (esperado true)"
fi

# ---- Check 4: container.securityContext fields ----
csc="$(printf '%s' "$pod_json" | jq -r '.spec.template.spec.containers[0].securityContext')"
ape="$(printf '%s' "$csc" | jq -r '.allowPrivilegeEscalation // true')"
rof="$(printf '%s' "$csc" | jq -r '.readOnlyRootFilesystem // false')"
drop="$(printf '%s' "$csc" | jq -r '.capabilities.drop // [] | tostring')"
runas="$(printf '%s' "$csc" | jq -r '.runAsUser // (.spec.template.spec.securityContext.runAsUser // 0)')"
# Combina para un check compacto.
if [ "$ape" = "false" ] && [ "$rof" = "true" ] && printf '%s' "$drop" | grep -q "ALL"; then
  note_ok "Container securityContext: APE=false, ROFS=true, drop includes ALL"
else
  note_fail "Container securityContext laxo: APE=$ape ROFS=$rof drop=$drop"
fi

# ---- Check 5: runAsUser numerico y >=1000 ----
if [ -n "$runas" ] && [ "$runas" -ge 1000 ] 2>/dev/null; then
  note_ok "runAsUser=$runas (>=1000)"
else
  # Fallback: leerlo del Pod securityContext si no estaba en el container.
  runas2="$(printf '%s' "$pod_json" | jq -r '.spec.template.spec.securityContext.runAsUser // 0')"
  if [ "$runas2" -ge 1000 ] 2>/dev/null; then
    note_ok "Pod runAsUser=$runas2 (>=1000)"
  else
    note_fail "runAsUser debe ser numerico >=1000 (visto: container=$runas pod=$runas2)"
  fi
fi

# ---- Check 6: seccompProfile RuntimeDefault (Pod o container) ----
sc_pod="$(printf '%s' "$pod_json" | jq -r '.spec.template.spec.securityContext.seccompProfile.type // ""')"
sc_ctr="$(printf '%s' "$csc" | jq -r '.seccompProfile.type // ""')"
if [ "$sc_pod" = "RuntimeDefault" ] || [ "$sc_ctr" = "RuntimeDefault" ]; then
  note_ok "seccompProfile.type=RuntimeDefault"
else
  note_fail "seccompProfile.type no es RuntimeDefault (pod='$sc_pod' ctr='$sc_ctr')"
fi

# ---- Check 7: automountServiceAccountToken=false ----
amt="$(printf '%s' "$pod_json" | jq -r '.spec.template.spec.automountServiceAccountToken // true')"
if [ "$amt" = "false" ]; then
  note_ok "automountServiceAccountToken=false"
else
  note_fail "automountServiceAccountToken=$amt (esperado false)"
fi

# ---- Check negativo: pod-bad.yaml debe ser rechazado por PSA ----
if [ -f "$BAD_POD_PATH" ]; then
  out="$(kubectl apply --dry-run=server -f "$BAD_POD_PATH" 2>&1 || true)"
  if printf '%s' "$out" | grep -q 'violates PodSecurity'; then
    report+="  OK   -- Prueba negativa: pod-bad.yaml rechazado por PSA\n"
  else
    report+="  WARN -- Prueba negativa: apiserver no rechazo con 'violates PodSecurity'. Salida:\n$out\n"
  fi
else
  report+="  SKIP -- pod-bad.yaml no encontrado en $BAD_POD_PATH\n"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total controles OK (requeridos: 7)."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
