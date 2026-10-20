#!/usr/bin/env bash
# Validate k8s-06-02-cronjob-flaky-fix.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# kubectl output into `grep -q`; if grep matches early the upstream may be
# SIGPIPEd (exit 141) and pipefail would spuriously fail the check.

WORK="${WORK_DIR:-/tmp/k8s-06-02}"
NS="${NS:-cronjob-lab}"
NAME="${NAME:-slow-cleanup}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v kubectl >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'kubectl' no está instalado.
  https://kubernetes.io/docs/tasks/tools/
EOF
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible (kubectl cluster-info falla)."
  exit 0
fi

echo "== Validando CronJob $NAME en $NS =="

# --- 1. CronJob existe ---
if ! kubectl -n "$NS" get cronjob "$NAME" >/dev/null 2>&1; then
  bad "CronJob '$NAME' no existe en ns '$NS'"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi
ok "CronJob '$NAME' existe"

# --- 2. schedule intacto ---
sched="$(kubectl -n "$NS" get cronjob "$NAME" -o jsonpath='{.spec.schedule}' 2>/dev/null)"
if [ "$sched" = "*/1 * * * *" ]; then
  ok "schedule intacto ('*/1 * * * *')"
else
  bad "schedule cambió a '$sched' (debe seguir siendo '*/1 * * * *')"
fi

# --- 3. concurrencyPolicy = Forbid o Replace ---
policy="$(kubectl -n "$NS" get cronjob "$NAME" -o jsonpath='{.spec.concurrencyPolicy}' 2>/dev/null)"
case "$policy" in
  Forbid|Replace)
    ok "concurrencyPolicy = '$policy' (ok)"
    ;;
  Allow|"")
    bad "concurrencyPolicy = '$policy' — debe ser 'Forbid' o 'Replace'"
    ;;
  *)
    bad "concurrencyPolicy = '$policy' — valor inesperado"
    ;;
esac

# --- 4. startingDeadlineSeconds dentro de [10, 300] ---
sds="$(kubectl -n "$NS" get cronjob "$NAME" -o jsonpath='{.spec.startingDeadlineSeconds}' 2>/dev/null)"
if [ -z "$sds" ]; then
  bad "startingDeadlineSeconds no definido (fija entre 10 y 300)"
elif ! echo "$sds" | grep -qE '^[0-9]+$'; then
  bad "startingDeadlineSeconds no es un entero ('$sds')"
elif [ "$sds" -lt 10 ] || [ "$sds" -gt 300 ]; then
  bad "startingDeadlineSeconds=$sds fuera de rango [10, 300]"
else
  ok "startingDeadlineSeconds=$sds en rango [10, 300]"
fi

# --- 5. diagnostico.md ---
diag="$WORK/diagnostico.md"
if [ ! -f "$diag" ]; then
  bad "no existe $diag"
else
  ok "diagnostico.md existe"
  if grep -qi 'concurrencyPolicy' "$diag"; then
    ok "diagnostico.md menciona concurrencyPolicy"
  else
    bad "diagnostico.md no menciona 'concurrencyPolicy'"
  fi
fi

# --- 6. Comando no fue tocado (sigue siendo 'sleep 90') ---
cmd="$(kubectl -n "$NS" get cronjob "$NAME" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command}' 2>/dev/null)"
if echo "$cmd" | grep -q 'sleep 90'; then
  ok "comando intacto (sigue teniendo 'sleep 90')"
else
  bad "comando parece haber cambiado — no era parte del fix (cmd='$cmd')"
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
