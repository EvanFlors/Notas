#!/usr/bin/env bash
# Smoke script for example 01. Builds dependencies and renders the consumer
# chart with the shared library. We do NOT enable `set -o pipefail` because
# some grep -q filters below close the pipe early and would mark upstream
# producers as spuriously failed.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

echo "== 1. Library chart on its own renders no resources =="
rendered=$(helm template probe ./platform-lib 2>/dev/null || true)
if [ -z "$(printf '%s' "$rendered" | tr -d '[:space:]')" ]; then
  echo "  OK   platform-lib produced no manifests (library chart behavior)"
else
  echo "  FAIL platform-lib produced manifests — not a library chart"
  exit 1
fi

echo "== 2. Build dependencies of the consumer chart =="
helm dependency build ./consumer-chart

echo "== 3. Render consumer chart =="
out=$(helm template demo ./consumer-chart)
printf '%s\n' "$out" | head -40

echo
echo "== 4. Assertions on rendered output =="

if printf '%s\n' "$out" | grep -q 'app.kubernetes.io/managed-by: Helm'; then
  echo "  OK   platform.labels injected managed-by"
else
  echo "  FAIL expected label 'app.kubernetes.io/managed-by: Helm'"
  exit 1
fi

if printf '%s\n' "$out" | grep -q 'platform.example.com/owner: "team-platform"'; then
  echo "  OK   custom platform label present"
else
  echo "  FAIL expected label 'platform.example.com/owner: \"team-platform\"'"
  exit 1
fi

if printf '%s\n' "$out" | grep -q 'name: demo-consumer-chart'; then
  echo "  OK   platform.fullname produced 'demo-consumer-chart'"
else
  echo "  FAIL expected resource name 'demo-consumer-chart'"
  exit 1
fi

echo
echo "OK: example 01 smoke passed."
