#!/usr/bin/env bash
# Structural validation for obs-01-01-when-not-prometheus.
# Checks that ANALYSIS.md exists and contains the required sections, keywords,
# alternatives and 7 numbered criteria in the synthesis.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

BASE="${1:-/tmp/obs-01-when-not}"
DOC="$BASE/ANALYSIS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# All 4 scenarios must appear as headings.
for n in 1 2 3 4; do
  if grep -qiE "^#+ *Escenario +${n}" "$DOC"; then
    echo "  OK   ANALYSIS.md has 'Escenario ${n}' heading"
  else
    echo "  FAIL ANALYSIS.md missing 'Escenario ${n}' heading"
    fail=$((fail+1))
  fi
done

# Each scenario must mention a decision marker (SI, NO, parcial).
decisions=$(grep -cEi 'Decisi[óo]n[^A-Za-z0-9]*(prometheus)?' "$DOC")
if [ "$decisions" -ge 4 ]; then
  echo "  OK   ANALYSIS.md has at least 4 'Decision' markers ($decisions found)"
else
  echo "  FAIL ANALYSIS.md has only $decisions 'Decision' markers (expected >=4)"
  fail=$((fail+1))
fi

# Must mention Pushgateway at least once (link to §4.5 of the lesson).
if grep -qi 'pushgateway' "$DOC"; then
  echo "  OK   mentions Pushgateway"
else
  echo "  FAIL does not mention Pushgateway"
  fail=$((fail+1))
fi

# Must mention 'pull' (model mental explicito).
if grep -qiE '\bpull\b' "$DOC"; then
  echo "  OK   mentions pull model"
else
  echo "  FAIL does not mention pull model"
  fail=$((fail+1))
fi

# Must name at least 2 alternatives from a canonical list.
alts_found=0
for alt in "victoriametrics" "mimir" "thanos" "influx" "cloudwatch" "datadog" \
           "warehouse" "bigquery" "snowflake" "redshift" "clickhouse" \
           "statsd" "otlp" "opentelemetry" "mqtt" "loki" "elastic" "kafka"; do
  if grep -qi "$alt" "$DOC"; then
    alts_found=$((alts_found+1))
  fi
done
if [ "$alts_found" -ge 2 ]; then
  echo "  OK   ANALYSIS.md names at least 2 alternatives ($alts_found found)"
else
  echo "  FAIL ANALYSIS.md names only $alts_found alternatives (expected >=2)"
  fail=$((fail+1))
fi

# Must have the Sintesis section.
if grep -qiE '^#+ *S[íi]ntesis' "$DOC"; then
  echo "  OK   has 'Síntesis' section"
else
  echo "  FAIL missing 'Síntesis' section"
  fail=$((fail+1))
fi

# Must have 7 numbered criteria questions in the synthesis (1. through 7.).
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   ANALYSIS.md has at least 7 numbered criteria"
else
  echo "  FAIL ANALYSIS.md has $answers_found numbered criteria (expected >=7)"
  fail=$((fail+1))
fi

# Must mention 'cardinal' (cardinalidad) OR 'retenci' (retención) at least once.
if grep -qiE 'cardinal|retenci' "$DOC"; then
  echo "  OK   mentions cardinality/retention as a decision criterion"
else
  echo "  FAIL no mention of cardinality nor retention"
  fail=$((fail+1))
fi

# Must mention 'IoT' or 'NAT' (escenario 3).
if grep -qiE '\biot\b|\bnat\b' "$DOC"; then
  echo "  OK   mentions IoT/NAT constraint"
else
  echo "  FAIL no mention of IoT or NAT constraint"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara ANALYSIS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
