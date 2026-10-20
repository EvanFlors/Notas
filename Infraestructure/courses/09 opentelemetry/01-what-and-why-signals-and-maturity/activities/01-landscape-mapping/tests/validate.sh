#!/usr/bin/env bash
# Structural validation for otel-01-01-landscape-mapping.
# Checks that LANDSCAPE.md exists and contains the required sections,
# the classification table, the before/after diagram cues, and the 5 claims.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

BASE="${1:-/tmp/otel-01-landscape}"
DOC="$BASE/LANDSCAPE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required top-level sections (A, B, C).
if grep -qiE '^#+ *(Secci[óo]n +A|Clasificaci[óo]n)' "$DOC"; then
  echo "  OK   LANDSCAPE.md has Section A (Clasificacion)"
else
  echo "  FAIL LANDSCAPE.md missing Section A / Clasificacion heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +B|Diagrama|Antes|Despu[eé]s)' "$DOC"; then
  echo "  OK   LANDSCAPE.md has Section B (Diagrama antes/despues)"
else
  echo "  FAIL LANDSCAPE.md missing Section B / Diagrama heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +C|Afirmaciones)' "$DOC"; then
  echo "  OK   LANDSCAPE.md has Section C (Afirmaciones)"
else
  echo "  FAIL LANDSCAPE.md missing Section C / Afirmaciones heading"
  fail=$((fail+1))
fi

# Table must have at least 5 classification rows: look for pipes '|' at least 7 times
# (header + separator + 5 rows = 7 lines starting with '|').
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 7 ]; then
  echo "  OK   LANDSCAPE.md has at least 5 table rows ($rows pipe-lines found)"
else
  echo "  FAIL LANDSCAPE.md table has only $rows pipe-lines (expected >=7)"
  fail=$((fail+1))
fi

# Must mention OTel / OpenTelemetry.
if grep -qiE 'otel|opentelemetry' "$DOC"; then
  echo "  OK   mentions OTel / OpenTelemetry"
else
  echo "  FAIL does not mention OTel / OpenTelemetry"
  fail=$((fail+1))
fi

# Must mention Collector.
if grep -qi 'collector' "$DOC"; then
  echo "  OK   mentions Collector"
else
  echo "  FAIL does not mention Collector"
  fail=$((fail+1))
fi

# Must mention at least 'receiver' or 'exporter' (to show understanding
# of how pre-OTel tools coexist via Collector).
if grep -qiE 'receiver|exporter' "$DOC"; then
  echo "  OK   mentions receiver/exporter"
else
  echo "  FAIL does not mention receiver nor exporter"
  fail=$((fail+1))
fi

# Must name at least 4 canonical pieces (Prometheus, Jaeger, Zipkin, Loki,
# Grafana, Fluentbit, Datadog, etc.) — proxy for breadth of landscape.
pieces=0
for p in "prometheus" "jaeger" "zipkin" "loki" "grafana" "fluentbit" \
         "vector" "datadog" "honeycomb" "new relic" "newrelic"; do
  if grep -qi "$p" "$DOC"; then
    pieces=$((pieces+1))
  fi
done
if [ "$pieces" -ge 4 ]; then
  echo "  OK   LANDSCAPE.md names at least 4 canonical pieces ($pieces found)"
else
  echo "  FAIL LANDSCAPE.md names only $pieces canonical pieces (expected >=4)"
  fail=$((fail+1))
fi

# Must mention the 'OTLP' wire protocol.
if grep -qi 'otlp' "$DOC"; then
  echo "  OK   mentions OTLP"
else
  echo "  FAIL does not mention OTLP"
  fail=$((fail+1))
fi

# Section C: must contain at least 5 numbered items (1. .. 5.).
claims_found=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    claims_found=$((claims_found+1))
  fi
done
if [ "$claims_found" -ge 5 ]; then
  echo "  OK   LANDSCAPE.md has at least 5 numbered claims"
else
  echo "  FAIL LANDSCAPE.md has $claims_found numbered claims (expected >=5)"
  fail=$((fail+1))
fi

# Must have at least one of the classification keywords.
if grep -qiE 'reemplaza|convive|fuera-de-scope|fuera de scope'  "$DOC"; then
  echo "  OK   uses classification vocabulary (reemplaza/convive/fuera-de-scope)"
else
  echo "  FAIL does not use classification vocabulary"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara LANDSCAPE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
