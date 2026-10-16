#!/usr/bin/env bash
# Structural validator for the switch-vendor exercise.
#
# Usage: bash validate.sh [WORK_DIR]
# Default: /tmp/otel-14-02
#
# Checks:
#   - WORK_DIR contains collector/collector-datadog.yaml and collector/MIGRATION.md.
#   - collector-datadog.yaml is valid YAML (python3 + yaml).
#   - It uses the `datadog` exporter.
#   - It references ${env:DD_API_KEY} (no literal API key).
#   - It preserves cost-control processors: memory_limiter, batch, tail_sampling, attributes/drop-high-card.
#   - All 3 pipelines (traces, metrics, logs) route to `datadog`.
#   - MIGRATION.md contains sections: Context, Decision, Steps, Verification, Rollback.
#   - src/ is byte-identical to the starter (vendor neutrality: no code change).
#
# Note: we do NOT enable `set -o pipefail`. Several checks use `grep -q` which
# can SIGPIPE upstream and pipefail would spuriously fail.

WORK_DIR="${1:-/tmp/otel-14-02}"
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_DIR="$(cd -- "${SCRIPT_DIR}/../starter" && pwd)"

passed=0
failed=0
report=""

ok()  { report+="OK   — $1\n"; passed=$((passed+1)); }
bad() { report+="FAIL — $1 — $2\n"; failed=$((failed+1)); }

CFG="$WORK_DIR/collector/collector-datadog.yaml"
MIG="$WORK_DIR/collector/MIGRATION.md"

echo "== Validating switch-vendor exercise at $WORK_DIR =="

# ----- Check 1: files exist
if [ -f "$CFG" ]; then
  ok "collector-datadog.yaml exists"
else
  bad "collector-datadog.yaml missing" "expected at $CFG"
fi
if [ -f "$MIG" ]; then
  ok "MIGRATION.md exists"
else
  bad "MIGRATION.md missing" "expected at $MIG"
fi

# ----- Check 2: valid YAML
if [ -f "$CFG" ]; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$CFG'))" 2>/dev/null; then
    ok "collector-datadog.yaml is valid YAML"
  else
    bad "YAML parse error" "python3 yaml.safe_load failed on $CFG"
  fi
fi

# ----- Check 3: uses `datadog` exporter
if [ -f "$CFG" ] && grep -Eq '^  datadog:' "$CFG"; then
  ok "exporter 'datadog' declared"
else
  bad "no 'datadog' exporter" "expected a top-level 'datadog:' entry under exporters"
fi

# ----- Check 4: references ${env:DD_API_KEY}
if [ -f "$CFG" ] && grep -q '${env:DD_API_KEY}' "$CFG"; then
  ok "API key referenced via \${env:DD_API_KEY}"
else
  bad "API key not externalised" "expected '\${env:DD_API_KEY}' reference"
fi

# ----- Check 5: no literal 32-hex-char keys (very loose heuristic)
if [ -f "$CFG" ] && grep -Eq 'key:[[:space:]]+[a-f0-9]{32,}' "$CFG"; then
  bad "possible literal API key detected" "remove it; use env reference"
else
  ok "no literal API key detected"
fi

# ----- Check 6: cost-control processors preserved
if [ -f "$CFG" ]; then
  missing_proc=""
  for proc in memory_limiter batch tail_sampling attributes/drop-high-card; do
    if ! grep -Eq "^  ${proc}:" "$CFG"; then
      missing_proc+=" $proc"
    fi
  done
  if [ -z "$missing_proc" ]; then
    ok "cost-control processors preserved (memory_limiter, batch, tail_sampling, attributes/drop-high-card)"
  else
    bad "missing processors" "$missing_proc"
  fi
fi

# ----- Check 7: all 3 pipelines route to datadog
if [ -f "$CFG" ]; then
  # Use python to count pipelines whose exporters list contains 'datadog'.
  pipelines_ok=$(python3 - "$CFG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
pipes = (data.get("service") or {}).get("pipelines") or {}
needed = {"traces", "metrics", "logs"}
hits = sum(1 for name in needed
           if name in pipes
           and "datadog" in (pipes[name].get("exporters") or []))
print(hits)
PY
)
  if [ "$pipelines_ok" = "3" ]; then
    ok "all 3 pipelines (traces, metrics, logs) route to 'datadog'"
  else
    bad "pipeline routing incomplete" "only $pipelines_ok/3 pipelines export to 'datadog'"
  fi
fi

# ----- Check 8: MIGRATION.md has required sections
if [ -f "$MIG" ]; then
  missing_sec=""
  for sec in Context Decision Steps Verification Rollback; do
    if ! grep -Eq "^## [0-9]+\\. ${sec}" "$MIG"; then
      missing_sec+=" $sec"
    fi
  done
  if [ -z "$missing_sec" ]; then
    ok "MIGRATION.md has Context, Decision, Steps, Verification, Rollback"
  else
    bad "MIGRATION.md missing sections" "$missing_sec"
  fi
fi

# ----- Check 9: src/ untouched vs starter
if [ -d "$WORK_DIR/src" ] && [ -d "$STARTER_DIR/src" ]; then
  diff_out=$(diff -r "$STARTER_DIR/src" "$WORK_DIR/src" 2>&1)
  if [ -z "$diff_out" ]; then
    ok "src/ is byte-identical to the starter (vendor-neutral: zero code change)"
  else
    bad "src/ was modified" "$(printf "%s" "$diff_out" | head -5)"
  fi
else
  bad "src/ missing" "expected both $STARTER_DIR/src and $WORK_DIR/src"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
