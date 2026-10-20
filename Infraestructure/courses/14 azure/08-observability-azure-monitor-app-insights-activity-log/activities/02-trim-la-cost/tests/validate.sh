#!/usr/bin/env bash
# Structural validation for az-08-02-trim-la-cost.
#
# Checks that the 4 deliverables exist and carry the minimum structure:
#   - cost-trim-plan.md       : plan with the 5 levers + sections
#   - diagnostic-settings.json: filtered ARM resource
#   - la-cost-queries.kql     : >=3 KQL queries against Usage/AzureDiagnostics
#   - README-INTENT.md        : section per file + required mentions
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-08-02}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
    return 0
  else
    echo "  FAIL $(basename "$f") does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_grep() {
  local f="$1"
  local pat="$2"
  local label="$3"
  if grep -qE "$pat" "$f"; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (pattern: $pat)"
    fail=$((fail+1))
  fi
}

check_grep_i() {
  local f="$1"
  local pat="$2"
  local label="$3"
  if grep -qiE "$pat" "$f"; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (pattern i: $pat)"
    fail=$((fail+1))
  fi
}

check_jq_valid() {
  local f="$1"
  if jq empty "$f" >/dev/null 2>&1; then
    echo "  OK   $(basename "$f") is valid JSON"
    return 0
  else
    echo "  FAIL $(basename "$f") is not valid JSON"
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
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

# --- cost-trim-plan.md ---------------------------------------------------
F_P="$BASE/cost-trim-plan.md"
if check_file_exists "$F_P"; then
  check_grep_i "$F_P" '^#+ .*(cost|coste).*Log +Analytics|^#+ .*Log +Analytics.*(cost|coste)' 'title mentions Log Analytics and cost/coste'
  check_grep_i "$F_P" '^#+ *(Contexto|Context)\b'      'has Contexto/Context section'
  check_grep_i "$F_P" '^#+ *(Diagn[oó]stico|Diagnosis)\b' 'has Diagnostico/Diagnosis section'
  check_grep_i "$F_P" '^#+ *(Palancas|Levers)\b'       'has Palancas/Levers section'
  check_grep_i "$F_P" '^#+ *(Plan|Rollout)\b'          'has Plan/Rollout section'
  check_grep_i "$F_P" '^#+ *(Riesgos|Risks)\b'         'has Riesgos/Risks section'
  # Five levers by name.
  check_grep   "$F_P" 'Basic +Logs'                    'mentions Basic Logs'
  check_grep   "$F_P" 'Archive'                        'mentions Archive'
  check_grep_i "$F_P" 'sampling'                       'mentions sampling'
  check_grep_i "$F_P" 'dailyQuotaGb|daily +cap'        'mentions dailyQuotaGb or daily cap'
  check_grep_i "$F_P" 'diagnosticSettings|diagnostic +settings' 'mentions diagnosticSettings'
  # Usage table + a candidate table.
  check_grep   "$F_P" '\bUsage\b'                      'mentions Usage table'
  check_grep_i "$F_P" 'AppRequests|AzureDiagnostics'   'mentions AppRequests or AzureDiagnostics'
  # Numeric savings estimation (any % followed by digits).
  if grep -qE '[0-9]+ *%|%[0-9]+' "$F_P"; then
    echo "  OK   $(basename "$F_P"): mentions a numeric % savings estimate"
  else
    echo "  FAIL $(basename "$F_P"): does not include any numeric % savings estimate"
    fail=$((fail+1))
  fi
fi

# --- diagnostic-settings.json -------------------------------------------
F_DS="$BASE/diagnostic-settings.json"
if check_file_exists "$F_DS"; then
  check_jq_valid "$F_DS" || true
  check_jq_contains "$F_DS" '.type == "Microsoft.Insights/diagnosticSettings"' 'type == Microsoft.Insights/diagnosticSettings'
  check_jq_contains "$F_DS" 'has("apiVersion") and (.apiVersion | length > 0)' 'has non-empty apiVersion'
  check_jq_contains "$F_DS" 'has("name") and (.name | length > 0)'             'has non-empty name'
  check_jq_contains "$F_DS" '.properties.workspaceId | type == "string" and length > 0' 'has properties.workspaceId'
  check_jq_contains "$F_DS" '.properties.workspaceId | contains("/providers/Microsoft.OperationalInsights/workspaces/")' 'workspaceId points to a Log Analytics workspace'
  check_jq_contains "$F_DS" '(.properties.logs | type == "array") and (.properties.logs | length >= 2)' 'logs is array with >= 2 entries'
  check_jq_contains "$F_DS" '[.properties.logs[] | has("category") and has("enabled")] | all' 'every logs entry has category + enabled'
  check_jq_contains "$F_DS" '[.properties.logs[].enabled] | any(. == false)' 'at least one log category is disabled (filtering demonstrated)'
  check_jq_contains "$F_DS" '.properties | has("metrics")' 'properties has metrics key'
  check_jq_contains "$F_DS" '[.properties.metrics[]? | select(.category == "AllMetrics") | .enabled] | any(. == false)' 'metrics AllMetrics is explicitly disabled (saving pattern)'
fi

# --- la-cost-queries.kql -------------------------------------------------
F_K="$BASE/la-cost-queries.kql"
if check_file_exists "$F_K"; then
  check_grep "$F_K" '\bUsage\b'                      'uses Usage table'
  check_grep "$F_K" 'sum\(Quantity\)'                'uses sum(Quantity) (GB computation)'
  check_grep "$F_K" 'IsBillable *== *true'           'filters by IsBillable == true'
  check_grep "$F_K" 'by +DataType'                   'groups by DataType'
  check_grep "$F_K" '\btop\b|\border +by\b'          'uses top or order by'
  # At least 3 queries by separators or top-level tables.
  sep=$(grep -cE '^//---' "$F_K" || true)
  tops=$(grep -cE '^(Usage|AzureDiagnostics|AzureActivity|AppRequests|AppDependencies|Heartbeat|Perf|InsightsMetrics|let\b)' "$F_K" || true)
  if [ "$sep" -ge 2 ] || [ "$tops" -ge 3 ]; then
    echo "  OK   $(basename "$F_K"): contains at least 3 queries (separators=${sep}, top-level starts=${tops})"
  else
    echo "  FAIL $(basename "$F_K"): fewer than 3 queries detected (separators=${sep}, top-level starts=${tops})"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "cost-trim-plan" "diagnostic-settings" "la-cost-queries"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  for term in "Log Analytics" "Diagnostic Settings" "KQL" "Usage"; do
    if grep -q "$term" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${term}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${term}'"
      fail=$((fail+1))
    fi
  done
fi

# --- Repo hygiene: ANALYSIS.md must not exist ----------------------------
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE contains ANALYSIS.md — this repo convention uses cost-trim-plan.md + README-INTENT.md."
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md in base (convention: cost-trim-plan.md + README-INTENT.md)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Plan, diagnosticSettings JSON, KQL y README-INTENT.md pasan validacion estructural."
echo "        Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
