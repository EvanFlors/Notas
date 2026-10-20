#!/usr/bin/env bash
# Validate argo-09-02-tradeoffs-adr.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`; `grep -q` can close the pipe early and cause SIGPIPE
# upstream, which pipefail would turn into a false negative.

# The student's ADR.md is expected in the activity root, next to this tests/.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ADR="${ADR_PATH:-$HERE/ADR.md}"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# 1. ADR.md exists
if [ -f "$ADR" ]; then
  ok "ADR.md existe en $ADR"
else
  # Fallback: a solution ADR may be present under solution/
  if [ -f "$HERE/solution/ADR.md" ] && [ "${ACCEPT_SOLUTION:-0}" = "1" ]; then
    ADR="$HERE/solution/ADR.md"
    ok "Usando solution/ADR.md (ACCEPT_SOLUTION=1)"
  else
    bad "ADR.md no existe (crea $ADR a partir de starter/ADR_TEMPLATE.md)"
    echo
    echo "=== argo-09-02 validation ==="
    printf "%b" "$report"
    echo "-----"
    echo "passed=$passed failed=$failed"
    exit 1
  fi
fi

# 2. Las tres orgs decididas
for n in 1 2 3; do
  if grep -q "## Org $n" "$ADR"; then
    ok "Sección 'Org $n' presente"
  else
    bad "Falta sección '## Org $n'"
  fi
done

# 3. Revisit presente
if grep -q "Revisit" "$ADR"; then
  ok "Revisit fecha presente"
else
  bad "Falta 'Revisit:' con fecha"
fi

# 4. Decision table presente (nombres de las 5 estrategias en una tabla)
hits=0
for name in "SOPS" "Sealed Secrets" "ESO" "CSI" "Vault"; do
  if grep -q "$name" "$ADR"; then
    hits=$((hits+1))
  fi
done
if [ "$hits" -ge 5 ]; then
  ok "Decision table menciona las 5 estrategias"
else
  bad "Decision table incompleta ($hits/5 estrategias mencionadas)"
fi

# 5. Rotation plan presente
if grep -q -i "Rotation plan" "$ADR"; then
  ok "Rotation plan presente"
else
  bad "Falta 'Rotation plan'"
fi

# 6. No valores secretos literales obvios (heurística suave)
leaked=0
for pat in "BEGIN RSA" "AKIA[0-9A-Z]\\{16\\}" "ghp_[A-Za-z0-9]\\{30\\}"; do
  if grep -qE "$pat" "$ADR" 2>/dev/null; then
    leaked=1
  fi
done
if [ "$leaked" = "0" ]; then
  ok "No se detectaron patrones de secretos reales"
else
  bad "Posible secreto literal en el ADR (revisa patrones AWS/RSA/GitHub token)"
fi

echo
echo "=== argo-09-02 validation ==="
printf "%b" "$report"
echo "-----"
echo "passed=$passed failed=$failed"

if [ "$failed" -eq 0 ]; then
  echo "All checks passed"
  exit 0
fi
exit 1
