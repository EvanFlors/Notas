#!/usr/bin/env bash
# Validate gha-03-01-trigger-matrix.
#
# Note: deliberately no `set -o pipefail` — some checks pipe long producers
# (yaml dumps, grep over multiline) and SIGPIPE (141) would mis-report.

BASE="${1:-${BASE_DIR:-/tmp/trigger-matrix}}"
WF="$BASE/workflows"

ok=0; fail=0; report=""
note_ok()   { report+="  OK   — $1\n"; ok=$((ok+1)); }
note_fail() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating trigger-matrix under $BASE =="

if [ ! -d "$WF" ]; then
  echo "FAIL: $WF does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

required=(01-ci.yml 02-release.yml 03-nightly-cleanup.yml 04-manual-deploy.yml 05-pr-labeler.yml)
for f in "${required[@]}"; do
  if [ -f "$WF/$f" ]; then
    note_ok "$f exists"
    if python3 -c "import yaml; yaml.safe_load(open('$WF/$f'))" 2>/dev/null; then
      note_ok "$f parses as YAML"
    else
      note_fail "$f is not valid YAML"
    fi
  else
    note_fail "$f missing"
  fi
done

# Scenario checks ----------------------------------------------------------
check_file_contains() {
  local f="$1" pat="$2" msg="$3"
  if [ -f "$WF/$f" ] && grep -Eq "$pat" "$WF/$f"; then
    note_ok "$f: $msg"
  else
    note_fail "$f: expected $msg (pattern: $pat)"
  fi
}

check_file_not_contains() {
  local f="$1" pat="$2" msg="$3"
  if [ -f "$WF/$f" ] && grep -Eq "$pat" "$WF/$f"; then
    note_fail "$f: $msg"
  else
    note_ok "$f: $msg"
  fi
}

# 01: push + pull_request + paths filter + branches
check_file_contains 01-ci.yml '^[[:space:]]*push:'         "declares push"
check_file_contains 01-ci.yml '^[[:space:]]*pull_request:' "declares pull_request"
check_file_contains 01-ci.yml 'paths(-ignore)?:'           "uses paths or paths-ignore"
check_file_contains 01-ci.yml 'branches:'                  "declares branches filter"

# 02: release with types published
check_file_contains 02-release.yml '^[[:space:]]*release:' "declares release"
check_file_contains 02-release.yml 'types:[[:space:]]*\[?[^]]*published' "release types includes published"

# 03: schedule + workflow_dispatch
check_file_contains 03-nightly-cleanup.yml '^[[:space:]]*schedule:'          "declares schedule"
check_file_contains 03-nightly-cleanup.yml '^[[:space:]]*workflow_dispatch:' "declares workflow_dispatch"
check_file_contains 03-nightly-cleanup.yml "cron:[[:space:]]*['\"]"          "has cron expression"

# 04: workflow_dispatch with typed inputs choice + string
check_file_contains 04-manual-deploy.yml '^[[:space:]]*workflow_dispatch:' "declares workflow_dispatch"
check_file_contains 04-manual-deploy.yml 'type:[[:space:]]*choice' "has choice input"
check_file_contains 04-manual-deploy.yml 'type:[[:space:]]*string' "has string input"

# 05: pull_request_target + pull-requests: write + NO actions/checkout
check_file_contains 05-pr-labeler.yml 'pull_request_target:' "declares pull_request_target"
check_file_contains 05-pr-labeler.yml 'pull-requests:[[:space:]]*write' "declares pull-requests: write"
check_file_not_contains 05-pr-labeler.yml 'actions/checkout' "does NOT checkout code (safe pattern)"

# README
if [ -f "$WF/README.md" ]; then
  note_ok "workflows/README.md exists"
  missing=""
  for f in "${required[@]}"; do
    if ! grep -q "$f" "$WF/README.md"; then missing+=" $f"; fi
  done
  if [ -z "$missing" ]; then
    note_ok "workflows/README.md mentions all 5 files"
  else
    note_fail "workflows/README.md does not mention:$missing"
  fi
else
  note_fail "workflows/README.md missing"
fi

# Optional actionlint
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF"/*.yml >/dev/null 2>&1; then
    note_ok "actionlint clean on all workflows"
  else
    note_fail "actionlint reported issues (run actionlint for detail)"
  fi
else
  report+="  SKIP — actionlint not installed (optional)\n"
fi

echo
printf "%b" "$report"
echo
total=$((ok + fail))
echo "RESULT: $ok/$total checks OK."
[ "$fail" -eq 0 ]
