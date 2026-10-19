#!/usr/bin/env bash
# Structural validation for gcp-08-01-slo-and-alerting-policy-json.
#
# Checks that the 4 deliverables exist, the JSON files parse and carry the
# expected top-level fields for a Cloud Monitoring alerting policy and a
# Cloud Logging log-based metric, and that the ADR + README-INTENT include
# the mandatory sections and keywords.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP project — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-08-slo}"
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

# --- alerting-policy.json ---------------------------------------------------
F1="$BASE/alerting-policy.json"
if check_file_exists "$F1"; then
  check_jq_valid "$F1" || true
  check_jq_contains "$F1" '(.displayName // "") | type == "string" and length > 0' 'has non-empty displayName'
  check_jq_contains "$F1" '(.combiner // "") | (. == "AND" or . == "OR" or . == "AND_WITH_MATCHING_RESOURCE")' 'combiner is AND/OR/AND_WITH_MATCHING_RESOURCE'
  check_jq_contains "$F1" '(.conditions // []) | length >= 1' 'has at least one condition'
  check_jq_contains "$F1" '[.conditions[] | has("conditionThreshold") or has("conditionAbsent") or has("conditionMatchedLog") or has("conditionMonitoringQueryLanguage") or has("conditionPrometheusQueryLanguage")] | any' 'uses a supported condition type'
  check_jq_contains "$F1" '(.notificationChannels // []) | length >= 1' 'has at least one notificationChannel'
  check_jq_contains "$F1" '[.notificationChannels[]] | any(contains("notificationChannels/"))' 'notificationChannels reference the channel path'
  check_jq_contains "$F1" '(.documentation.content // "") | length > 0' 'documentation.content is non-empty (runbook)'
  check_jq_contains "$F1" '(.alertStrategy.autoClose // "") | length > 0' 'alertStrategy.autoClose set'
  # Must target a Cloud Run / Cloud Monitoring metric (string match on filter or query).
  if grep -qE '(run\.googleapis\.com|select_slo_|slo_burn_rate|logging\.googleapis\.com)' "$F1"; then
    echo "  OK   $F1: filter mentions Cloud Run/SLO/Logging metric"
  else
    echo "  FAIL $F1: filter does not mention Cloud Run / SLO burn rate / Logging metric"
    fail=$((fail+1))
  fi
  # Must NOT contain a numeric-looking real-world project id (we require placeholder).
  if grep -qE '"projects/[a-z][-a-z0-9]{5,}/' "$F1" \
     && ! grep -q '"projects/PROJECT_ID/' "$F1"; then
    echo "  FAIL $F1: appears to reference a non-placeholder project; use PROJECT_ID"
    fail=$((fail+1))
  else
    echo "  OK   $F1: uses PROJECT_ID placeholder (no real project id)"
  fi
fi

# --- logs-based-metric.json -------------------------------------------------
F2="$BASE/logs-based-metric.json"
if check_file_exists "$F2"; then
  check_jq_valid "$F2" || true
  check_jq_contains "$F2" '(.name // "") | type == "string" and length > 0' 'has non-empty name'
  check_jq_contains "$F2" '(.description // "") | type == "string" and length > 0' 'has non-empty description'
  check_jq_contains "$F2" '(.filter // "") | type == "string" and length > 0' 'has non-empty filter'
  check_jq_contains "$F2" '(.metricDescriptor.metricKind // "") | (. == "DELTA" or . == "CUMULATIVE" or . == "GAUGE")' 'metricDescriptor.metricKind is DELTA/CUMULATIVE/GAUGE'
  check_jq_contains "$F2" '(.metricDescriptor.valueType // "") | (. == "INT64" or . == "DOUBLE" or . == "DISTRIBUTION")' 'metricDescriptor.valueType is INT64/DOUBLE/DISTRIBUTION'
  check_jq_contains "$F2" '(.labelExtractors // {}) | length >= 1' 'has at least one labelExtractor'
  # Filter should mention a reasonable resource.type (cloud_run_revision, k8s_container, etc.).
  if grep -qE 'resource\.type[[:space:]]*=' "$F2"; then
    echo "  OK   $F2: filter constrains resource.type"
  else
    echo "  FAIL $F2: filter does not constrain resource.type (metric would match too broadly)"
    fail=$((fail+1))
  fi
fi

# --- SLO-ADR.md -------------------------------------------------------------
F3="$BASE/SLO-ADR.md"
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
  # Must mention SLI, SLO, error budget or burn rate, goal, Cloud Run, checkout, rolling period.
  for kw in "SLI" "SLO" "Cloud Run" "checkout" "99.9"; do
    if grep -q "$kw" "$F3"; then
      echo "  OK   $F3 mentions '${kw}'"
    else
      echo "  FAIL $F3 does not mention '${kw}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'burn[ -]?rate|error[ _-]?budget' "$F3"; then
    echo "  OK   $F3 mentions burn rate / error budget"
  else
    echo "  FAIL $F3 does not mention burn rate / error budget"
    fail=$((fail+1))
  fi
  if grep -qiE '(30[ -]?d[ií]as?|30 ?days|rolling.*30|7[ -]?d[ií]as?|7 ?days)' "$F3"; then
    echo "  OK   $F3 defines a rolling period (7 or 30 days)"
  else
    echo "  FAIL $F3 does not define a rolling period (7 or 30 days)"
    fail=$((fail+1))
  fi
  # Alternatives: at least 2 listed.
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
  for section in "alerting-policy" "logs-based-metric" "SLO"; do
    if grep -qE "^#+ .*${section}" "$F4"; then
      echo "  OK   $F4 has section for '${section}'"
    else
      echo "  FAIL $F4 missing section for '${section}'"
      fail=$((fail+1))
    fi
  done
  for kw in "burn rate" "notificationChannels" "documentation"; do
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
