#!/usr/bin/env bash
# Structural validation for plat-11-01-build-dora-dashboard.
# Checks that events.json + DORA.md exist and that DORA.md has the required
# sections, mentions both services, the 4 metric names, buckets, and Goodhart.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-11-dora}"
EVENTS="$BASE/events.json"
DOC="$BASE/DORA.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$EVENTS" ]; then
  echo "FAIL: $EVENTS does not exist. Run starter/generate_events.py first."
  exit 1
fi
echo "  OK   events.json exists"

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi
echo "  OK   DORA.md exists"

# events.json must mention both services (basic sanity).
if grep -q 'checkout-api' "$EVENTS"; then
  echo "  OK   events.json mentions checkout-api"
else
  echo "  FAIL events.json missing checkout-api"
  fail=$((fail+1))
fi
if grep -q 'legacy-billing' "$EVENTS"; then
  echo "  OK   events.json mentions legacy-billing"
else
  echo "  FAIL events.json missing legacy-billing"
  fail=$((fail+1))
fi

# events.json must contain commit_merged, deploy and incident event types.
for et in commit_merged deploy incident; do
  if grep -q "\"$et\"" "$EVENTS"; then
    echo "  OK   events.json has event type '$et'"
  else
    echo "  FAIL events.json missing event type '$et'"
    fail=$((fail+1))
  fi
done

# Optional: compute_dora.py sanity-check against the real data.
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json,sys; json.load(open('$EVENTS'))" >/dev/null 2>&1; then
    echo "  OK   events.json parses as JSON"
  else
    echo "  FAIL events.json is not valid JSON"
    fail=$((fail+1))
  fi
else
  echo "  SKIP python3 not available — JSON parse check skipped"
fi

# DORA.md required headings (A, B, C, D).
for sec in "A" "B" "C" "D"; do
  if grep -qiE "^#+ *(Secci[óo]n +${sec}|${sec}\\.)" "$DOC"; then
    echo "  OK   DORA.md has Section ${sec} heading"
  else
    echo "  FAIL DORA.md missing Section ${sec} heading"
    fail=$((fail+1))
  fi
done

# DORA.md must mention both services.
for s in checkout-api legacy-billing; do
  if grep -q "$s" "$DOC"; then
    echo "  OK   DORA.md mentions $s"
  else
    echo "  FAIL DORA.md does not mention $s"
    fail=$((fail+1))
  fi
done

# Must mention the 4 DORA metric names (allow Spanish synonyms).
metric_hits=0
if grep -qiE 'deployment frequency|frecuencia de despliegue|deployment_frequency' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'lead time|lead-time|lead_time|tiempo de entrega' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'change failure rate|tasa de fallo|change_failure_rate|cfr' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if grep -qiE 'recovery|restore|recuperaci[óo]n|fdrt|mttr' "$DOC"; then
  metric_hits=$((metric_hits+1))
fi
if [ "$metric_hits" -ge 4 ]; then
  echo "  OK   DORA.md references all 4 DORA metric names ($metric_hits/4)"
else
  echo "  FAIL DORA.md references only $metric_hits/4 DORA metric names"
  fail=$((fail+1))
fi

# Must mention at least 2 buckets (Elite, High, Medium, Low).
bucket_hits=0
for b in elite high medium low; do
  if grep -qi "\\b${b}\\b" "$DOC"; then
    bucket_hits=$((bucket_hits+1))
  fi
done
if [ "$bucket_hits" -ge 2 ]; then
  echo "  OK   DORA.md names at least 2 DORA buckets ($bucket_hits/4)"
else
  echo "  FAIL DORA.md names only $bucket_hits/4 DORA buckets (expected >=2)"
  fail=$((fail+1))
fi

# Must mention Goodhart or 'vanity metric'.
if grep -qiE 'goodhart|vanity' "$DOC"; then
  echo "  OK   DORA.md references Goodhart / vanity metric"
else
  echo "  FAIL DORA.md does not mention Goodhart nor vanity metric"
  fail=$((fail+1))
fi

# Section D must contain at least 3 numbered items.
rec_count=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    rec_count=$((rec_count+1))
  fi
done
if [ "$rec_count" -ge 3 ]; then
  echo "  OK   DORA.md has at least 3 numbered recommendations"
else
  echo "  FAIL DORA.md has $rec_count numbered recommendations (expected >=3)"
  fail=$((fail+1))
fi

# Table with at least 4 rows (metric rows) + header + separator.
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 6 ]; then
  echo "  OK   DORA.md table has $rows pipe-lines (expected >=6)"
else
  echo "  FAIL DORA.md table has only $rows pipe-lines (expected >=6)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara DORA.md con solution/REFERENCE.md para autoevaluarte."
exit 0
