#!/usr/bin/env bash
# Validate plat-09-01: 5 checks (XRD, Composition, Claim Ready, Namespace,
# Quota+NetworkPolicy).
#
# Note: deliberately NO `set -o pipefail` because several checks use
# `kubectl ... | grep -q ...` and pipefail would spuriously report the
# SIGPIPE (exit 141) produced when grep exits on first match as a failure.
set -eu

TEAM_NS="${TEAM_NS:-team-student}"
TARGET_NS="${TARGET_NS:-student-ns}"
CLAIM="${CLAIM:-student-claim}"
XRD="xnamespaceproducts.platform.io"
COMP="xnamespaceproducts.k8s-native"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating plat-09-01 (claim=$CLAIM in $TEAM_NS -> $TARGET_NS) =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no instalado"; exit 0
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: kubectl no puede alcanzar apiserver"; exit 0
fi
if ! kubectl get crd compositeresourcedefinitions.apiextensions.crossplane.io >/dev/null 2>&1; then
  echo "SKIP: Crossplane no instalado. Ejecuta tests/setup.sh primero."
  exit 0
fi

# ---- Check 1: XRD Established ----
est="$(kubectl get xrd "$XRD" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || echo '')"
if [ "$est" = "True" ]; then
  note_ok "XRD $XRD Established=True"
else
  note_fail "XRD $XRD no Established (status='$est')"
fi

# ---- Check 2: Composition existe ----
if kubectl get composition "$COMP" >/dev/null 2>&1; then
  note_ok "Composition $COMP existe"
else
  note_fail "Composition $COMP no existe"
fi

# ---- Check 3: Claim Ready=True (espera hasta 90s a reconcile) ----
ready=""
for i in $(seq 1 18); do
  ready="$(kubectl -n "$TEAM_NS" get namespaceproductclaim "$CLAIM" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo '')"
  [ "$ready" = "True" ] && break
  sleep 5
done
if [ "$ready" = "True" ]; then
  note_ok "Claim $CLAIM en $TEAM_NS Ready=True"
else
  note_fail "Claim $CLAIM en $TEAM_NS no Ready (status='$ready')"
fi

# ---- Check 4: Namespace materializado con label managed-by=crossplane ----
mb="$(kubectl get ns "$TARGET_NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null || echo '')"
if [ "$mb" = "crossplane" ]; then
  note_ok "Namespace $TARGET_NS existe con managed-by=crossplane"
else
  note_fail "Namespace $TARGET_NS no existe o sin label (managed-by='$mb')"
fi

# ---- Check 5: ResourceQuota + NetworkPolicy en el namespace ----
rq_ok=0; np_ok=0
if kubectl -n "$TARGET_NS" get resourcequota "${TARGET_NS}-quota" >/dev/null 2>&1; then
  rq_ok=1
fi
if kubectl -n "$TARGET_NS" get networkpolicy "${TARGET_NS}-deny-all" >/dev/null 2>&1; then
  np_ok=1
fi
if [ "$rq_ok" -eq 1 ] && [ "$np_ok" -eq 1 ]; then
  note_ok "ResourceQuota ${TARGET_NS}-quota + NetworkPolicy ${TARGET_NS}-deny-all presentes"
else
  note_fail "ResourceQuota=${rq_ok} NetworkPolicy=${np_ok} en $TARGET_NS (ambos esperados)"
fi

echo
echo "---- report ----"
printf "%b" "$report"
echo "passed=$passed  failed=$failed"
if [ "$failed" -eq 0 ]; then
  echo "ALL CHECKS PASSED (5/5)"
  exit 0
fi
exit 1
