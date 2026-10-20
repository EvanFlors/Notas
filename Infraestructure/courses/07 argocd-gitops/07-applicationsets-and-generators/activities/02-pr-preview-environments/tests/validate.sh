#!/usr/bin/env bash
# Validate argo-07-02-pr-preview-environments.
# OFFLINE: checks mock-repo layout + both appset manifests.
# ONLINE: if cluster + ApplicationSet CRD present, verifies mock Applications.
#
# Note: no `set -o pipefail` on purpose. Pipelines like `cmd | grep -q ...`
# emit SIGPIPE on the upstream when grep exits early; pipefail would turn
# those into spurious failures.

BASE="${1:-${BASE_DIR:-/tmp/argo-07-02}}"
REPO="$BASE/mock-repo"
APPSET_MOCK="$BASE/appset-mock.yaml"
APPSET_GH="$BASE/appset-github.yaml"
pass=0
fail=0
skip=0

say_ok()   { echo "  OK   $*"; pass=$((pass+1)); }
say_fail() { echo "  FAIL $*"; fail=$((fail+1)); }
say_skip() { echo "  SKIP $*"; skip=$((skip+1)); }

echo "== Validating argo-07-02 under $BASE =="

# ---------- Mock repo ----------

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: no git repo at $REPO. Run starter/build-mock-infra.sh first."
  exit 1
fi

for n in 101 102 103; do
  f="$REPO/pulls/$n.yaml"
  if [ -f "$f" ]; then
    # Validate shape
    if python3 -c "import yaml,sys; d=yaml.safe_load(open('$f')); assert isinstance(d,dict) and 'number' in d and 'branch' in d and 'head_sha' in d" >/dev/null 2>&1; then
      say_ok "pulls/$n.yaml has required keys (number, branch, head_sha)"
    else
      say_fail "pulls/$n.yaml missing required keys"
    fi
  else
    say_fail "pulls/$n.yaml missing"
  fi
done

# ---------- Appset mock ----------

validate_appset() {
  local f="$1"
  local label="$2"
  local need_pr="$3"   # yes = must use pullRequest generator; no = must use git.files

  if [ ! -f "$f" ]; then
    say_fail "$label: $f not found"
    return
  fi

  if python3 -c "import yaml,sys; list(yaml.safe_load_all(open('$f')))" >/dev/null 2>&1; then
    say_ok "$label: valid YAML"
  else
    say_fail "$label: invalid YAML"
    return
  fi

  if grep -E '^kind:[[:space:]]+ApplicationSet' "$f" >/dev/null; then
    say_ok "$label: kind ApplicationSet"
  else
    say_fail "$label: kind must be ApplicationSet"
  fi

  if grep -E '^[[:space:]]*goTemplate:[[:space:]]+true' "$f" >/dev/null; then
    say_ok "$label: goTemplate true"
  else
    say_fail "$label: goTemplate must be true"
  fi

  if grep -F 'missingkey=error' "$f" >/dev/null; then
    say_ok "$label: missingkey=error"
  else
    say_fail "$label: missingkey=error missing"
  fi

  if grep -F '{{.number}}' "$f" >/dev/null; then
    say_ok "$label: uses {{.number}} in template"
  else
    say_fail "$label: template must parametrize by {{.number}}"
  fi

  if grep -F 'myapp-pr-' "$f" >/dev/null; then
    say_ok "$label: namespace/name pattern myapp-pr-* present"
  else
    say_fail "$label: must use myapp-pr-{{.number}} naming"
  fi

  # preserveResourcesOnDeletion must NOT be true
  if grep -E 'preserveResourcesOnDeletion:[[:space:]]+true' "$f" >/dev/null; then
    say_fail "$label: preserveResourcesOnDeletion must NOT be true for previews"
  else
    say_ok "$label: preserveResourcesOnDeletion correct (not true)"
  fi

  if [ "$need_pr" = "yes" ]; then
    if grep -E '^[[:space:]]*-?[[:space:]]*pullRequest:' "$f" >/dev/null; then
      say_ok "$label: uses pullRequest generator"
    else
      say_fail "$label: must use pullRequest generator"
    fi
    if grep -F 'tokenRef' "$f" >/dev/null; then
      say_ok "$label: tokenRef present"
    else
      say_fail "$label: tokenRef missing for GitHub access"
    fi
    if grep -E "labels:[[:space:]]*\[[\"']?preview[\"']?\]" "$f" >/dev/null; then
      say_ok "$label: filters by labels [preview]"
    else
      say_fail "$label: should filter PRs by labels [preview]"
    fi
  else
    if grep -E '^[[:space:]]*files:' "$f" >/dev/null; then
      say_ok "$label: uses git.files generator"
    else
      say_fail "$label: must use git.files generator (mock)"
    fi
    if grep -F 'pulls/*.yaml' "$f" >/dev/null; then
      say_ok "$label: files path matches pulls/*.yaml"
    else
      say_fail "$label: should reference pulls/*.yaml"
    fi
  fi
}

validate_appset "$APPSET_MOCK" "appset-mock.yaml" "no"
validate_appset "$APPSET_GH"   "appset-github.yaml" "yes"

# ---------- Online (optional) ----------

if ! command -v kubectl >/dev/null 2>&1; then
  say_skip "kubectl not installed; online checks skipped"
elif ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  say_skip "no reachable cluster; online checks skipped"
elif ! kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1; then
  say_skip "ApplicationSet CRD not present; online checks skipped"
else
  if kubectl -n argocd get applicationset myapp-pr-previews-mock >/dev/null 2>&1; then
    say_ok "mock ApplicationSet exists in cluster"
    count="$(kubectl -n argocd get applications -l generated-by=pr-preview --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${count:-0}" -ge 3 ]; then
      say_ok "generated $count preview Application(s)"
    else
      say_fail "only $count preview Application(s); expected >=3"
    fi
  else
    say_skip "mock ApplicationSet not applied yet (kubectl apply -f $APPSET_MOCK)"
  fi
fi

echo
echo "RESULT: $pass OK, $fail FAIL, $skip SKIP"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
