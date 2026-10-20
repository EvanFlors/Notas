#!/usr/bin/env bash
# Structural validation for sec-11-01-admission-policy-set-for-capstone.
# Checks files, YAML parseability (if python3 is available) and expected
# content markers. If kyverno-cli is present, also runs `kyverno apply` as a
# bonus semantic check; if kind/kubectl/kyverno are missing, SKIPS gracefully.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/sec-11-admission}"
fail=0

echo "== Structural validation for $BASE =="

check_file() {
  if [ -f "$1" ]; then
    echo "  OK   $1 exists"
  else
    echo "  FAIL $1 missing"
    fail=$((fail+1))
  fi
}

grep_in() {
  # grep_in <file> <regex> <label>
  if [ -f "$1" ] && grep -qiE "$2" "$1"; then
    echo "  OK   $3"
  else
    echo "  FAIL $3"
    fail=$((fail+1))
  fi
}

# 1. Expected tree.
check_file "$BASE/POLICIES.md"
check_file "$BASE/policies/01-require-labels.yaml"
check_file "$BASE/policies/02-disallow-latest-tag.yaml"
check_file "$BASE/policies/03-disallow-privileged.yaml"
check_file "$BASE/manifests/good-pod.yaml"
check_file "$BASE/manifests/bad-labels-pod.yaml"
check_file "$BASE/manifests/bad-latest-pod.yaml"
check_file "$BASE/manifests/bad-privileged-pod.yaml"

# 2. POLICIES.md must have the three required sections.
grep_in "$BASE/POLICIES.md" '^#+ *contrato' "POLICIES.md has 'Contrato' section"
grep_in "$BASE/POLICIES.md" '^#+ *rollout' "POLICIES.md has 'Rollout' section"
grep_in "$BASE/POLICIES.md" '^#+ *excepciones|^#+ *excepci' "POLICIES.md has 'Excepciones' section"

# 3. Each policy must be a Kyverno ClusterPolicy.
for p in "$BASE/policies/01-require-labels.yaml" \
         "$BASE/policies/02-disallow-latest-tag.yaml" \
         "$BASE/policies/03-disallow-privileged.yaml"; do
  grep_in "$p" '^kind: *ClusterPolicy' "$(basename "$p") kind=ClusterPolicy"
  grep_in "$p" 'kyverno\.io' "$(basename "$p") uses kyverno.io API"
  grep_in "$p" 'validationFailureAction' "$(basename "$p") declares validationFailureAction"
done

# 4. Policy intent markers.
grep_in "$BASE/policies/01-require-labels.yaml" 'owner|app' "require-labels mentions owner/app"
grep_in "$BASE/policies/02-disallow-latest-tag.yaml" 'latest' "disallow-latest-tag mentions latest"
grep_in "$BASE/policies/03-disallow-privileged.yaml" 'privileged' "disallow-privileged mentions privileged"

# 5. Manifests contain Pod kind.
for m in "$BASE/manifests/good-pod.yaml" \
         "$BASE/manifests/bad-labels-pod.yaml" \
         "$BASE/manifests/bad-latest-pod.yaml" \
         "$BASE/manifests/bad-privileged-pod.yaml"; do
  grep_in "$m" '^kind: *Pod' "$(basename "$m") kind=Pod"
done

# 6. YAML parse check (optional if python3+PyYAML available).
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  yaml_fail=0
  for f in "$BASE"/policies/*.yaml "$BASE"/manifests/*.yaml; do
    [ -f "$f" ] || continue
    if python3 -c "import sys,yaml;list(yaml.safe_load_all(open(sys.argv[1])))" "$f" >/dev/null 2>&1; then
      :
    else
      echo "  FAIL $f not valid YAML"
      yaml_fail=$((yaml_fail+1))
    fi
  done
  if [ "$yaml_fail" -eq 0 ]; then
    echo "  OK   all YAML files parse"
  else
    fail=$((fail+yaml_fail))
  fi
else
  echo "  SKIP YAML parse check (python3/PyYAML not available)"
fi

# 7. Bonus: kyverno apply offline (if CLI present).
if command -v kyverno >/dev/null 2>&1; then
  echo "  INFO kyverno CLI detected: running 'kyverno apply' (offline)"
  if kyverno apply "$BASE/policies/" --resource "$BASE/manifests/" >/tmp/sec-11-admission-kv.log 2>&1; then
    echo "  OK   kyverno apply ran (see /tmp/sec-11-admission-kv.log)"
  else
    # kyverno exits non-zero when any policy fails on any resource — expected.
    echo "  OK   kyverno apply ran with failures (expected: bad pods must fail)"
  fi
else
  echo "  SKIP kyverno CLI not installed (install from https://kyverno.io/docs/kyverno-cli/)"
fi

# 8. Bonus: kind + kubectl detection (purely informative).
if command -v kind >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  echo "  INFO kind + kubectl detected — in-cluster test possible (see README)"
else
  echo "  SKIP kind/kubectl not installed — in-cluster test skipped"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara POLICIES.md con solution/REFERENCE.md para autoevaluarte."
exit 0
