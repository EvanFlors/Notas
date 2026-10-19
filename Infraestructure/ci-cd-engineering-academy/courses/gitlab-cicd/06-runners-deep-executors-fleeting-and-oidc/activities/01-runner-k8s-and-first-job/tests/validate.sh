#!/usr/bin/env bash
# Structural validation for gl-06-01-runner-k8s-and-first-job.
# Checks that values.yaml, config.toml and .gitlab-ci.yml parse as YAML/TOML
# and carry the minimum fields expected by the lesson (authentication token
# prefix, kubernetes executor, privileged=false, Kaniko in the pipeline, no
# DinD) plus the three required sections in NOTES.md.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real cluster.

set -eu

BASE="${1:-/tmp/gl-06-runner-k8s}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

# --- values.yaml ---------------------------------------------------------
VALUES="$BASE/values.yaml"
if check_file_exists "$VALUES"; then
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$VALUES" 2>/dev/null; then
    echo "  OK   $VALUES is valid YAML"
  else
    echo "  FAIL $VALUES is not valid YAML"
    fail=$((fail+1))
  fi

  if grep -qE '^gitlabUrl:' "$VALUES"; then
    echo "  OK   values.yaml declares gitlabUrl"
  else
    echo "  FAIL values.yaml missing gitlabUrl"
    fail=$((fail+1))
  fi

  if grep -qE '^runnerToken: *["'\'']?glrt-' "$VALUES"; then
    echo "  OK   values.yaml uses modern runnerToken (glrt- prefix)"
  else
    echo "  FAIL values.yaml missing runnerToken with 'glrt-' prefix"
    fail=$((fail+1))
  fi

  if python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
rbac=(d or {}).get('rbac') or {}
assert rbac.get('create') is True
" "$VALUES" 2>/dev/null; then
    echo "  OK   values.yaml has rbac.create: true"
  else
    echo "  FAIL values.yaml missing rbac.create: true"
    fail=$((fail+1))
  fi

  if python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
c=(d or {}).get('concurrent')
assert isinstance(c,int) and c>=1
" "$VALUES" 2>/dev/null; then
    echo "  OK   values.yaml has concurrent >= 1"
  else
    echo "  FAIL values.yaml missing or invalid 'concurrent'"
    fail=$((fail+1))
  fi

  if grep -qE 'executor *= *"kubernetes"' "$VALUES"; then
    echo "  OK   values.yaml embeds a [[runners]] with executor=kubernetes"
  else
    echo "  FAIL values.yaml does not configure executor=kubernetes"
    fail=$((fail+1))
  fi

  if grep -qE 'privileged *= *false' "$VALUES"; then
    echo "  OK   values.yaml sets privileged=false"
  else
    echo "  FAIL values.yaml does not set privileged=false"
    fail=$((fail+1))
  fi

  if grep -qE 'tags: *["'\''][^"'\'']*\bk8s\b' "$VALUES"; then
    echo "  OK   values.yaml declares tag 'k8s'"
  else
    echo "  FAIL values.yaml does not include tag 'k8s'"
    fail=$((fail+1))
  fi
fi

# --- config.toml ---------------------------------------------------------
# TOML is validated structurally with grep/awk because Python's `tomllib`
# only exists from Python 3.11. We check: top-level `concurrent`, a
# `[[runners]]` list-of-tables header, executor=kubernetes, mandatory
# name/url/token keys, a `[runners.kubernetes]` section with privileged=false
# and at least one resource request.
TOML="$BASE/config.toml"
if check_file_exists "$TOML"; then
  toml_ok=1

  # Try an optional deeper parse if the user has tomllib or tomli.
  if python3 -c "
import sys
try:
    import tomllib as T
except ImportError:
    try:
        import tomli as T
    except ImportError:
        sys.exit(0)
T.load(open(sys.argv[1],'rb'))
" "$TOML" 2>/dev/null; then
    echo "  OK   $TOML parses with tomllib/tomli (deep parse available)"
  else
    echo "  INFO tomllib/tomli not available; falling back to grep-based checks"
  fi

  if grep -qE '^\s*concurrent\s*=\s*[0-9]+' "$TOML"; then
    echo "  OK   config.toml has top-level 'concurrent' integer"
  else
    echo "  FAIL config.toml missing top-level 'concurrent = <int>'"
    fail=$((fail+1)); toml_ok=0
  fi

  if grep -qE '^\s*\[\[runners\]\]' "$TOML"; then
    echo "  OK   config.toml has a [[runners]] block"
  else
    echo "  FAIL config.toml missing [[runners]] block"
    fail=$((fail+1)); toml_ok=0
  fi

  for key in 'name' 'url' 'token'; do
    if grep -qE "^\s*${key}\s*=\s*\"" "$TOML"; then
      echo "  OK   config.toml declares runner '${key}'"
    else
      echo "  FAIL config.toml missing runner '${key} = \"...\"'"
      fail=$((fail+1)); toml_ok=0
    fi
  done

  if grep -qE '^\s*executor\s*=\s*"kubernetes"' "$TOML"; then
    echo "  OK   config.toml sets executor=\"kubernetes\""
  else
    echo "  FAIL config.toml does not set executor=\"kubernetes\""
    fail=$((fail+1)); toml_ok=0
  fi

  if grep -qE '^\s*\[runners\.kubernetes\]' "$TOML"; then
    echo "  OK   config.toml has [runners.kubernetes] section"
  else
    echo "  FAIL config.toml missing [runners.kubernetes] section"
    fail=$((fail+1)); toml_ok=0
  fi

  if grep -qE '^\s*privileged\s*=\s*false' "$TOML"; then
    echo "  OK   config.toml sets privileged=false"
  else
    echo "  FAIL config.toml does not set privileged=false"
    fail=$((fail+1)); toml_ok=0
  fi

  if grep -qE '^\s*(cpu_request|memory_request)\s*=' "$TOML"; then
    echo "  OK   config.toml declares at least one resource request"
  else
    echo "  FAIL config.toml missing cpu_request/memory_request"
    fail=$((fail+1)); toml_ok=0
  fi

  if [ "$toml_ok" -eq 1 ]; then
    echo "  OK   config.toml passes structural checks"
  fi
fi

# --- .gitlab-ci.yml ------------------------------------------------------
CI="$BASE/.gitlab-ci.yml"
if check_file_exists "$CI"; then
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$CI" 2>/dev/null; then
    echo "  OK   $CI is valid YAML"
  else
    echo "  FAIL $CI is not valid YAML"
    fail=$((fail+1))
  fi

  if python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1])) or {}
