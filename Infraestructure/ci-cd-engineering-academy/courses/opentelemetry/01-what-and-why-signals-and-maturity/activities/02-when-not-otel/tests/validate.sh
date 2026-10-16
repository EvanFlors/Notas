#!/usr/bin/env bash
# Structural validation for otel-01-02-when-not-otel.
# Checks that DECISIONS.md exists and contains the required scenarios,
# decision markers, alternatives, and the synthesis with 7 numbered criteria.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

BASE="${1:-/tmp/otel-01-when-not}"
DOC="$BASE/DECISIONS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# All 4 scenarios must appear as headings.
for n in 1 2 3 4; do
  if grep -qiE "^#+ *Escenario +${n}" "$DOC"; then
    echo "  OK   DECISIONS.md has 'Escenario ${n}' heading"
  else
    echo "  FAIL DECISIONS.md missing 'Escenario ${n}' heading"
    fail=$((fail+1))
  fi
done

# Each scenario must mention a decision marker.
decisions=$(grep -cEi 'Decisi[óo]n' "$DOC")
if [ "$decisions" -ge 4 ]; then
  echo "  OK   DECISIONS.md has at least 4 'Decision' markers ($decisions found)"
else
  echo "  FAIL DECISIONS.md has only $decisions 'Decision' markers (expected >=4)"
  fail=$((fail+1))
fi

# Must mention OTel / OpenTelemetry.
if grep -qiE 'otel|opentelemetry' "$DOC"; then
  echo "  OK   mentions OTel / OpenTelemetry"
else
  echo "  FAIL does not mention OTel / OpenTelemetry"
  fail=$((fail+1))
fi

# Must mention 'status' (status page) at least once in synthesis context.
if grep -qiE 'status[- ]?page|status\b' "$DOC"; then
  echo "  OK   mentions status page / status"
else
  echo "  FAIL does not mention status page"
  fail=$((fail+1))
fi

# Must mention 'profiling' (either as excluded signal or incubation context).
if grep -qi 'profiling' "$DOC"; then
  echo "  OK   mentions profiling"
else
  echo "  FAIL does not mention profiling"
  fail=$((fail+1))
fi

# Must mention at least one maturity vocabulary token.
if grep -qiE '\b(ga|stable|beta|alpha|experimental|incubaci[óo]n|incubation|madurez)\b' "$DOC"; then
  echo "  OK   uses maturity vocabulary (GA/Stable/Beta/Alpha/incubacion/madurez)"
else
  echo "  FAIL does not use maturity vocabulary"
  fail=$((fail+1))
fi

# Must mention at least 2 alternatives from a canonical list.
alts_found=0
for alt in "datadog" "honeycomb" "new relic" "newrelic" "dynatrace" \
           "pprof" "pyroscope" "parca" "pixie" "ebpf" "beyla" \
           "jaeger" "zipkin" "prometheus_client" "dual-emit" "dual emit" "wait" "esperar"; do
  if grep -qi "$alt" "$DOC"; then
    alts_found=$((alts_found+1))
  fi
done
if [ "$alts_found" -ge 2 ]; then
  echo "  OK   DECISIONS.md names at least 2 alternatives/strategies ($alts_found found)"
else
  echo "  FAIL DECISIONS.md names only $alts_found alternatives (expected >=2)"
  fail=$((fail+1))
fi

# Must have the Sintesis section.
if grep -qiE '^#+ *S[íi]ntesis' "$DOC"; then
  echo "  OK   has 'Sintesis' section"
else
  echo "  FAIL missing 'Sintesis' section"
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
  echo "  OK   DECISIONS.md has at least 7 numbered criteria"
else
  echo "  FAIL DECISIONS.md has $answers_found numbered criteria (expected >=7)"
  fail=$((fail+1))
fi

# Must mention backend / vendor-neutral concept.
if grep -qiE 'backend|vendor[- ]?neutral|lock[- ]?in' "$DOC"; then
  echo "  OK   mentions backend / vendor-neutral / lock-in"
else
  echo "  FAIL no mention of backend / vendor-neutral / lock-in"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara DECISIONS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
