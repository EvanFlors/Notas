#!/usr/bin/env bash
# Structural validation for aws-14-02-event-driven-design-decisions.
# Checks DECISIONS.md has the required sections and that pdf-report.asl.json
# is a syntactically valid ASL skeleton (StartAt + States + at least one
# Task, one Choice, and one Retry/Catch block).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-14-design}"
DOC="$BASE/DECISIONS.md"
ASL="$BASE/pdf-report.asl.json"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it first."
  exit 1
fi

# ---- DECISIONS.md ----
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

for sec in A B C D E; do
  if grep -qiE "^#+ *(Secci[óo]n +${sec}\b|${sec}\. )" "$DOC"; then
    echo "  OK   DECISIONS.md has Section ${sec}"
  else
    echo "  FAIL DECISIONS.md missing Section ${sec}"
    fail=$((fail+1))
  fi
done

# Compute table — at least 4 pipe-rows for 4 subcases + header + separator = >=6.
rows=$(grep -cE '^\|' "$DOC" || echo 0)
if [ "$rows" -ge 6 ]; then
  echo "  OK   DECISIONS.md has at least 4 compute rows ($rows pipe-lines found)"
else
  echo "  FAIL DECISIONS.md has only $rows pipe-lines (expected >=6)"
  fail=$((fail+1))
fi

# Mentions at least Lambda and one of ECS/Fargate/EKS.
if grep -qi 'lambda' "$DOC"; then
  echo "  OK   mentions Lambda"
else
  echo "  FAIL does not mention Lambda"
  fail=$((fail+1))
fi
if grep -qiE 'ecs|fargate|eks'  "$DOC"; then
  echo "  OK   mentions ECS/Fargate/EKS (compute alternatives)"
else
  echo "  FAIL does not mention ECS/Fargate/EKS"
  fail=$((fail+1))
fi

# Topology must mention SQS, DLQ, VisibilityTimeout (or VisTO).
if grep -qi 'sqs' "$DOC"; then
  echo "  OK   mentions SQS"
else
  echo "  FAIL does not mention SQS"
  fail=$((fail+1))
fi
if grep -qi 'dlq' "$DOC"; then
  echo "  OK   mentions DLQ"
else
  echo "  FAIL does not mention DLQ"
  fail=$((fail+1))
fi
if grep -qiE 'visibility ?timeout|visto\b' "$DOC"; then
  echo "  OK   mentions VisibilityTimeout / VisTO"
else
  echo "  FAIL does not mention VisibilityTimeout / VisTO"
  fail=$((fail+1))
fi

# Must mention SNS or EventBridge (fanout layer).
if grep -qiE 'sns|eventbridge'  "$DOC"; then
  echo "  OK   mentions SNS or EventBridge (fanout)"
else
  echo "  FAIL does not mention SNS nor EventBridge"
  fail=$((fail+1))
fi

# FIFO vs Standard vocabulary.
if grep -qiE '\bfifo\b|standard' "$DOC"; then
  echo "  OK   uses FIFO/Standard vocabulary"
else
  echo "  FAIL does not use FIFO/Standard vocabulary"
  fail=$((fail+1))
fi

# Costos ocultos — at least 3 numbered items in the file.
numbered=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    numbered=$((numbered+1))
  fi
done
if [ "$numbered" -ge 3 ]; then
  echo "  OK   DECISIONS.md has at least 3 numbered items (hidden costs)"
else
  echo "  FAIL DECISIONS.md has $numbered numbered items (expected >=3)"
  fail=$((fail+1))
fi

# Must mention CloudWatch Logs (canonical hidden cost example).
if grep -qiE 'cloudwatch|logs?' "$DOC"; then
  echo "  OK   mentions CloudWatch / logs (hidden cost vocabulary)"
else
  echo "  FAIL does not mention CloudWatch / logs"
  fail=$((fail+1))
fi

# ---- ASL JSON ----
if [ ! -f "$ASL" ]; then
  echo "  FAIL $ASL does not exist. Student must produce it."
  fail=$((fail+1))
else
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$ASL" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    doc = json.load(f)
# Must have StartAt + States mapping.
assert isinstance(doc, dict), "root is not a JSON object"
assert "StartAt" in doc, "missing StartAt"
assert "States" in doc and isinstance(doc["States"], dict), "missing/invalid States"
start = doc["StartAt"]
states = doc["States"]
assert start in states, f"StartAt '{start}' not in States"
types = [s.get("Type") for s in states.values()]
assert "Task" in types, "no Task state"
assert "Choice" in types, "no Choice state"
has_rc = any(("Retry" in s or "Catch" in s) for s in states.values())
assert has_rc, "no Retry nor Catch anywhere"
for name, s in states.items():
    nxt = s.get("Next")
    if nxt is not None:
        assert nxt in states, f"state '{name}' Next '{nxt}' not defined"
    for ch in s.get("Choices", []) or []:
        n = ch.get("Next")
        assert n in states, f"Choice in '{name}' Next '{n}' not defined"
    dft = s.get("Default")
    if dft is not None:
        assert dft in states, f"state '{name}' Default '{dft}' not defined"
print("ASL structural OK")
PY
    then
      echo "  OK   pdf-report.asl.json is structurally valid ASL (StartAt+States+Task+Choice+Retry/Catch)"
    else
      echo "  FAIL pdf-report.asl.json failed structural ASL validation (see error above)"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP python3 not available; cannot validate ASL JSON structure"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara DECISIONS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