jobs=[v for k,v in d.items() if isinstance(v,dict) and 'script' in v]
assert jobs, 'no jobs with script'
tagged=[j for j in jobs if 'k8s' in (j.get('tags') or [])]
assert tagged, 'no job tagged k8s'
" "$CI" 2>/dev/null; then
    echo "  OK   .gitlab-ci.yml has at least one job tagged 'k8s'"
  else
    echo "  FAIL .gitlab-ci.yml must contain at least one job with tags including 'k8s'"
    fail=$((fail+1))
  fi

  if grep -qiE 'kaniko|buildkit' "$CI"; then
    echo "  OK   .gitlab-ci.yml uses Kaniko or BuildKit"
  else
    echo "  FAIL .gitlab-ci.yml does not reference Kaniko/BuildKit image"
    fail=$((fail+1))
  fi

  if grep -qE 'docker:[0-9]+-dind|docker:dind' "$CI"; then
    echo "  FAIL .gitlab-ci.yml uses docker:dind (prohibited for this lab)"
    fail=$((fail+1))
  else
    echo "  OK   .gitlab-ci.yml does not use docker:dind"
  fi
fi

# --- NOTES.md ------------------------------------------------------------
NOTES="$BASE/NOTES.md"
if check_file_exists "$NOTES"; then
  for section in "Decisi[oó]n" "Por +qu[eé] +no +DinD" "Cache +S3"; do
    if grep -qE "^#+ +(${section})" "$NOTES"; then
      echo "  OK   NOTES.md has section matching '${section}'"
    else
      echo "  FAIL NOTES.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE '\bIRSA\b|IAM +role' "$NOTES"; then
    echo "  OK   NOTES.md mentions IRSA or IAM role"
  else
    echo "  FAIL NOTES.md does not mention IRSA or IAM role"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness in a real cluster is NOT verified here.)"
  exit 1
fi
echo "OK: runner K8s files pass structural validation."
echo "    Compara con solution/ para autoevaluarte."
exit 0
