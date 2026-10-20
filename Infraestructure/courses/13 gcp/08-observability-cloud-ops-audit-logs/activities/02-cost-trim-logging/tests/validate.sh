#!/usr/bin/env bash
# Structural validation for gcp-08-02-cost-trim-logging.
#
# Checks: exclusion-filter.json (valid JSON, >=3 exclusions, no exclusion
# matches cloudaudit, each disabled=false), sink.json (BigQuery destination,
# cloudaudit filter, includeChildren=true, partitioned tables), LOG-RETENTION-ADR.md
# with required sections + keywords, README-INTENT.md with required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP project — compare manually
# with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-08-cost}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_jq_valid() {
  local f="$1"
  if jq empty "$f" >/dev/null 2>&1; then
    echo "  OK   $f is valid JSON"
    return 0
  else
    echo "  FAIL $f is not valid JSON"
    fail=$((fail+1))
    return 1
  fi
}

check_jq_contains() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local val
  val=$(jq -r "$expr" "$f" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

# --- exclusion-filter.json --------------------------------------------------
F1="$BASE/exclusion-filter.json"
if check_file_exists "$F1"; then
  check_jq_valid "$F1" || true
  check_jq_contains "$F1" '(.exclusions // []) | length >= 3' 'has at least 3 exclusions'
  check_jq_contains "$F1" '[.exclusions[] | (.name // "") | length > 0] | all' 'each exclusion has a non-empty name'
  check_jq_contains "$F1" '[.exclusions[] | (.filter // "") | length > 0] | all' 'each exclusion has a non-empty filter'
  check_jq_contains "$F1" '[.exclusions[] | (if has("disabled") then .disabled else false end)] | all(. == false)' 'no exclusion is disabled'
  # None of the exclusions should match cloudaudit.googleapis.com (would break audit).
  bad=$(jq -r '[.exclusions[] | select((.filter // "") | contains("cloudaudit.googleapis.com") and (contains("NOT") | not))] | length' "$F1" 2>/dev/null || echo "0")
  if [ "$bad" = "0" ]; then
    echo "  OK   $F1: no exclusion silently drops cloudaudit.googleapis.com logs"
  else
    echo "  FAIL $F1: ${bad} exclusion(s) match cloudaudit.googleapis.com without a NOT clause"
    fail=$((fail+1))
  fi
  # At least one exclusion must target health/probe traffic.
  if jq -r '.exclusions[].filter' "$F1" 2>/dev/null | grep -qiE 'health|readi|live|probe'; then
    echo "  OK   $F1: has an exclusion targeting health/probe traffic"
  else
    echo "  FAIL $F1: no exclusion targets health/probe traffic"
    fail=$((fail+1))
  fi
  # At least one exclusion must target DEBUG severity or similar.
  if jq -r '.exclusions[].filter' "$F1" 2>/dev/null | grep -qiE 'DEBUG|severity<|severity ?< ?INFO'; then
    echo "  OK   $F1: has an exclusion targeting DEBUG / low severity"
  else
    echo "  FAIL $F1: no exclusion targets DEBUG / low severity logs"
    fail=$((fail+1))
  fi
fi

# --- sink.json --------------------------------------------------------------
F2="$BASE/sink.json"
if check_file_exists "$F2"; then
  check_jq_valid "$F2" || true
  check_jq_contains "$F2" '(.name // "") | length > 0' 'has non-empty name'
  check_jq_contains "$F2" '(.destination // "") | startswith("bigquery.googleapis.com/")' 'destination points to BigQuery'
  check_jq_contains "$F2" '(.filter // "") | contains("cloudaudit.googleapis.com")' 'filter targets cloudaudit.googleapis.com'
  check_jq_contains "$F2" '(.includeChildren // false) == true' 'includeChildren = true (org-wide)'
  check_jq_contains "$F2" '(.bigqueryOptions.usePartitionedTables // false) == true' 'uses partitioned tables'
  # Destination must use the LOG_SINK_PROJECT placeholder (no real project).
  if grep -q 'LOG_SINK_PROJECT' "$F2"; then
    echo "  OK   $F2: uses LOG_SINK_PROJECT placeholder"
  else
    echo "  FAIL $F2: does not use LOG_SINK_PROJECT placeholder in destination"
    fail=$((fail+1))
  fi
fi

# --- LOG-RETENTION-ADR.md ---------------------------------------------------
F3="$BASE/LOG-RETENTION-ADR.md"
if check_file_exists "$F3"; then
  if grep -qiE '^#+ *ADR' "$F3"; then
    echo "  OK   $F3 has an 'ADR' heading"
  else
    echo "  FAIL $F3 missing 'ADR' heading"
    fail=$((fail+1))
  fi
  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$F3"; then
      echo "  OK   $F3 has '${label}' section"
    else
      echo "  FAIL $F3 missing '${label}' section"
      fail=$((fail+1))
    fi
  done
  for kw in "_Required" "_Default" "BigQuery" "exclusion" "Data Access" "Admin Activity" "Secret Manager"; do
    if grep -q "$kw" "$F3"; then
      echo "  OK   $F3 mentions '${kw}'"
    else
      echo "  FAIL $F3 does not mention '${kw}'"
      fail=$((fail+1))
    fi
  done
  if grep -qE '400[ -]?d[ií]as?|400 ?days' "$F3"; then
    echo "  OK   $F3 mentions 400 days retention"
  else
    echo "  FAIL $F3 does not mention 400 days retention"
    fail=$((fail+1))
  fi
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$F3" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$F3" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   $F3 lists at least 2 alternatives"
  else
    echo "  FAIL $F3 lists fewer than 2 alternatives"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md -------------------------------------------------------
F4="$BASE/README-INTENT.md"
if check_file_exists "$F4"; then
  for section in "exclusion-filter" "sink" "retention"; do
    if grep -qE "^#+ .*${section}" "$F4"; then
      echo "  OK   $F4 has section for '${section}'"
    else
      echo "  FAIL $F4 missing section for '${section}'"
      fail=$((fail+1))
    fi
  done
  for kw in "health" "DEBUG" "audit" "BigQuery" "cloudaudit"; do
    if grep -qi "$kw" "$F4"; then
      echo "  OK   $F4 mentions '${kw}'"
    else
      echo "  FAIL $F4 does not mention '${kw}'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  echo "        (Semantic correctness in a real GCP project is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Structural validation passed."
echo "        Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
