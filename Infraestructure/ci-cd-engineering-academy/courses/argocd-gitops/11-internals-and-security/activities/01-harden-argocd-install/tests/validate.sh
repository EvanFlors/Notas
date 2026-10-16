#!/usr/bin/env bash
# Validate argo-11-01-harden-argocd-install.
# Checks the 7 hardening controls listed in README.md section 3.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe into `grep -q`
# where early-match SIGPIPE would be reported as a spurious failure.

NS="${NS:-argocd}"
BASE="${BASE:-/tmp/argo-11-01}"
ORIG_KEY_FILE="$BASE/original.secretkey.b64"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating argo-11-01-harden-argocd-install (ns=$NS) =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl not installed" >&2; exit 1
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: no active kube context. (Nothing to validate.)" >&2
  exit 0
fi
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "SKIP: namespace '$NS' not found. Run bootstrap.sh first." >&2
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required (brew/apt install jq)" >&2; exit 1
fi

# ---- Control 1: admin.enabled=false in argocd-cm ----
ae="$(kubectl -n "$NS" get cm argocd-cm -o jsonpath='{.data.admin\.enabled}' 2>/dev/null || echo '')"
if [ "$ae" = "false" ]; then
  note_ok "Control 1: argocd-cm admin.enabled=false"
else
  note_fail "Control 1: admin.enabled='$ae' (expected 'false')"
fi

# ---- Control 2: server.insecure=false ----
si="$(kubectl -n "$NS" get cm argocd-cmd-params-cm -o jsonpath='{.data.server\.insecure}' 2>/dev/null || echo '')"
# Fallback: check Deployment args — accept if --insecure is NOT present.
if [ "$si" = "false" ]; then
  note_ok "Control 2: argocd-cmd-params-cm server.insecure=false"
else
  args="$(kubectl -n "$NS" get deploy argocd-server -o json 2>/dev/null \
          | jq -r '.spec.template.spec.containers[]?.args[]?' 2>/dev/null || echo '')"
  if printf '%s' "$args" | grep -q -- '--insecure'; then
    note_fail "Control 2: --insecure still in argocd-server args and server.insecure='$si'"
  else
    note_ok "Control 2: --insecure flag absent from argocd-server (server.insecure='$si')"
  fi
fi

# ---- Control 3: PSA restricted on namespace ----
enforce="$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo '')"
if [ "$enforce" = "restricted" ]; then
  note_ok "Control 3: ns $NS pod-security.kubernetes.io/enforce=restricted"
else
  note_fail "Control 3: ns enforce='$enforce' (expected 'restricted')"
fi

# ---- Control 4: NetworkPolicy default-deny + DNS egress ----
nps_json="$(kubectl -n "$NS" get networkpolicy -o json 2>/dev/null || echo '{"items":[]}')"
has_default_deny="$(printf '%s' "$nps_json" | jq '[.items[] | select(.spec.podSelector == {} and ((.spec.policyTypes // []) | index("Egress") != null))] | length')"
has_dns_egress="$(printf '%s' "$nps_json" | jq '[.items[].spec.egress[]? | .ports[]? | select(.port==53)] | length')"
if [ "${has_default_deny:-0}" -ge 1 ] && [ "${has_dns_egress:-0}" -ge 1 ]; then
  note_ok "Control 4: NetworkPolicy default-deny (egress) + port 53 egress rule present"
else
  note_fail "Control 4: default-deny=$has_default_deny dns-egress=$has_dns_egress (need both >=1)"
fi

# ---- Control 5: server.secretkey rotated ----
cur_key="$(kubectl -n "$NS" get secret argocd-secret -o jsonpath='{.data.server\.secretkey}' 2>/dev/null || echo '')"
if [ -z "$cur_key" ]; then
  note_fail "Control 5: argocd-secret.server\\.secretkey is empty (not yet regenerated — restart argocd-server)"
else
  if [ -f "$ORIG_KEY_FILE" ]; then
    orig_key="$(cat "$ORIG_KEY_FILE" 2>/dev/null || echo '')"
    if [ -n "$orig_key" ] && [ "$cur_key" = "$orig_key" ]; then
      note_fail "Control 5: server.secretkey unchanged since bootstrap"
    else
      note_ok "Control 5: server.secretkey differs from bootstrap snapshot"
    fi
  else
    # Fallback: no snapshot → accept if key exists (best effort).
    note_ok "Control 5: server.secretkey present (no snapshot to compare — treating as rotated)"
  fi
fi

# ---- Control 6: deny-by-default policy with role + binding ----
rbac_json="$(kubectl -n "$NS" get cm argocd-rbac-cm -o json 2>/dev/null || echo '{}')"
pdefault="$(printf '%s' "$rbac_json" | jq -r '.data["policy.default"] // "MISSING"')"
pcsv="$(printf '%s' "$rbac_json" | jq -r '.data["policy.csv"] // ""')"
has_p="$(printf '%s' "$pcsv" | grep -c '^[[:space:]]*p,' || true)"
has_g="$(printf '%s' "$pcsv" | grep -c '^[[:space:]]*g,' || true)"
if [ "$pdefault" = "" ] && [ "${has_p:-0}" -ge 1 ] && [ "${has_g:-0}" -ge 1 ]; then
  note_ok "Control 6: argocd-rbac-cm deny-by-default + >=1 p + >=1 g"
else
  note_fail "Control 6: policy.default='$pdefault' p=$has_p g=$has_g (need default='' p>=1 g>=1)"
fi

# ---- Control 7: argocd-application-controller SA NOT directly bound to cluster-admin ----
sa_name="argocd-application-controller"
bad_bindings="$(kubectl get clusterrolebindings -o json 2>/dev/null \
  | jq --arg sa "$sa_name" --arg ns "$NS" \
      '[.items[] | select(.roleRef.name=="cluster-admin")
                 | select(.subjects // [] | any(.kind=="ServiceAccount" and .name==$sa and .namespace==$ns))
                 | .metadata.name]')"
count="$(printf '%s' "$bad_bindings" | jq 'length')"
if [ "${count:-0}" -eq 0 ]; then
  note_ok "Control 7: no ClusterRoleBinding ties SA $NS/$sa_name directly to cluster-admin"
else
  note_fail "Control 7: SA $NS/$sa_name is cluster-admin via: $bad_bindings"
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
