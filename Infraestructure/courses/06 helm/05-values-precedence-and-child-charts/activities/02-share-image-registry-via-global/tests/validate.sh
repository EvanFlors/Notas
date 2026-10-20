#!/usr/bin/env bash
# Validate helm-05-02-share-image-registry-via-global.
#
# Note: we deliberately do NOT enable `set -o pipefail` because grep -q may
# close early, giving helm a SIGPIPE (exit 141) that pipefail would flag as
# a spurious failure.

ACTIVITY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Default: student works under starter/platform/
CHART_PATH="${CHART_DIR:-$ACTIVITY_DIR/starter/platform}"

passed=0
failed=0
report=""

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is required but not found in PATH." >&2
  exit 2
fi

if [ ! -d "$CHART_PATH" ]; then
  echo "ERROR: chart dir not found: $CHART_PATH" >&2
  echo "Create platform/ under starter/ or set CHART_DIR=/abs/path." >&2
  exit 2
fi

tmp_out="$(mktemp -t helm-05-02-XXXXXX.yaml)"
trap 'rm -f "$tmp_out"' EXIT

render() {
  local label="$1"; shift
  if ! helm template demo "$CHART_PATH" "$@" >"$tmp_out" 2>/dev/null; then
    report+="$label: FAIL (helm template errored)\n"
    failed=$((failed+1))
    return 1
  fi
  return 0
}

check_match() {
  local label="$1"
  local expected="$2"
  if grep -q "$expected" "$tmp_out"; then
    report+="$label: OK\n"
    passed=$((passed+1))
  else
    report+="$label: FAIL (missing: $expected)\n"
    failed=$((failed+1))
  fi
}

# --- Scenario A: defaults ---
if render "Scenario A defaults" ; then
  check_match "A web uses ghcr.io/acme/web:1.0.0" 'image: "ghcr.io/acme/web:1.0.0"'
  check_match "A worker uses ghcr.io/acme/worker:1.0.0" 'image: "ghcr.io/acme/worker:1.0.0"'
fi

# --- Scenario B: values-airgapped.yaml ---
if [ -f "$CHART_PATH/values-airgapped.yaml" ]; then
  if render "Scenario B airgapped" -f "$CHART_PATH/values-airgapped.yaml" ; then
    check_match "B web uses registry.internal/web" 'image: "registry.internal/web:1.0.0"'
    check_match "B worker uses registry.internal/worker" 'image: "registry.internal/worker:1.0.0"'
  fi
else
  report+="Scenario B: FAIL (values-airgapped.yaml missing)\n"
  failed=$((failed+1))
fi

# --- Scenario C: --set global.imageRegistry ---
if render "Scenario C --set override" --set global.imageRegistry=foo.io ; then
  check_match "C web uses foo.io/web" 'image: "foo.io/web:1.0.0"'
  check_match "C worker uses foo.io/worker" 'image: "foo.io/worker:1.0.0"'
fi

# --- Antipattern check: no per-subchart imageRegistry in parent values.yaml ---
# We look for a `web:` or `worker:` block in the parent values.yaml that
# contains an `imageRegistry` key — a sign the student duplicated the value
# instead of using `global:`.
parent_values="$CHART_PATH/values.yaml"
if [ -f "$parent_values" ]; then
  if grep -E '^\s*(web|worker):' "$parent_values" >/dev/null 2>&1; then
    # Only flag if an imageRegistry appears somewhere inside those blocks
    if grep -E '^\s*imageRegistry:' "$parent_values" >/dev/null 2>&1; then
      # Make sure the one we see is NOT under `global:` by counting indentation.
      # Heuristic: if an imageRegistry line is indented beyond `global:` scope
      # and sits under a web/worker block, warn.
      awk '
        /^web:|^worker:/ { in_sub=1; next }
        /^[A-Za-z]/ && !/^web:|^worker:/ { in_sub=0 }
        in_sub && /imageRegistry:/ { found=1 }
        END { exit (found?0:1) }
      ' "$parent_values"
      if [ $? -eq 0 ]; then
        report+="Antipattern: imageRegistry duplicated under a subchart block in platform/values.yaml\n"
        failed=$((failed+1))
      else
        report+="Antipattern check: OK (no per-subchart imageRegistry duplication)\n"
        passed=$((passed+1))
      fi
    else
      report+="Antipattern check: OK\n"
      passed=$((passed+1))
    fi
  else
    report+="Antipattern check: OK\n"
    passed=$((passed+1))
  fi
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
