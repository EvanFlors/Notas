#!/usr/bin/env bash
# Structural validation for helm-09-01-add-full-test-pipeline.
# Checks that the student has produced all 4 artifacts of the pipeline:
#   1. ct.yaml at the root
#   2. .github/workflows/*.yaml with lint, unittest and ct install (matrix)
#   3. charts/<chart>/tests/*_test.yaml with >= 3 tests
#   4. charts/<chart>/README.md with a "Supported Kubernetes versions" section
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT run `ct install` or `helm unittest` — those are opt-in and expensive.
# Does NOT grade semantic correctness.

BASE="${1:-/tmp/helm-09-01}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Did you copy the starter?"
  exit 1
fi

# -------- 1. ct.yaml --------
CT="$BASE/ct.yaml"
if [ -f "$CT" ]; then
  echo "  OK   ct.yaml present"
  if grep -q "chart-dirs" "$CT" && grep -q "target-branch" "$CT"; then
    echo "  OK   ct.yaml has chart-dirs and target-branch"
  else
    echo "  FAIL ct.yaml missing chart-dirs or target-branch"
    fail=$((fail+1))
  fi
else
  echo "  FAIL ct.yaml missing at repo root"
  fail=$((fail+1))
fi

# -------- 2. workflow --------
WF_DIR="$BASE/.github/workflows"
WF=""
if [ -d "$WF_DIR" ]; then
  WF=$(find "$WF_DIR" -name '*.yaml' -o -name '*.yml' | head -1)
fi
if [ -n "$WF" ] && [ -f "$WF" ]; then
  echo "  OK   workflow present: $WF"
  if grep -q "helm lint" "$WF"; then
    echo "  OK   workflow runs helm lint"
  else
    echo "  FAIL workflow does not mention 'helm lint'"
    fail=$((fail+1))
  fi
  if grep -q "helm-unittest\|helm unittest" "$WF"; then
    echo "  OK   workflow runs helm unittest (or installs the plugin)"
  else
    echo "  FAIL workflow does not run helm unittest"
    fail=$((fail+1))
  fi
  if grep -q "chart-testing-action\|ct install\|ct lint" "$WF"; then
    echo "  OK   workflow uses chart-testing"
  else
    echo "  FAIL workflow does not use chart-testing (ct)"
    fail=$((fail+1))
  fi
  if grep -q "kind-action\|kindest/node" "$WF"; then
    echo "  OK   workflow uses kind"
  else
    echo "  FAIL workflow does not use kind (no cluster for ct install)"
    fail=$((fail+1))
  fi
  # Matrix with at least 2 K8s entries. Count occurrences of 'v1.N' across the file
  # (works both for one-per-line and inline list forms).
  k8s_hits=$(grep -oE 'v1\.[0-9]+' "$WF" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  k8s_hits=${k8s_hits:-0}
  if [ "$k8s_hits" -ge 2 ]; then
    echo "  OK   workflow declares at least 2 Kubernetes versions in matrix ($k8s_hits refs)"
  else
    echo "  FAIL workflow matrix has fewer than 2 Kubernetes versions ($k8s_hits refs)"
    fail=$((fail+1))
  fi
  if grep -q "fetch-depth: 0" "$WF"; then
    echo "  OK   workflow uses fetch-depth: 0 (ct can diff against target-branch)"
  else
    echo "  WARN workflow does not set fetch-depth: 0 — ct may not detect changed charts"
  fi
else
  echo "  FAIL no workflow file found under .github/workflows/"
  fail=$((fail+1))
fi

# -------- 3. unittest tests --------
CHART_DIR=""
for d in "$BASE"/charts/*/; do
  if [ -f "$d/Chart.yaml" ]; then CHART_DIR="$d"; break; fi
done
if [ -z "$CHART_DIR" ]; then
  echo "  FAIL no chart found under $BASE/charts/*/"
  fail=$((fail+1))
else
  echo "  OK   chart dir detected: $CHART_DIR"
  TESTS_DIR="$CHART_DIR/tests"
  if [ -d "$TESTS_DIR" ]; then
    tfiles=$(find "$TESTS_DIR" -name '*_test.yaml' | wc -l | tr -d ' ')
    if [ "$tfiles" -ge 1 ]; then
      echo "  OK   $tfiles helm-unittest test file(s) present"
      # Count 'it:' occurrences across all test files.
      it_count=$(grep -rhc '^\s*-\s*it:' "$TESTS_DIR" 2>/dev/null | awk '{s+=$1} END {print s+0}')
      if [ "$it_count" -ge 3 ]; then
        echo "  OK   total 'it:' tests >= 3 ($it_count)"
      else
        echo "  FAIL only $it_count 'it:' tests, expected >= 3"
        fail=$((fail+1))
      fi
    else
      echo "  FAIL no *_test.yaml files under $TESTS_DIR"
      fail=$((fail+1))
    fi
  else
    echo "  FAIL no tests/ directory under $CHART_DIR"
    fail=$((fail+1))
  fi

  # -------- 4. README with supported K8s versions --------
  CR="$CHART_DIR/README.md"
  if [ -f "$CR" ] && grep -qi "supported kubernetes versions" "$CR"; then
    echo "  OK   chart README documents Supported Kubernetes versions"
  else
    echo "  FAIL chart README missing or does not include 'Supported Kubernetes versions'"
    fail=$((fail+1))
  fi
fi

# -------- Tool presence (informational) --------
if command -v helm >/dev/null 2>&1; then
  echo "  INFO helm present: $(helm version --short 2>/dev/null || echo unknown)"
  if helm plugin list 2>/dev/null | grep -q unittest; then
    echo "  INFO helm-unittest plugin installed"
  else
    echo "  WARN helm-unittest plugin NOT installed (install with: helm plugin install https://github.com/helm-unittest/helm-unittest)"
  fi
else
  echo "  WARN helm not installed — tool-level checks skipped (SKIP graceful)"
fi
if command -v ct >/dev/null 2>&1; then
  echo "  INFO ct present: $(ct version 2>/dev/null | head -1)"
else
  echo "  WARN ct (chart-testing) not installed locally — the CI workflow installs it"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
