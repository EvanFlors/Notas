#!/usr/bin/env bash
# Validate argo-07-01-env-per-folder-appset.
# Modes:
#   - OFFLINE (default): checks local repo layout and appset.yaml structure.
#   - ONLINE: if kubectl can reach a cluster with the ApplicationSet CRD and
#     a running applicationset-controller, also verifies the 3 Applications
#     were generated.
#
# SKIP semantics: if a cluster is not available, the online checks are skipped
# gracefully (not failed).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `cmd | grep -q ...` which produces SIGPIPE (exit 141) on the upstream
# process when grep exits early. pipefail would turn those SIGPIPE exits into
# spurious failures.

BASE="${1:-${BASE_DIR:-/tmp/argo-07-01}}"
REPO="$BASE/infra-repo"
APPSET="$BASE/appset.yaml"
pass=0
fail=0
skip=0

say_ok()   { echo "  OK   $*"; pass=$((pass+1)); }
say_fail() { echo "  FAIL $*"; fail=$((fail+1)); }
say_skip() { echo "  SKIP $*"; skip=$((skip+1)); }

echo "== Validating argo-07-01 under $BASE =="

# ---------- Offline checks ----------

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: no git repo at $REPO. Run starter/build-base-repo.sh first."
  exit 1
fi

for env in dev stg prod; do
  if [ -f "$REPO/envs/$env/deployment.yaml" ]; then
    say_ok "envs/$env/deployment.yaml exists"
  else
    say_fail "envs/$env/deployment.yaml missing"
  fi
done

if [ -d "$REPO/envs/_shared" ]; then
  say_ok "envs/_shared exists (will be excluded)"
else
  say_fail "envs/_shared missing"
fi

if [ ! -f "$APPSET" ]; then
  say_fail "appset.yaml not found at $APPSET (write it per the README)"
else
  # Parse YAML
  if python3 -c "import yaml,sys; list(yaml.safe_load_all(open('$APPSET')))" >/dev/null 2>&1; then
    say_ok "appset.yaml is valid YAML"
  else
    say_fail "appset.yaml is not valid YAML"
  fi

  # kind: ApplicationSet
  if grep -E '^kind:[[:space:]]+ApplicationSet' "$APPSET" >/dev/null; then
    say_ok "kind: ApplicationSet"
  else
    say_fail "kind is not ApplicationSet"
  fi

  # goTemplate: true
  if grep -E '^[[:space:]]*goTemplate:[[:space:]]+true' "$APPSET" >/dev/null; then
    say_ok "goTemplate: true"
  else
    say_fail "goTemplate: true is missing (recommended for new ApplicationSets)"
  fi

  # missingkey=error
  if grep -F 'missingkey=error' "$APPSET" >/dev/null; then
    say_ok "goTemplateOptions includes missingkey=error"
  else
    say_fail "missingkey=error is missing (prevents typo-induced empty values)"
  fi

  # git.directories generator
  if grep -E '^[[:space:]]*directories:' "$APPSET" >/dev/null; then
    say_ok "git.directories generator present"
  else
    say_fail "generator must use git.directories"
  fi

  # path: envs/*
  if grep -E 'path:[[:space:]]*envs/\*' "$APPSET" >/dev/null; then
    say_ok "path: envs/* configured"
  else
    say_fail "path: envs/* missing"
  fi

  # exclude _shared
  if grep -E 'envs/_shared' "$APPSET" >/dev/null && grep -E 'exclude:[[:space:]]+true' "$APPSET" >/dev/null; then
    say_ok "envs/_shared excluded"
  else
    say_fail "envs/_shared should be excluded explicitly"
  fi

  # template uses .path.basename
  if grep -F '.path.basename' "$APPSET" >/dev/null; then
    say_ok "template references {{.path.basename}}"
  else
    say_fail "template should reference {{.path.basename}}"
  fi
fi

# ---------- Online checks (optional) ----------

if ! command -v kubectl >/dev/null 2>&1; then
  say_skip "kubectl not installed; online checks skipped"
elif ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  say_skip "no reachable cluster; online checks skipped"
elif ! kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1; then
  say_skip "ApplicationSet CRD not present; online checks skipped"
else
  if kubectl -n argocd get applicationset myapp-envs >/dev/null 2>&1; then
    say_ok "ApplicationSet myapp-envs exists in cluster"
    count="$(kubectl -n argocd get applications -l generated-by=git-envs --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${count:-0}" -ge 3 ]; then
      say_ok "generated $count Application(s) (>=3 expected)"
    else
      say_fail "only $count Application(s) generated (expected >=3). Give the controller a moment."
    fi
  else
    say_skip "ApplicationSet not applied yet (kubectl apply -f $APPSET)"
  fi
fi

echo
echo "RESULT: $pass OK, $fail FAIL, $skip SKIP"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
