#!/usr/bin/env bash
# Structural validation for helm-01-02-read-values-of-popular-chart.
# Checks that ANALYSIS.md exists with 3 chart sections, >=15 documented values
# (table rows), a comparison section, a justification section, and that the 3
# values-*.yaml source files were produced.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness - compare manually with
# solution/ANALYSIS-reference.md.

BASE="${1:-/tmp/helm-01-values}"
AN="$BASE/ANALYSIS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$AN" ]; then
  echo "FAIL: $AN does not exist. Student must produce it."
  exit 1
fi

# 3 chart sections.
for n in 1 2 3; do
  if grep -qiE "^##[[:space:]]+chart[[:space:]]+${n}" "$AN"; then
    echo "  OK   ANALYSIS.md has '## Chart ${n}' section"
  else
    echo "  FAIL ANALYSIS.md missing '## Chart ${n}' section"
    fail=$((fail+1))
  fi
done

# Comparison section.
if grep -qiE "^##[[:space:]]+comparaci|^##[[:space:]]+comparison" "$AN"; then
  echo "  OK   ANALYSIS.md has comparison section"
else
  echo "  FAIL ANALYSIS.md missing '## Comparacion' / '## Comparison' section"
  fail=$((fail+1))
fi

# Justification section (why values.yaml is the API/interface).
if grep -qiE "^##.*values\.yaml.*(ES|is).*(interfaz|api|interface)" "$AN"; then
  echo "  OK   ANALYSIS.md has 'values.yaml ES/IS the interface/API' justification section"
else
  echo "  FAIL ANALYSIS.md missing justification section ('## Por que values.yaml ES la interfaz' or similar)"
  fail=$((fail+1))
fi

# At least 15 documented values total: count data rows across tables.
# A data row has at least 4 pipes and does NOT begin with '|---' (separator) or
# '| Valor' (header).
rows=$(grep -cE '^\|[^|]*\|[^|]*\|[^|]*\|' "$AN" || true)
sep=$(grep -cE '^\|[[:space:]]*-+' "$AN" || true)
hdr=$(grep -ciE '^\|[[:space:]]*(valor|value)[[:space:]]*\|' "$AN" || true)
data=$((rows - sep - hdr))
if [ "$data" -ge 15 ]; then
  echo "  OK   ANALYSIS.md documents at least 15 values (counted $data data rows)"
else
  echo "  FAIL ANALYSIS.md documents only $data value rows (expected >=15, 5 per chart x 3)"
  fail=$((fail+1))
fi

# Must mention values.schema.json.
if grep -qi "values.schema.json" "$AN"; then
  echo "  OK   mentions values.schema.json (formalization of the API)"
else
  echo "  FAIL does not mention values.schema.json"
  fail=$((fail+1))
fi

# Must mention breaking change / major bump reasoning.
if grep -qiE "breaking change|major bump|rompe.*consumidor|rompe.*downstream" "$AN"; then
  echo "  OK   ANALYSIS.md discusses breaking-change implications of changing values keys"
else
  echo "  FAIL ANALYSIS.md does not discuss breaking-change implications"
  fail=$((fail+1))
fi

# The 3 chart names should appear.
for name in "ingress-nginx" "cert-manager" "prometheus"; do
  if grep -qi "$name" "$AN"; then
    echo "  OK   mentions chart '$name'"
  else
    echo "  WARN does not mention '$name' (ok if you chose a documented alternative)"
  fi
done

# Source values-*.yaml files should exist as evidence of helm show values.
yaml_count=$(find "$BASE" -maxdepth 1 -type f -name 'values-*.yaml' 2>/dev/null | wc -l | tr -d ' ')
if [ "$yaml_count" -ge 3 ]; then
  echo "  OK   found $yaml_count values-*.yaml source files in $BASE"
else
  echo "  FAIL found only $yaml_count values-*.yaml files in $BASE (expected >=3)"
  echo "       Run: helm show values <chart> > values-<slug>.yaml  (x3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility - compare with solution/ANALYSIS-reference.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ANALYSIS.md con solution/ANALYSIS-reference.md para autoevaluarte."
exit 0
