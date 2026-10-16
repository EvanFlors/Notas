#!/usr/bin/env bash
# Structural validation for plat-11-02-platform-product-canvas.
# Checks that CANVAS.md exists and contains the 7 required sections,
# a 7-row metrics table, mentions of DORA/SPACE/NPS, a financing model,
# at least 3 numbered antipatterns, and Goodhart / vanity metric.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-11-canvas}"
DOC="$BASE/CANVAS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi
echo "  OK   CANVAS.md exists"

# All 7 sections.
for n in 1 2 3 4 5 6 7; do
  if grep -qiE "^#+ *Secci[óo]n +${n}" "$DOC"; then
    echo "  OK   CANVAS.md has 'Seccion ${n}' heading"
  else
    echo "  FAIL CANVAS.md missing 'Seccion ${n}' heading"
    fail=$((fail+1))
  fi
done

# Section 3 subsections NOW / NEXT / LATER.
for sub in NOW NEXT LATER; do
  if grep -qiE "\\b${sub}\\b" "$DOC"; then
    echo "  OK   CANVAS.md mentions '${sub}'"
  else
    echo "  FAIL CANVAS.md missing '${sub}' subsection"
    fail=$((fail+1))
  fi
done

# Metrics table: 7 rows + header + separator = at least 9 pipe-lines.
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 9 ]; then
  echo "  OK   CANVAS.md metrics table has $rows pipe-lines (expected >=9)"
else
  echo "  FAIL CANVAS.md metrics table has only $rows pipe-lines (expected >=9 = header + sep + 7 rows)"
  fail=$((fail+1))
fi

# DORA must appear.
if grep -qi 'dora' "$DOC"; then
  echo "  OK   CANVAS.md mentions DORA"
else
  echo "  FAIL CANVAS.md does not mention DORA"
  fail=$((fail+1))
fi

# SPACE or at least one of its 5 dimensions.
if grep -qiE 'space|satisfaction|performance|activity|communication|efficiency' "$DOC"; then
  echo "  OK   CANVAS.md mentions SPACE (or a SPACE dimension)"
else
  echo "  FAIL CANVAS.md does not mention SPACE nor any SPACE dimension"
  fail=$((fail+1))
fi

# NPS.
if grep -qi 'nps' "$DOC"; then
  echo "  OK   CANVAS.md mentions NPS"
else
  echo "  FAIL CANVAS.md does not mention NPS"
  fail=$((fail+1))
fi

# Financing model.
if grep -qiE 'showback|chargeback|platform fee|central|financiamiento' "$DOC"; then
  echo "  OK   CANVAS.md mentions a financing model"
else
  echo "  FAIL CANVAS.md does not mention a financing model (showback/chargeback/fee/central)"
  fail=$((fail+1))
fi

# At least 3 numbered antipatterns.
ap_count=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    ap_count=$((ap_count+1))
  fi
done
if [ "$ap_count" -ge 3 ]; then
  echo "  OK   CANVAS.md has at least 3 numbered items"
else
  echo "  FAIL CANVAS.md has $ap_count numbered items (expected >=3)"
  fail=$((fail+1))
fi

# Goodhart / vanity metric.
if grep -qiE 'goodhart|vanity' "$DOC"; then
  echo "  OK   CANVAS.md references Goodhart / vanity metric"
else
  echo "  FAIL CANVAS.md does not mention Goodhart nor vanity metric"
  fail=$((fail+1))
fi

# At least 2 DORA metric names.
metric_hits=0
if grep -qiE 'deployment frequency|frecuencia de despliegue|deployment_frequency|\\bDF\\b' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'lead time|lead-time|lead_time|\\bLTC\\b' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'change failure|change_failure|\\bCFR\\b|tasa de fallo' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'recovery|restore|\\bFDRT\\b|\\bMTTR\\b' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if [ "$metric_hits" -ge 2 ]; then
  echo "  OK   CANVAS.md names at least 2 DORA metrics ($metric_hits/4)"
else
  echo "  FAIL CANVAS.md names only $metric_hits/4 DORA metrics (expected >=2)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara CANVAS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
