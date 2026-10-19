#!/usr/bin/env bash
# Structural validation for az-08-01-instrument-capstone-with-app-insights.
#
# Checks that the 5 deliverables exist and carry the minimum structure
# required by the brief:
#   - otel-walkthrough.md    : OTel/App Insights/Log Analytics walkthrough
#   - log-analytics-workspace.json : ARM resource with sku + retention
#   - app-insights-alert.json      : scheduledQueryRules with KQL + scope
#   - kql-queries.kql              : >=3 KQL queries using the minimum ops
#   - README-INTENT.md             : section per file + required mentions
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-08-01}"
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

# --- otel-walkthrough.md -------------------------------------------------
F_W="$BASE/otel-walkthrough.md"
if check_file_exists "$F_W"; then
  check_grep_i   "$F_W" '^#+ .*OpenTelemetry'                 'has OpenTelemetry title/heading'
  check_grep_i   "$F_W" '^#+ *Prerrequisitos|^#+ *Prerequisites' 'has Prerrequisitos/Prerequisites section'
  check_grep_i   "$F_W" '^#+ *Instalaci[oó]n|^#+ *Install'    'has Instalacion/Install section'
  check_grep_i   "$F_W" '^#+ *Configuraci[oó]n|^#+ *Configuration' 'has Configuracion/Configuration section'
  check_grep_i   "$F_W" '^#+ *Verificaci[oó]n|^#+ *Verification' 'has Verificacion/Verification section'
  check_grep     "$F_W" 'azure-monitor-opentelemetry'         'mentions azure-monitor-opentelemetry package'
  check_grep     "$F_W" 'configure_azure_monitor'             'shows configure_azure_monitor call'
  check_grep_i   "$F_W" 'connection +string'                  'mentions connection string'
  check_grep     "$F_W" 'AppRequests'                         'mentions AppRequests table'
  # At least one other App Insights table.
  if grep -qE 'AppDependencies|AppExceptions|AppTraces|AppCustomEvents' "$F_W"; then
    echo "  OK   $(basename "$F_W"): mentions a second App Insights table"
  else
    echo "  FAIL $(basename "$F_W"): must mention a second App Insights table (AppDependencies/AppExceptions/AppTraces/AppCustomEvents)"
    fail=$((fail+1))
  fi
  # No real-looking GUIDs (full 8-4-4-4-12 patterns that are NOT clearly placeholders).
  if grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$F_W" \
     | grep -v -iE 'redacted|placeholder|example' | grep -q .; then
    echo "  FAIL $(basename "$F_W"): contains what looks like a real GUID (tenant/subscription/ikey)."
    echo "        Replace with REDACTED-... placeholders."
    fail=$((fail+1))
  else
    echo "  OK   $(basename "$F_W"): no real-looking GUIDs"
  fi
fi

# --- log-analytics-workspace.json ---------------------------------------
F_LA="$BASE/log-analytics-workspace.json"
if check_file_exists "$F_LA"; then
  check_jq_valid "$F_LA" || true
  check_jq_contains "$F_LA" '.type == "Microsoft.OperationalInsights/workspaces"' 'type == Microsoft.OperationalInsights/workspaces'
  check_jq_contains "$F_LA" 'has("apiVersion") and (.apiVersion | length > 0)' 'has non-empty apiVersion'
  check_jq_contains "$F_LA" 'has("name") and (.name | length > 0)'             'has non-empty name'
  check_jq_contains "$F_LA" 'has("location") and (.location | length > 0)'     'has non-empty location'
  check_jq_contains "$F_LA" '.properties.sku.name | length > 0'                'has properties.sku.name'
  check_jq_contains "$F_LA" '.properties.retentionInDays >= 30 and .properties.retentionInDays <= 730' 'retentionInDays in [30, 730]'
  check_jq_contains "$F_LA" '.properties | has("publicNetworkAccessForIngestion")' 'has publicNetworkAccessForIngestion'
  check_jq_contains "$F_LA" '.properties | has("publicNetworkAccessForQuery")'     'has publicNetworkAccessForQuery'
