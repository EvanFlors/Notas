#!/usr/bin/env bash
# Structural validation for az-05-02-cosmos-consistency-tradeoff.
# Checks that CONSISTENCY.md exists with the required sections and
# vocabulary. Verifies model.py is present. If run.log is present, checks
# it either contains the OK marker or a SKIP line (both acceptable).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which may trigger SIGPIPE (exit 141) when grep
# matches early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness.

set -eu

BASE="${1:-/tmp/az-05-cosmos}"
DOC="$BASE/CONSISTENCY.md"
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

# Required four sections A..D.
for sec in A B C D; do
  if grep -qiE "^#+ *${sec}([.)]| +[-—–])" "$DOC"; then
    echo "  OK   CONSISTENCY.md has section ${sec}"
  else
    echo "  FAIL CONSISTENCY.md missing section ${sec}"
    fail=$((fail+1))
  fi
done

# At least 3 patterns described.
patron_count=$(grep -ciE 'patr[óo]n' "$DOC" || true)
numbered=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    numbered=$((numbered+1))
  fi
done
if [ "$patron_count" -ge 3 ] || [ "$numbered" -ge 3 ]; then
  echo "  OK   CONSISTENCY.md describes at least 3 patterns (patron_tokens=$patron_count, numbered=$numbered)"
else
  echo "  FAIL CONSISTENCY.md describes fewer than 3 patterns"
  fail=$((fail+1))
fi

# Must mention Cosmos vocabulary. Accept either DynamoDB-style PK/SK OR
# Cosmos vocab "partition key / partitionKey".
if (grep -qE '\bPK\b' "$DOC" && grep -qE '\bSK\b' "$DOC") \
   || grep -qiE 'partition[- ]?key|partitionKey' "$DOC"; then
  echo "  OK   mentions PK/SK or partition key"
else
  echo "  FAIL does not mention PK/SK nor partition key"
  fail=$((fail+1))
fi

# GSI reference or Cosmos "composite index".
if grep -qiE '\bgsi\b|global secondary index|composite +index' "$DOC"; then
  echo "  OK   mentions GSI / composite index"
else
  echo "  FAIL does not mention GSI / composite index"
  fail=$((fail+1))
fi

# Must mention Query and GetItem (or get_item / read_item / point read).
if grep -qiE '\bquery\b' "$DOC" \
   && grep -qiE 'get[-_ ]?item|read[-_ ]?item|point[- ]?read' "$DOC"; then
  echo "  OK   mentions Query and GetItem/read_item/point read operations"
else
  echo "  FAIL does not mention both Query and GetItem/read_item/point read"
  fail=$((fail+1))
fi

# Hot partition.
if grep -qiE 'hot[- ]?partition' "$DOC"; then
  echo "  OK   mentions hot partition"
else
  echo "  FAIL does not mention hot partition"
  fail=$((fail+1))
fi

# Sharding.
if grep -qiE 'sharding|shard' "$DOC"; then
  echo "  OK   mentions sharding"
else
  echo "  FAIL does not mention sharding"
  fail=$((fail+1))
fi

# single-table / single-container.
if grep -qiE 'single[- ]?table|single[- ]?container' "$DOC"; then
  echo "  OK   mentions single-table / single-container"
else
  echo "  FAIL does not mention single-table / single-container"
  fail=$((fail+1))
fi

# LocalStack (comparison reference to aws-08).
if grep -qi 'localstack' "$DOC"; then
  echo "  OK   mentions LocalStack (comparison with aws-08)"
else
  echo "  FAIL does not mention LocalStack"
  fail=$((fail+1))
fi

# Cosmos emulator.
if grep -qiE 'cosmos +emulator|cosmos +db +emulator' "$DOC"; then
  echo "  OK   mentions Cosmos DB emulator"
else
  echo "  FAIL does not mention Cosmos DB emulator"
  fail=$((fail+1))
fi

# Azurite.
if grep -qi 'azurite' "$DOC"; then
  echo "  OK   mentions Azurite"
else
  echo "  FAIL does not mention Azurite"
  fail=$((fail+1))
fi

# Projection type reference (ALL / KEYS_ONLY / INCLUDE / projection).
if grep -qiE 'projection|KEYS_ONLY|ALL\b|INCLUDE' "$DOC"; then
  echo "  OK   discusses projection type"
else
  echo "  FAIL does not discuss projection type"
  fail=$((fail+1))
fi

# At least one consistency level named.
clevels=0
for c in "strong" "bounded staleness" "session" "consistent prefix" "eventual"; do
  if grep -qi "$c" "$DOC"; then
    clevels=$((clevels+1))
  fi
done
if [ "$clevels" -ge 2 ]; then
  echo "  OK   names at least 2 Cosmos consistency levels ($clevels found)"
else
  echo "  FAIL names only $clevels Cosmos consistency levels (expected >=2)"
  fail=$((fail+1))
fi

# DynamoDB mapping reference.
if grep -qi 'dynamodb' "$DOC"; then
  echo "  OK   mentions DynamoDB (mapping reference)"
else
  echo "  FAIL does not mention DynamoDB"
  fail=$((fail+1))
fi

# If run.log present, must contain OK marker or SKIP line.
if [ -f "$LOG" ]; then
  if grep -qE 'OK: [0-9]+/3 cosmos patterns verified' "$LOG" \
     || grep -qi 'blob upload OK' "$LOG"; then
    echo "  OK   run.log shows emulator run completed"
  elif grep -qiE 'SKIP: (Cosmos emulator|Azurite) not available|cosmos SKIP|azurite SKIP' "$LOG"; then
    echo "  OK   run.log shows clean SKIP (emulators absent)"
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
echo "OK: estructura valida. Compara CONSISTENCY.md con solution/REFERENCE.md para autoevaluarte."
exit 0
