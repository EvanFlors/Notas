#!/usr/bin/env bash
# Structural validation for otel-03-02 — eBPF vs SDK analysis.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

BASE="${1:-/tmp/otel-03-02}"
DOC="$BASE/ANALYSIS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Copy starter/template.md there and complete it."
  exit 1
fi

# All 4 scenarios present as headings.
for n in 1 2 3 4; do
  if grep -qiE "^#+ *Escenario +${n}" "$DOC"; then
    echo "  OK   has 'Escenario ${n}' heading"
  else
    echo "  FAIL missing 'Escenario ${n}' heading"
    fail=$((fail+1))
  fi
done

# Decision markers (at least 4).
dec=$(grep -ciE 'Decisi[óo]n[^A-Za-z0-9]' "$DOC")
if [ "$dec" -ge 4 ]; then
  echo "  OK   has at least 4 'Decisión' markers ($dec)"
else
  echo "  FAIL only $dec 'Decisión' markers (expected >=4)"
  fail=$((fail+1))
fi

# Mentions at least one eBPF tool by name.
if grep -qiE 'pixie|beyla|hubble' "$DOC"; then
  echo "  OK   names at least one eBPF tool (Pixie/Beyla/Hubble)"
else
  echo "  FAIL does not name any eBPF tool"
  fail=$((fail+1))
fi

# Mentions SDK and auto at least once each as part of the analysis vocabulary.
if grep -qiE '\bsdk\b' "$DOC"; then
  echo "  OK   mentions SDK"
else
  echo "  FAIL does not mention SDK"
  fail=$((fail+1))
fi
if grep -qiE '\bauto\b|opentelemetry-instrument' "$DOC"; then
  echo "  OK   mentions auto-instrumentation"
else
  echo "  FAIL does not mention auto-instrumentation"
  fail=$((fail+1))
fi

# Student must have replaced the raw template placeholders.
if grep -qE '\(describe en 2 l[ií]neas\)|<manual\|library\|auto\|ebpf\|ninguna' "$DOC"; then
  echo "  FAIL ANALYSIS.md still contains unfilled template placeholders"
  fail=$((fail+1))
else
  echo "  OK   template placeholders have been replaced"
fi

# Synthesis section with 5 numbered criteria.
if grep -qiE '^#+ *S[íi]ntesis' "$DOC"; then
  echo "  OK   has 'Síntesis' section"
else
  echo "  FAIL missing 'Síntesis' section"
  fail=$((fail+1))
fi

answers=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    answers=$((answers+1))
  fi
done
if [ "$answers" -ge 5 ]; then
  echo "  OK   Síntesis has at least 5 numbered criteria"
else
  echo "  FAIL Síntesis has only $answers numbered criteria (expected >=5)"
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
