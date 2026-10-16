#!/usr/bin/env bash
# Validate structure + minimum content of /tmp/obs15-02/COST-ANALYSIS.md.
# Only structure and presence of key artifacts; a human reviewer judges content.
#
# Note: deliberately NOT using `set -o pipefail` because `grep -q` on piped
# input can produce SIGPIPE and spuriously fail checks.
set -eu

TARGET="${TARGET:-/tmp/obs15-02/COST-ANALYSIS.md}"
PROFILE="${PROFILE:-/tmp/obs15-02/profile.yaml}"
passed=0
failed=0
report=""

check() {
  local name="$1" ok="$2" why="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — ${name}\n"; passed=$((passed + 1))
  else
    report+="FAIL — ${name}: ${why}\n"; failed=$((failed + 1))
  fi
}

if [ ! -f "$TARGET" ]; then
  echo "FAIL: no existe $TARGET."
  echo "Copia starter/profile.yaml a /tmp/obs15-02/ y escribe COST-ANALYSIS.md allí."
  exit 1
fi

# 1-6: required sections, in order
for header in \
  "## Resumen de la factura" \
  "## Top-3 contribuyentes" \
  "## Causa raíz" \
  "## Optimización 1" \
  "## Optimización 2" \
  "## Ahorro total estimado"
do
  has=0
  if grep -Fxq "$header" "$TARGET"; then
    has=1
  fi
  check "section present: '${header}'" "$has" "falta el header de nivel 2 exacto"
done

# 7: Resumen contains at least one $ figure
resumen=$(awk '/^## Resumen de la factura/,/^## Top-3 contribuyentes/' "$TARGET")
if printf "%s" "$resumen" | grep -qE '\$[0-9]'; then
  check "'Resumen de la factura' contains a \$ figure" 1 ""
else
  check "'Resumen de la factura' contains a \$ figure" 0 \
        "sin cifras \$ en el resumen"
fi

# 8-9: each optimization must contain a $ figure
opt1=$(awk '/^## Optimización 1/,/^## Optimización 2/' "$TARGET")
if printf "%s" "$opt1" | grep -qE '\$[0-9]'; then
  check "'Optimización 1' quantifies a \$ delta" 1 ""
else
  check "'Optimización 1' quantifies a \$ delta" 0 "sin cifra \$"
fi

opt2=$(awk '/^## Optimización 2/,/^## Ahorro total estimado/' "$TARGET")
if printf "%s" "$opt2" | grep -qE '\$[0-9]'; then
  check "'Optimización 2' quantifies a \$ delta" 1 ""
else
  check "'Optimización 2' quantifies a \$ delta" 0 "sin cifra \$"
fi

# 10: Ahorro total contains $ and %
ahorro=$(awk '/^## Ahorro total estimado/,0' "$TARGET")
if printf "%s" "$ahorro" | grep -qE '\$[0-9]' && printf "%s" "$ahorro" | grep -q '%'; then
  check "'Ahorro total estimado' contains \$ and %" 1 ""
else
  check "'Ahorro total estimado' contains \$ and %" 0 \
        "incluye cifra \$ y porcentaje % del ahorro"
fi

# 11: at least 3 service names from the profile are mentioned (in top-3 section ideally)
if [ -f "$PROFILE" ]; then
  mentioned=0
  svcs=$(awk '/^  - name:/{print $3}' "$PROFILE")
  for svc in $svcs; do
    if grep -qw "$svc" "$TARGET"; then
      mentioned=$((mentioned + 1))
    fi
  done
  if [ "$mentioned" -ge 3 ]; then
    check "mentions >= 3 services from profile" 1 ""
  else
    check "mentions >= 3 services from profile" 0 "sólo $mentioned servicios"
  fi
else
  check "mentions >= 3 services from profile" 0 "no se encontró $PROFILE para validar nombres"
fi

# 12: minimum substantive length
nelines=$(grep -cE '[^[:space:]]' "$TARGET" || true)
if [ "$nelines" -ge 25 ]; then
  check "document has substantive content (>= 25 non-empty lines)" 1 ""
else
  check "document has substantive content (>= 25 non-empty lines)" 0 \
        "sólo $nelines líneas no vacías; amplía el análisis"
fi

echo "== obs-15-02 validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/12 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
