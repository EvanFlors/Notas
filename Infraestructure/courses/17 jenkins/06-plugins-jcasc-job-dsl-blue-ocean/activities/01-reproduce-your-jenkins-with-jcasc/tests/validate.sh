#!/usr/bin/env bash
# Structural validation for jk-06-01-reproduce-your-jenkins-with-jcasc.
# Checks jenkins.yaml (YAML parse + required blocks), plugins.txt (strict
# pinning + required plugins), seed-jobs.groovy (minimum DSL calls) and
# README-INTENT.md (required sections + mentions).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run Jenkins; schema correctness against a real controller is NOT
# verified here — that is the optional Docker walkthrough (SKIP by default).

set -eu

BASE="${1:-/tmp/jk-06-01}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

JYAML="$BASE/jenkins.yaml"
PTXT="$BASE/plugins.txt"
GROOVY="$BASE/seed-jobs.groovy"
DOC="$BASE/README-INTENT.md"

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

# ---- jenkins.yaml ----------------------------------------------------------
if check_file_exists "$JYAML"; then
  if python3 -c "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" "$JYAML" 2>/dev/null; then
    echo "  OK   jenkins.yaml parses as YAML"
  else
    echo "  FAIL jenkins.yaml does not parse as YAML"
    fail=$((fail+1))
  fi

  for key in "jenkins" "credentials" "unclassified" "tool" "jobs"; do
    present=$(python3 - "$JYAML" "$key" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
print("1" if sys.argv[2] in data else "0")
PY
)
    if [ "$present" = "1" ]; then
      echo "  OK   jenkins.yaml has top-level key '$key'"
    else
      echo "  FAIL jenkins.yaml missing top-level key '$key'"
      fail=$((fail+1))
    fi
  done

  for sub in "securityRealm" "authorizationStrategy"; do
    present=$(python3 - "$JYAML" "$sub" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
j = data.get("jenkins") or {}
print("1" if sys.argv[2] in j else "0")
PY
)
    if [ "$present" = "1" ]; then
      echo "  OK   jenkins.jenkins.$sub present"
    else
      echo "  FAIL jenkins.jenkins.$sub missing"
      fail=$((fail+1))
    fi
  done

  # credentials.system.domainCredentials[*].credentials non-empty
  cred_count=$(python3 - "$JYAML" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
c = (((data.get("credentials") or {}).get("system") or {}).get("domainCredentials") or [])
total = 0
for d in c:
    total += len(d.get("credentials") or [])
print(total)
PY
)
  if [ "${cred_count:-0}" -ge 1 ]; then
    echo "  OK   jenkins.yaml declares at least 1 credential (${cred_count} total)"
  else
    echo "  FAIL jenkins.yaml declares no credentials under credentials.system.domainCredentials"
    fail=$((fail+1))
  fi

  # jobs[*].script present
  job_scripts=$(python3 - "$JYAML" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
jobs = data.get("jobs") or []
print(sum(1 for j in jobs if isinstance(j, dict) and "script" in j))
PY
)
  if [ "${job_scripts:-0}" -ge 1 ]; then
    echo "  OK   jenkins.yaml has at least 1 jobs[].script (seed)"
  else
    echo "  FAIL jenkins.yaml has no jobs[].script entry"
    fail=$((fail+1))
  fi

  # No obvious plaintext secret: forbid lines like `password: "something"` where
  # the value is NOT a ${VAR} placeholder.
  bad_secret=$(grep -nE '^[[:space:]]*(password|secret|token|apiKey)[[:space:]]*:' "$JYAML" \
               | grep -vE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' || true)
  if [ -z "$bad_secret" ]; then
    echo "  OK   jenkins.yaml: no obvious plaintext secrets"
  else
    echo "  FAIL jenkins.yaml appears to contain plaintext secrets:"
    printf '       %s\n' "$bad_secret"
    fail=$((fail+1))
  fi
fi

# ---- plugins.txt -----------------------------------------------------------
if check_file_exists "$PTXT"; then
  # Count non-comment, non-blank lines.
  total_lines=$(grep -cvE '^[[:space:]]*(#|$)' "$PTXT" || true)
  if [ "${total_lines:-0}" -ge 6 ]; then
    echo "  OK   plugins.txt has at least 6 plugins (${total_lines})"
  else
    echo "  FAIL plugins.txt has only ${total_lines} plugins (expected >=6)"
    fail=$((fail+1))
  fi

  # Every non-comment line must be of form name:version (version non-empty, not 'latest').
  bad_lines=$(grep -vE '^[[:space:]]*(#|$)' "$PTXT" \
              | grep -vE '^[A-Za-z0-9][A-Za-z0-9._-]*:[A-Za-z0-9][A-Za-z0-9._+-]*$' || true)
  latest_lines=$(grep -vE '^[[:space:]]*(#|$)' "$PTXT" | grep -E ':latest$' || true)
  if [ -z "$bad_lines" ] && [ -z "$latest_lines" ]; then
    echo "  OK   plugins.txt: every line pinned (name:version, no :latest)"
  else
    echo "  FAIL plugins.txt has unpinned or malformed lines:"
    [ -n "$bad_lines" ]    && printf '       bad: %s\n' $bad_lines
    [ -n "$latest_lines" ] && printf '       latest: %s\n' $latest_lines
    fail=$((fail+1))
  fi

  for req in "configuration-as-code" "job-dsl" "workflow-aggregator"; do
    if grep -qE "^${req}:" "$PTXT"; then
      echo "  OK   plugins.txt includes required plugin '$req'"
    else
      echo "  FAIL plugins.txt missing required plugin '$req'"
      fail=$((fail+1))
    fi
  done
fi

# ---- seed-jobs.groovy ------------------------------------------------------
if check_file_exists "$GROOVY"; then
  has_folder=$(grep -cE "^[[:space:]]*folder\\(" "$GROOVY" || true)
  has_pipeline=$(grep -cE "^[[:space:]]*(pipelineJob|multibranchPipelineJob)\\(" "$GROOVY" || true)
  total_dsl=$((has_folder + has_pipeline))

  if [ "$has_folder" -ge 1 ]; then
    echo "  OK   seed-jobs.groovy declares at least 1 folder()"
  else
    echo "  FAIL seed-jobs.groovy has no folder() call"
    fail=$((fail+1))
  fi
  if [ "$has_pipeline" -ge 1 ]; then
    echo "  OK   seed-jobs.groovy declares at least 1 pipelineJob/multibranchPipelineJob"
  else
    echo "  FAIL seed-jobs.groovy has no pipelineJob() or multibranchPipelineJob()"
    fail=$((fail+1))
  fi
  if [ "$total_dsl" -ge 2 ]; then
    echo "  OK   seed-jobs.groovy has ${total_dsl} DSL calls (>=2)"
  else
    echo "  FAIL seed-jobs.groovy has only ${total_dsl} DSL calls (expected >=2)"
    fail=$((fail+1))
  fi
fi

# ---- README-INTENT.md ------------------------------------------------------
if check_file_exists "$DOC"; then
  for section in "jenkins.yaml" "plugins.txt" "seed-jobs.groovy" "Blue Ocean"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section for '${section}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'JCasC|Configuration as Code' "$DOC"; then
    echo "  OK   README-INTENT.md mentions JCasC / Configuration as Code"
  else
    echo "  FAIL README-INTENT.md does not mention JCasC"
    fail=$((fail+1))
  fi
  if grep -qiE 'seed +job' "$DOC"; then
    echo "  OK   README-INTENT.md mentions seed job"
  else
    echo "  FAIL README-INTENT.md does not mention seed job"
    fail=$((fail+1))
  fi
  if grep -qiE 'pinning|version|pinned' "$DOC"; then
    echo "  OK   README-INTENT.md mentions pinning/version strategy"
  else
    echo "  FAIL README-INTENT.md does not mention pinning/version"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Runtime schema correctness in a real Jenkins is NOT verified here.)"
  exit 1
fi
echo "OK: jenkins.yaml, plugins.txt, seed-jobs.groovy y README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/ para autoevaluacion semantica."
exit 0
