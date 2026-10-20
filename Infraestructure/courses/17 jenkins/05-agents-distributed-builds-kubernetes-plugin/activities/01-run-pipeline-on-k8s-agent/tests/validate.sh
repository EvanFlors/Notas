#!/usr/bin/env bash
# Structural validation for jk-05-01-run-pipeline-on-k8s-agent.
# Checks that podTemplate.yaml and Jenkinsfile exist, parse, and contain
# the minimum structure required by the Kubernetes plugin agent pattern:
# jnlp container + at least one build container with sleep infinity +
# restartPolicy Never + requests/limits; and a declarative pipeline that
# uses agent kubernetes + container('name') { sh ... }.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# The live `kind` lab is OPTIONAL: if `kind` is not installed, the live
# section is SKIPped (not counted as failure).

set -eu

BASE="${1:-/tmp/jk-05-k8s-agent}"
POD="$BASE/podTemplate.yaml"
JEN="$BASE/Jenkinsfile"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

# ---- podTemplate.yaml ----------------------------------------------------
if [ ! -f "$POD" ]; then
  echo "  FAIL $POD does not exist"
  fail=$((fail+1))
else
  echo "  OK   $POD exists"

  if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$POD" >/dev/null 2>&1; then
    echo "  OK   $POD is valid YAML"
  else
    echo "  FAIL $POD is not valid YAML"
    fail=$((fail+1))
  fi

  # kind == Pod
  if python3 -c "import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); import sys as s; s.exit(0 if d.get('kind')=='Pod' else 1)" "$POD" 2>/dev/null; then
    echo "  OK   kind == Pod"
  else
    echo "  FAIL kind must be 'Pod'"
    fail=$((fail+1))
  fi

  # apiVersion == v1
  if python3 -c "import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); import sys as s; s.exit(0 if d.get('apiVersion')=='v1' else 1)" "$POD" 2>/dev/null; then
    echo "  OK   apiVersion == v1"
  else
    echo "  FAIL apiVersion must be 'v1'"
    fail=$((fail+1))
  fi

  # restartPolicy: Never
  if python3 -c "import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); import sys as s; s.exit(0 if (d.get('spec') or {}).get('restartPolicy')=='Never' else 1)" "$POD" 2>/dev/null; then
    echo "  OK   spec.restartPolicy == Never"
  else
    echo "  FAIL spec.restartPolicy must be 'Never'"
    fail=$((fail+1))
  fi

  # at least 2 containers
  nc=$(python3 -c "import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); print(len((d.get('spec') or {}).get('containers') or []))" "$POD" 2>/dev/null || echo 0)
  if [ "$nc" -ge 2 ]; then
    echo "  OK   has at least 2 containers (${nc} found)"
  else
    echo "  FAIL has only ${nc} container(s); expected >= 2 (jnlp + build)"
    fail=$((fail+1))
  fi

  # jnlp container present with inbound-agent image
  if python3 -c "
import sys, yaml
d=yaml.safe_load(open(sys.argv[1]))
cs=(d.get('spec') or {}).get('containers') or []
ok=any(c.get('name')=='jnlp' and 'inbound-agent' in (c.get('image') or '') for c in cs)
sys.exit(0 if ok else 1)
" "$POD" 2>/dev/null; then
    echo "  OK   has 'jnlp' container with jenkins/inbound-agent image"
  else
    echo "  FAIL missing 'jnlp' container with a jenkins/inbound-agent image"
    fail=$((fail+1))
  fi

  # at least one non-jnlp container with sleep-like command AND requests+limits
  if python3 -c "
import sys, yaml
d=yaml.safe_load(open(sys.argv[1]))
cs=(d.get('spec') or {}).get('containers') or []
def long_running(c):
    cmd=c.get('command') or []
    args=c.get('args') or []
    joined=' '.join(cmd+args).lower()
    return any(k in joined for k in ['sleep infinity','sleep 999','tail -f /dev/null','cat'])
def resources_ok(c):
    r=c.get('resources') or {}
    return bool(r.get('requests')) and bool(r.get('limits'))
ok=any(c.get('name')!='jnlp' and long_running(c) and resources_ok(c) for c in cs)
sys.exit(0 if ok else 1)
" "$POD" 2>/dev/null; then
    echo "  OK   has at least one non-jnlp build container with long-running command AND requests+limits"
  else
    echo "  FAIL no non-jnlp build container with long-running command AND requests+limits"
    fail=$((fail+1))
  fi
fi

# ---- Jenkinsfile --------------------------------------------------------
if [ ! -f "$JEN" ]; then
  echo "  FAIL $JEN does not exist"
  fail=$((fail+1))
else
  echo "  OK   $JEN exists"

  # pipeline { ... }
  if grep -qE '^\s*pipeline\s*\{' "$JEN"; then
    echo "  OK   Jenkinsfile declares a 'pipeline' block"
  else
    echo "  FAIL Jenkinsfile missing a 'pipeline { ... }' block"
    fail=$((fail+1))
  fi

  # agent { kubernetes { ... } }
  if grep -qE 'agent\s*\{[^}]*kubernetes' "$JEN" || grep -qE 'kubernetes\s*\{' "$JEN"; then
    echo "  OK   Jenkinsfile uses 'agent { kubernetes { ... } }'"
  else
    echo "  FAIL Jenkinsfile does not use 'agent { kubernetes { ... } }'"
    fail=$((fail+1))
  fi

  # yaml or yamlFile reference
  if grep -qE '(yamlFile|yaml\s*[\x27"])' "$JEN"; then
    echo "  OK   Jenkinsfile references a pod yaml (yamlFile or inline yaml)"
  else
    echo "  FAIL Jenkinsfile does not include 'yamlFile' or inline 'yaml'"
    fail=$((fail+1))
  fi

  # stages / stage
  if grep -qE '^\s*stages\s*\{' "$JEN" && grep -qE '^\s*stage\(' "$JEN"; then
    echo "  OK   Jenkinsfile has stages { stage(...) ... }"
  else
    echo "  FAIL Jenkinsfile missing 'stages { stage(...) ... }'"
    fail=$((fail+1))
  fi

  # container('name') { sh ... } — at least one
  if grep -qE "container\(['\"][a-zA-Z0-9_-]+['\"]\)\s*\{" "$JEN"; then
    echo "  OK   Jenkinsfile uses container('name') { ... }"
  else
    echo "  FAIL Jenkinsfile does not use container('name') { ... }"
    fail=$((fail+1))
  fi

  if grep -qE "\bsh\b" "$JEN"; then
    echo "  OK   Jenkinsfile uses at least one 'sh' step"
  else
    echo "  FAIL Jenkinsfile has no 'sh' step"
    fail=$((fail+1))
  fi
fi

# ---- OPTIONAL: kind live lab -------------------------------------------
echo
if command -v kind >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  echo "  OK   kind + kubectl available (live lab possible — not run by validator)"
else
  echo "  SKIP kind/kubectl not installed; live lab skipped (not a failure)"
  skipped=$((skipped+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. ${skipped} optional check(s) skipped."
echo "    Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
