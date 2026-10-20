#!/usr/bin/env bash
# Structural validation for aws-08-02-dynamodb-partition-key-design.
# Checks that ACCESS_PATTERNS.md exists with the required sections and
# vocabulary. Verifies model.py is present. If run.log is present, checks
# it either contains the OK marker or a SKIP line (both are acceptable).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which may trigger SIGPIPE (exit 141) when grep
# matches early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness.

set -eu

BASE="${1:-/tmp/aws-08-dynamodb}"
DOC="$BASE/ACCESS_PATTERNS.md"
MODEL="$BASE/model.py"
LOG="$BASE/run.log"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "  WARN model.py not present at $MODEL (expected copy from starter/)"
fi

# Required sections A..D.
for sec in A B C D; do
  if grep -qiE "^#+ *${sec}([.)]| +[-—–])" "$DOC"; then
    echo "  OK   ACCESS_PATTERNS.md has section ${sec}"
  else
    echo "  FAIL ACCESS_PATTERNS.md missing section ${sec}"
    fail=$((fail+1))
  fi
done

# At least 3 patterns described: look for 'Patr' tokens or 3 numbered items.
patron_count=$(grep -ciE 'patr[óo]n' "$DOC" || true)
numbered=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    numbered=$((numbered+1))
  fi
done
if [ "$patron_count" -ge 3 ] || [ "$numbered" -ge 3 ]; then
  echo "  OK   ACCESS_PATTERNS.md describes at least 3 patterns (patron_tokens=$patron_count, numbered=$numbered)"
else
  echo "  FAIL ACCESS_PATTERNS.md describes fewer than 3 patterns"
  fail=$((fail+1))
fi

# Must mention DynamoDB vocabulary: PK, SK and GSI.
if grep -qE '\bPK\b' "$DOC" && grep -qE '\bSK\b' "$DOC"; then
  echo "  OK   mentions PK and SK"
else
  echo "  FAIL does not mention PK and SK"
  fail=$((fail+1))
fi

if grep -qiE '\bgsi\b|global secondary index' "$DOC"; then
  echo "  OK   mentions GSI"
else
  echo "  FAIL does not mention GSI"
  fail=$((fail+1))
fi

# Must mention Query and GetItem operations.
if grep -qiE '\bquery\b' "$DOC" && grep -qiE 'get[-_ ]?item' "$DOC"; then
  echo "  OK   mentions Query and GetItem operations"
else
  echo "  FAIL does not mention both Query and GetItem"
  fail=$((fail+1))
fi

# Must mention hot partition.
if grep -qiE 'hot[- ]?partition' "$DOC"; then
  echo "  OK   mentions hot partition"
else
  echo "  FAIL does not mention hot partition"
  fail=$((fail+1))
fi

# Must mention sharding / write sharding.
if grep -qiE 'sharding|shard'  "$DOC"; then
  echo "  OK   mentions sharding"
else
  echo "  FAIL does not mention sharding"
  fail=$((fail+1))
fi

# Must mention single-table.
if grep -qiE 'single[- ]?table' "$DOC"; then
  echo "  OK   mentions single-table"
else
  echo "  FAIL does not mention single-table"
  fail=$((fail+1))
fi

# Must mention LocalStack (either as used or as SKIP context).
if grep -qi 'localstack' "$DOC"; then
  echo "  OK   mentions LocalStack"
else
  echo "  FAIL does not mention LocalStack"
  fail=$((fail+1))
fi

# Projection type reference (ALL / KEYS_ONLY / INCLUDE).
if grep -qiE 'projection|KEYS_ONLY|ALL\b|INCLUDE' "$DOC"; then
  echo "  OK   discusses projection type"
else
  echo "  FAIL does not discuss projection type"
  fail=$((fail+1))
fi

# If run.log is present, must contain either OK marker or SKIP line.
if [ -f "$LOG" ]; then
  if grep -qE 'OK: [0-9]+/3 access patterns verified' "$LOG"; then
    echo "  OK   run.log shows LocalStack run completed"
  elif grep -qi 'SKIP: LocalStack not available' "$LOG"; then
    echo "  OK   run.log shows clean SKIP (LocalStack absent)"
  else
    echo "  FAIL run.log present but shows neither OK nor SKIP line"
    fail=$((fail+1))
  fi
else
  echo "  WARN run.log not present; cannot verify execution occurred"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ACCESS_PATTERNS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
