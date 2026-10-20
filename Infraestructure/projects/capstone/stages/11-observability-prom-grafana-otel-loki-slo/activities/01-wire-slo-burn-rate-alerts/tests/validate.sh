#!/usr/bin/env bash
# Validate cap-11-01-wire-slo-burn-rate-alerts.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `yq ... | grep -q ...`; if grep matches early, the upstream
# pipeline step may receive SIGPIPE (exit 141), and pipefail would turn that
# into a false negative.
set -eu

# Resolve the stage root as 3 levels up from this test file.
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE_ROOT="$(cd "$HERE/../../.." && pwd)"
OBS_DIR="$STAGE_ROOT/observability"
APP_DIR="$STAGE_ROOT/app"

passed=0
failed=0
report=""

ok()   { report+="  OK   $1"$'\n'; passed=$((passed+1)); }
bad()  { report+="  FAIL $1"$'\n'; failed=$((failed+1)); }
skip() { report+="  SKIP $1"$'\n'; }

echo "== Validating cap-11-01 (stage root: $STAGE_ROOT) =="

# --- 1. Required files exist and are non-empty ---
expected=(
  "observability/kube-prometheus-stack-values.yaml"
  "observability/servicemonitor.yaml"
  "observability/prometheusrule-slo.yaml"
  "observability/otel-collector-values.yaml"
  "observability/loki-values.yaml"
  "observability/tempo-values.yaml"
  "observability/grafana-dashboards/fastapi-golden-signals.json"
  "app/instrumentation.py"
  "README.md"
  "resources/links.md"
)
for rel in "${expected[@]}"; do
  f="$STAGE_ROOT/$rel"
  if [ -s "$f" ]; then
    ok "exists and non-empty: $rel"
  else
    bad "missing or empty: $rel"
  fi
done

# --- 2. YAML parses (requires yq, python3 or fallback to a very loose grep) ---
yaml_parser=""
if command -v yq >/dev/null 2>&1; then
  yaml_parser="yq"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  yaml_parser="python3"
fi

for rel in \
  "observability/kube-prometheus-stack-values.yaml" \
  "observability/servicemonitor.yaml" \
  "observability/prometheusrule-slo.yaml" \
  "observability/otel-collector-values.yaml" \
  "observability/loki-values.yaml" \
  "observability/tempo-values.yaml" \
  "activities/01-wire-slo-burn-rate-alerts/activity.yaml"
do
  f="$STAGE_ROOT/$rel"
  [ -f "$f" ] || continue
  case "$yaml_parser" in
    yq)
      if yq eval 'true' "$f" >/dev/null 2>&1; then
        ok "yaml parses: $rel"
      else
        bad "yaml parse error: $rel"
      fi
      ;;
    python3)
      if python3 -c "import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))" "$f" >/dev/null 2>&1; then
        ok "yaml parses: $rel"
      else
        bad "yaml parse error: $rel"
      fi
      ;;
    *)
      skip "yaml parser not available for $rel (install yq or python3+pyyaml)"
      ;;
  esac
done

# --- 3. PrometheusRule declares the 4 MWMBR alerts by name ---
PR="$STAGE_ROOT/observability/prometheusrule-slo.yaml"
if [ -f "$PR" ]; then
  for alert in HighErrorBudgetBurnFast HighErrorBudgetBurnMediumFast HighErrorBudgetBurnSlow HighErrorBudgetBurnVerySlow; do
    if grep -q "alert: $alert" "$PR"; then
      ok "PrometheusRule declares alert $alert"
    else
      bad "PrometheusRule missing alert $alert"
    fi
  done
  if grep -q "runbook_url" "$PR"; then
    ok "PrometheusRule includes runbook_url annotations"
  else
    bad "PrometheusRule should include runbook_url in annotations"
  fi
fi

# --- 4. promtool validation (SKIP if missing) ---
if command -v promtool >/dev/null 2>&1; then
  # Extract spec.groups and feed it to promtool as a Prometheus rules file.
  TMPRULES="$(mktemp)"
  if command -v yq >/dev/null 2>&1; then
    yq eval '.spec' "$PR" > "$TMPRULES"
  else
    cp "$PR" "$TMPRULES"
  fi
  if promtool check rules "$TMPRULES" >/dev/null 2>&1; then
    ok "promtool check rules passes"
  else
    bad "promtool check rules fails on prometheusrule-slo.yaml"
  fi
  rm -f "$TMPRULES"
else
  skip "promtool not installed; skipping rule validation"
fi

# --- 5. amtool validation on the Alertmanager fragment in kps values ---
KPS="$STAGE_ROOT/observability/kube-prometheus-stack-values.yaml"
if command -v amtool >/dev/null 2>&1 && command -v yq >/dev/null 2>&1; then
  TMPAM="$(mktemp)"
  yq eval '.alertmanager.config' "$KPS" > "$TMPAM"
  if amtool check-config "$TMPAM" >/dev/null 2>&1; then
    ok "amtool check-config passes"
  else
    bad "amtool check-config fails on alertmanager fragment"
  fi
  rm -f "$TMPAM"
else
  skip "amtool (or yq) not installed; skipping Alertmanager config validation"
fi

# --- 6. Dashboard JSON parses and declares the 4 Golden Signals panels ---
DASH="$STAGE_ROOT/observability/grafana-dashboards/fastapi-golden-signals.json"
if [ -f "$DASH" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert len(d.get('panels',[]))>=4" "$DASH" >/dev/null 2>&1; then
      ok "dashboard JSON parses and declares >=4 panels"
    else
      bad "dashboard JSON is invalid or has fewer than 4 panels"
    fi
  elif command -v jq >/dev/null 2>&1; then
    panels="$(jq '.panels | length' "$DASH" 2>/dev/null || echo 0)"
    if [ "${panels:-0}" -ge 4 ]; then
      ok "dashboard JSON declares $panels panels"
    else
      bad "dashboard JSON declares only ${panels:-0} panels"
    fi
  else
    skip "neither python3 nor jq available for dashboard check"
  fi
fi

# --- 7. instrumentation.py compiles (if python3 is available) ---
INS="$STAGE_ROOT/app/instrumentation.py"
if [ -f "$INS" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -m py_compile "$INS" >/dev/null 2>&1; then
      ok "app/instrumentation.py compiles"
    else
      bad "app/instrumentation.py has a syntax error"
    fi
  else
    skip "python3 not available; skipping instrumentation compile check"
  fi
fi

# --- 8. Hygiene: no obvious real secrets committed ---
if grep -R -nIE '(AKIA|ASIA)[0-9A-Z]{16}' "$STAGE_ROOT" >/dev/null 2>&1; then
  bad "possible AWS access key id found in stage files"
else
  ok "no AWS-looking access keys found"
fi
if grep -R -nIE 'ghp_[A-Za-z0-9]{30,}' "$STAGE_ROOT" >/dev/null 2>&1; then
  bad "possible GitHub token found in stage files"
else
  ok "no GitHub-looking personal access tokens found"
fi

# --- 9. ANALYSIS.md must NOT exist (per repo convention) ---
if find "$STAGE_ROOT" -maxdepth 3 -name 'ANALYSIS.md' -print -quit 2>/dev/null | grep -q .; then
  bad "ANALYSIS.md present (repo rule: do not create it)"
else
  ok "no ANALYSIS.md present"
fi

printf "%s" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
