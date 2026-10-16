#!/usr/bin/env bash
# Validate helm-05-01-env-overrides-dev-stg-prod.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# helm template output into `grep -q`. If `grep -q` finds a match early and
# exits before helm finishes writing, helm receives SIGPIPE (exit 141), which
# pipefail would spuriously surface as a failure.

ACTIVITY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHART_DIR="${CHART_DIR:-starter/mychart}"
CHART_PATH="$ACTIVITY_DIR/$CHART_DIR"

passed=0
failed=0
report=""

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is required but not found in PATH." >&2
  exit 2
fi

if [ ! -d "$CHART_PATH" ]; then
  echo "ERROR: chart dir not found: $CHART_PATH" >&2
  echo "Set CHART_DIR to override (e.g. CHART_DIR=solution/mychart bash tests/validate.sh)." >&2
  exit 2
fi

tmp_out="$(mktemp -t helm-05-01-XXXXXX.yaml)"
trap 'rm -f "$tmp_out"' EXIT

render() {
  # $1 label, rest: args appended to helm template
  local label="$1"; shift
  if ! helm template demo "$CHART_PATH" "$@" >"$tmp_out" 2>/dev/null; then
    report+="$label: FAIL (helm template errored)\n"
    failed=$((failed+1))
    return 1
  fi
  return 0
}

check_match() {
  # $1 label, $2 expected substring
  local label="$1"
  local expected="$2"
  if grep -q "$expected" "$tmp_out"; then
    report+="$label: OK ($expected)\n"
    passed=$((passed+1))
  else
    report+="$label: FAIL (missing: $expected)\n"
    failed=$((failed+1))
  fi
}

# --- Scenario 1: defaults ---
if render "Scenario 1 defaults" ; then
  check_match "Scenario 1 defaults [replicas=1]" 'replicas: "1"'
  check_match "Scenario 1 defaults [logLevel=debug]" 'logLevel: "debug"'
fi

# --- Scenario 2: dev ---
if render "Scenario 2 dev" -f "$CHART_PATH/values-dev.yaml" ; then
  check_match "Scenario 2 dev [replicas=1]" 'replicas: "1"'
  check_match "Scenario 2 dev [logLevel=debug]" 'logLevel: "debug"'
fi

# --- Scenario 3: stg ---
if render "Scenario 3 stg" -f "$CHART_PATH/values-stg.yaml" ; then
  check_match "Scenario 3 stg [replicas=2]" 'replicas: "2"'
  check_match "Scenario 3 stg [logLevel=info]" 'logLevel: "info"'
  check_match "Scenario 3 stg [memory=128Mi]" 'memory: "128Mi"'
fi

# --- Scenario 4: prod ---
if render "Scenario 4 prod" -f "$CHART_PATH/values-prod.yaml" ; then
  check_match "Scenario 4 prod [replicas=5]" 'replicas: "5"'
  check_match "Scenario 4 prod [logLevel=info]" 'logLevel: "info"'
  check_match "Scenario 4 prod [memory=256Mi]" 'memory: "256Mi"'
  check_match "Scenario 4 prod [image.tag=1.0.0]" 'image: "ghcr.io/acme/myapp:1.0.0"'
fi

# --- Scenario 5: --set wins over prod ---
if render "Scenario 5 --set override" -f "$CHART_PATH/values-prod.yaml" --set image.tag=1.2.3 ; then
  check_match "Scenario 5 [--set wins]" 'image: "ghcr.io/acme/myapp:1.2.3"'
fi

echo ""
printf "%b" "$report"
echo ""
echo "Passed: $passed    Failed: $failed"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
echo "All scenarios OK."
exit 0
