#!/usr/bin/env bash
# Structural validation for obs-01-02-identify-pillars-in-a-scenario.
# Checks that PILLARS.md exists and contains the required sections, the
# three-pillar vocabulary, 8 numbered questions and at least 5 lagunas.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

BASE="${1:-/tmp/obs-01-pillars}"
DOC="$BASE/PILLARS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# The three pillars must appear (as vocabulary).
for pillar in "metrics" "logs" "traces"; do
  if grep -qi "$pillar" "$DOC"; then
    echo "  OK   PILLARS.md mentions '$pillar'"
  else
    echo "  FAIL PILLARS.md does not mention '$pillar'"
    fail=$((fail+1))
  fi
done

# Must mention at least one of the emerging pillars.
if grep -qiE 'events?|profiling|exemplar' "$DOC"; then
  echo "  OK   mentions an emerging pillar (events/profiling/exemplars)"
else
  echo "  FAIL does not mention any emerging pillar"
  fail=$((fail+1))
fi

# Section A — must look like a table (at least 2 pipe-separated rows).
pipe_rows=$(grep -cE '^\|.+\|' "$DOC")
if [ "$pipe_rows" -ge 3 ]; then
  echo "  OK   PILLARS.md contains a markdown table ($pipe_rows pipe rows)"
else
  echo "  FAIL PILLARS.md has only $pipe_rows pipe-table rows (expected >=3)"
  fail=$((fail+1))
fi

# Must reference each of the 8 questions by number (1 through 8 appear as
# numbered items somewhere in the doc — either as rows or as explanations).
qs_found=0
for n in 1 2 3 4 5 6 7 8; do
  if grep -Eq "(^[[:space:]]*${n}\\.|^\\|[[:space:]]*${n}[[:space:]]*\\|)" "$DOC"; then
    qs_found=$((qs_found+1))
  fi
done
if [ "$qs_found" -ge 8 ]; then
  echo "  OK   PILLARS.md references all 8 questions"
else
  echo "  FAIL PILLARS.md references only $qs_found questions (expected 8)"
  fail=$((fail+1))
fi

# Lagunas section must exist and have at least 5 numbered lagunas.
if grep -qiE '^#+ *(B\.|Lagunas)' "$DOC"; then
  echo "  OK   has 'Lagunas' section (B)"
else
  echo "  FAIL missing 'Lagunas' section (B)"
  fail=$((fail+1))
fi

lag_count=$(grep -ciE '^#+ *Laguna +[0-9]' "$DOC")
if [ "$lag_count" -ge 5 ]; then
  echo "  OK   PILLARS.md lists $lag_count lagunas (>=5)"
else
  echo "  FAIL PILLARS.md lists only $lag_count lagunas (expected >=5)"
  fail=$((fail+1))
fi

# Section C — monitoring vs observabilidad must be addressed.
if grep -qiE 'monitoring' "$DOC" && grep -qiE 'observabil' "$DOC"; then
  echo "  OK   discusses monitoring vs observabilidad"
else
  echo "  FAIL does not discuss both 'monitoring' and 'observabilidad'"
  fail=$((fail+1))
fi

# Must mention a concrete acquirer-related signal (central to the postmortem).
if grep -qi 'acquirer' "$DOC"; then
  echo "  OK   mentions 'acquirer' (central missing label)"
else
  echo "  FAIL does not mention 'acquirer' (central missing label)"
  fail=$((fail+1))
fi

# Must mention trace_id or correlation across services.
if grep -qiE 'trace[_ ]?id|correlat' "$DOC"; then
  echo "  OK   mentions trace_id / correlation across services"
else
  echo "  FAIL does not mention trace_id nor correlation"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara PILLARS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