fi

# --- app-insights-alert.json --------------------------------------------
F_AL="$BASE/app-insights-alert.json"
if check_file_exists "$F_AL"; then
  check_jq_valid "$F_AL" || true
  check_jq_contains "$F_AL" '.type == "Microsoft.Insights/scheduledQueryRules"' 'type == Microsoft.Insights/scheduledQueryRules'
  check_jq_contains "$F_AL" 'has("apiVersion") and (.apiVersion | length > 0)'  'has non-empty apiVersion'
  check_jq_contains "$F_AL" '.properties.severity >= 0 and .properties.severity <= 4' 'severity in [0,4]'
  check_jq_contains "$F_AL" '.properties.enabled == true'                        'enabled == true'
  check_jq_contains "$F_AL" '.properties.evaluationFrequency | test("^PT[0-9]+[MH]$")' 'evaluationFrequency is ISO 8601 PT#M/PT#H'
  check_jq_contains "$F_AL" '.properties.windowSize | test("^PT[0-9]+[MH]$")'          'windowSize is ISO 8601 PT#M/PT#H'
  check_jq_contains "$F_AL" '(.properties.criteria.allOf | type == "array") and (.properties.criteria.allOf | length >= 1)' 'criteria.allOf is a non-empty array'
  check_jq_contains "$F_AL" '[.properties.criteria.allOf[] | has("query")] | all'      'every criteria entry has a query'
  check_jq_contains "$F_AL" '(.properties.scopes | type == "array") and (.properties.scopes | length >= 1)' 'scopes is a non-empty array'
  check_jq_contains "$F_AL" '[.properties.scopes[]] | any(contains("/providers/Microsoft.OperationalInsights/workspaces/"))' 'scopes points to a Log Analytics workspace'
  check_jq_contains "$F_AL" '.properties.actions | has("actionGroups")' 'actions has actionGroups key'
fi

# --- kql-queries.kql -----------------------------------------------------
F_KQL="$BASE/kql-queries.kql"
if check_file_exists "$F_KQL"; then
  # Count queries: separators or just by content.
  check_grep   "$F_KQL" 'AppRequests'      'uses AppRequests table'
  check_grep   "$F_KQL" 'percentile\('     'uses percentile(...) aggregation'
  check_grep   "$F_KQL" '\bjoin\b'         'uses join operator'
  check_grep   "$F_KQL" 'bin\(TimeGenerated,' 'uses bin(TimeGenerated, ...)'
  check_grep   "$F_KQL" '\bsummarize\b'    'uses summarize'
  # At least 3 queries: either 3 "//---" separators or 3 top-level KQL blocks heuristically.
  sep=$(grep -cE '^//---' "$F_KQL" || true)
  tops=$(grep -cE '^(AppRequests|AppDependencies|AppExceptions|AppTraces|AzureActivity|Usage|Heartbeat|AppMetrics|AppPageViews|AppAvailabilityResults|AppCustomEvents)\b' "$F_KQL" || true)
  if [ "$sep" -ge 2 ] || [ "$tops" -ge 3 ]; then
    echo "  OK   $(basename "$F_KQL"): contains at least 3 queries (separators=${sep}, top-level tables=${tops})"
  else
    echo "  FAIL $(basename "$F_KQL"): fewer than 3 queries detected (separators=${sep}, top-level tables=${tops})"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "otel-walkthrough" "log-analytics-workspace" "app-insights-alert" "kql-queries"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  for term in "OpenTelemetry" "Application Insights" "Log Analytics" "KQL"; do
    if grep -q "$term" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${term}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${term}'"
      fail=$((fail+1))
    fi
  done
fi

# --- Repo hygiene: ANALYSIS.md must not exist in BASE --------------------
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE contains ANALYSIS.md — this repo convention uses README-INTENT.md instead."
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md in base (convention: README-INTENT.md)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Walkthrough, JSON ARM, KQL y README-INTENT.md pasan validacion estructural."
echo "        Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
