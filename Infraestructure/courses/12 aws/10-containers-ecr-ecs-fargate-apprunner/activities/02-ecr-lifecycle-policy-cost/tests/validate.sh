#!/usr/bin/env bash
# Structural validation for aws-10-02-ecr-lifecycle-policy-cost.
# Checks that lifecycle-policy.json follows ECR's lifecycle policy schema
# and that README-INTENT.md justifies each rule.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT apply anything to AWS. Does NOT validate semantic correctness.

set -eu

BASE="${1:-/tmp/aws-10-ecr-lifecycle}"
JSON="$BASE/lifecycle-policy.json"
DOC="$BASE/README-INTENT.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

if [ ! -f "$JSON" ]; then
  echo "FAIL: $JSON does not exist. Copy starter/ first."
  exit 1
fi

if jq empty "$JSON" >/dev/null 2>&1; then
  echo "  OK   lifecycle-policy.json is valid JSON"
else
  echo "  FAIL lifecycle-policy.json is not valid JSON"
  exit 1
fi

check_jq() {
  local expr="$1"
  local label="$2"
  local val
  val=$(jq -r "$expr" "$JSON" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   lifecycle-policy.json: ${label}"
  else
    echo "  FAIL lifecycle-policy.json: ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

check_jq '(.rules | type == "array") and (.rules | length >= 3)' \
  'has rules array with at least 3 rules'

# Every rule has required fields.
check_jq '[.rules[] | (has("rulePriority") and has("description") and has("selection") and has("action"))] | all' \
  'every rule has rulePriority, description, selection and action'

# rulePriority is a positive integer and unique.
check_jq '[.rules[].rulePriority | type == "number"] | all' \
  'every rulePriority is a number'
check_jq '([.rules[].rulePriority] | unique | length) == (.rules | length)' \
  'rulePriority values are unique across rules'

# description is a non-empty, non-TODO string.
check_jq '[.rules[].description | (type == "string" and . != "" and (contains("TODO") | not))] | all' \
  'every description is a non-placeholder string'

# action.type is "expire" for every rule.
check_jq '[.rules[].action.type] | all(. == "expire")' \
  'every action.type is "expire" (only value ECR supports)'

# selection.tagStatus is one of the allowed values.
check_jq '[.rules[].selection.tagStatus] | all(. == "tagged" or . == "untagged" or . == "any")' \
  'every selection.tagStatus is tagged|untagged|any'

# selection.countType is one of the allowed values.
check_jq '[.rules[].selection.countType] | all(. == "imageCountMoreThan" or . == "sinceImagePushed")' \
  'every selection.countType is imageCountMoreThan|sinceImagePushed'

# selection.countNumber is a positive integer > 0 (no leftover 0 placeholder).
check_jq '[.rules[].selection.countNumber | type == "number" and . > 0] | all' \
  'every selection.countNumber is a positive number (>0)'

# When countType=sinceImagePushed, countUnit must be "days".
check_jq '[.rules[].selection | if .countType == "sinceImagePushed" then .countUnit == "days" else true end] | all' \
  'rules using sinceImagePushed set countUnit = "days"'

# When tagStatus=tagged, must have tagPrefixList or tagPatternList
# (and tagPrefixList must not just be ["TODO"]).
check_jq '[.rules[].selection | if .tagStatus == "tagged" then (has("tagPrefixList") or has("tagPatternList")) else true end] | all' \
  'tagged rules declare tagPrefixList or tagPatternList'
check_jq '[.rules[].selection | if (.tagStatus == "tagged" and has("tagPrefixList")) then ((.tagPrefixList | map(. != "TODO" and . != "")) | all) else true end] | all' \
  'tagPrefixList values are non-placeholder, non-empty'

# Must contain at least one "tagged" (retain releases), one "untagged" (sweep CI junk)
# and one broad backstop (any with sinceImagePushed, or tagged/any with large count).
check_jq '[.rules[].selection.tagStatus] | any(. == "tagged")' \
  'at least one rule targets tagStatus "tagged" (retain releases)'
check_jq '[.rules[].selection.tagStatus] | any(. == "untagged")' \
  'at least one rule targets tagStatus "untagged" (sweep CI junk)'
check_jq '[.rules[] | (.selection.tagStatus == "any") or (.selection.countType == "sinceImagePushed")] | any' \
  'at least one rule is a time-based or tagStatus=any backstop'

# rulePriority order should match array order (idiomatic; not required by ECR but
# we enforce it for pedagogical clarity).
check_jq '[.rules[].rulePriority] == ([.rules[].rulePriority] | sort)' \
  'rules are listed in ascending rulePriority order'

# --- README-INTENT.md ------------------------------------------------------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist."
  fail=$((fail+1))
else
  echo "  OK   README-INTENT.md exists"

  # Must have Resumen and Orden de evaluacion sections.
  if grep -qiE '^#+ +(Resumen|Summary)\b' "$DOC"; then
    echo "  OK   README-INTENT.md has 'Resumen' section"
  else
    echo "  FAIL README-INTENT.md missing 'Resumen' section"
    fail=$((fail+1))
  fi

  if grep -qiE '^#+ +(Orden +de +evaluaci[oó]n|Evaluation +order)\b' "$DOC"; then
    echo "  OK   README-INTENT.md has 'Orden de evaluacion' section"
  else
    echo "  FAIL README-INTENT.md missing 'Orden de evaluacion' section"
    fail=$((fail+1))
  fi

  # Must have one section per rule — count "## Regla" or "## Rule" headers.
  rule_headers=$(grep -cEi '^#+ +(Regla|Rule) +[0-9]+' "$DOC" || true)
  if [ "$rule_headers" -ge 3 ]; then
    echo "  OK   README-INTENT.md has >=3 per-rule sections (${rule_headers} found)"
  else
    echo "  FAIL README-INTENT.md has only ${rule_headers} per-rule sections (expected >=3)"
    fail=$((fail+1))
  fi

  # Must have no TODO markers left.
  if grep -qE 'TODO' "$DOC"; then
    echo "  FAIL README-INTENT.md still contains TODO markers"
    fail=$((fail+1))
  else
    echo "  OK   README-INTENT.md has no remaining TODO markers"
  fi

  # Must mention CloudWatch Metrics or ECR repository metrics for monitoring.
  if grep -qiE 'CloudWatch|repository +metrics|RepositorySize' "$DOC"; then
    echo "  OK   README-INTENT.md mentions CloudWatch/ECR repository metrics"
  else
    echo "  FAIL README-INTENT.md does not mention CloudWatch / ECR repository metrics"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/REFERENCE.md to self-grade semantics.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
