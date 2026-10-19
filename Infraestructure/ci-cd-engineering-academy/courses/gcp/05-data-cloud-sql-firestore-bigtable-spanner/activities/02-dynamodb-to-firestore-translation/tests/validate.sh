#!/usr/bin/env bash
# Structural validation for gcp-05-02-dynamodb-to-firestore-translation.
# Checks TRANSLATION.md has the 6 required sections, a mapping table, and
# the minimum mentions (collections+subcollections, row key, composite
# indexes, GSI/DynamoDB contrast, hotspot/sequential key warning,
# emulator limits).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness. Compare with solution/TRANSLATION.md.

set -eu

BASE="${1:-/tmp/gcp-05-02}"
DOC="$BASE/TRANSLATION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist."
  exit 1
fi
echo "  OK   TRANSLATION.md exists"

# Required sections.
for section in "Resumen" "Mapeo +por +patron" "Modelado +Firestore" \
               "Donde +Bigtable +gana" "Indices +compuestos" "Limites +del +emulador"; do
  if grep -qiE "^#+ *${section}" "$DOC"; then
    echo "  OK   has section matching '${section}'"
  else
    echo "  FAIL missing section matching '${section}'"
    fail=$((fail+1))
  fi
done

# Must contain a Markdown table (at least 2 pipe-rows).
table_rows=$(grep -cE '^\|.*\|' "$DOC" || true)
if [ "$table_rows" -ge 4 ]; then
  echo "  OK   contains a Markdown table (${table_rows} pipe-rows)"
else
  echo "  FAIL only ${table_rows} pipe-rows; expected a mapping table"
  fail=$((fail+1))
fi

# Must mention both Firestore and Bigtable several times.
fs_hits=$(grep -ci 'Firestore' "$DOC" || true)
bt_hits=$(grep -ci 'Bigtable' "$DOC" || true)
if [ "$fs_hits" -ge 3 ] && [ "$bt_hits" -ge 3 ]; then
  echo "  OK   mentions Firestore (${fs_hits}) and Bigtable (${bt_hits})"
else
  echo "  FAIL mentions Firestore ${fs_hits} / Bigtable ${bt_hits} (expected >=3 each)"
  fail=$((fail+1))
fi

# Must mention collections AND subcollections (Firestore modeling).
if grep -qiE 'colecci|collection' "$DOC" && grep -qiE 'subcolecci|subcollection' "$DOC"; then
  echo "  OK   mentions collections and subcollections"
else
  echo "  FAIL does not mention both 'collection' and 'subcollection'"
  fail=$((fail+1))
fi

# Must mention row key for Bigtable justification.
if grep -qiE 'row +key|rowkey' "$DOC"; then
  echo "  OK   mentions row key (Bigtable modeling)"
else
  echo "  FAIL does not mention row key"
  fail=$((fail+1))
fi

# Must contrast with DynamoDB and GSI.
if grep -qi 'DynamoDB' "$DOC"; then
  echo "  OK   mentions DynamoDB"
else
  echo "  FAIL does not mention DynamoDB"
  fail=$((fail+1))
fi
if grep -qiE 'GSI|Global +Secondary +Index' "$DOC"; then
  echo "  OK   mentions GSI / Global Secondary Index"
else
  echo "  FAIL does not mention GSI / Global Secondary Index"
  fail=$((fail+1))
fi

# Must mention composite indexes (word 'compuesto' or 'composite') at least
# twice (two indexes required).
idx_hits=$(grep -ciE 'compuesto|composite' "$DOC" || true)
if [ "$idx_hits" -ge 2 ]; then
  echo "  OK   mentions composite/compuesto index at least twice (${idx_hits})"
else
  echo "  FAIL mentions composite/compuesto index only ${idx_hits} times (expected >=2)"
  fail=$((fail+1))
fi

# Must mention hotspot or sequential key issue.
if grep -qiE 'hotspot|secuencial|monotono|sequential' "$DOC"; then
  echo "  OK   mentions hotspot / sequential key risk"
else
  echo "  FAIL does not mention hotspot / sequential key risk"
  fail=$((fail+1))
fi

# Must mention emulator and its limits.
if grep -qi 'emulador\|emulator' "$DOC"; then
  echo "  OK   mentions emulator"
else
  echo "  FAIL does not mention emulator"
  fail=$((fail+1))
fi

# Must NOT be named ANALYSIS.md (we explicitly use TRANSLATION.md).
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE/ANALYSIS.md exists; this activity uses TRANSLATION.md"
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md shadowing the deliverable"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/TRANSLATION.md for semantics.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/TRANSLATION.md para autoevaluarte."
exit 0
