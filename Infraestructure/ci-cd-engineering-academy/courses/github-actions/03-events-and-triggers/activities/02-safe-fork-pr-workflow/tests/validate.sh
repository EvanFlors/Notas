#!/usr/bin/env bash
# Validate gha-03-02-safe-fork-pr-workflow.
#
# Note: no `set -o pipefail` — grep over multiline producers can SIGPIPE (141).

BASE="${1:-${BASE_DIR:-/tmp/safe-fork-pr}}"
WF="$BASE/workflows"

ok=0; fail=0; report=""
note_ok()   { report+="  OK   — $1\n"; ok=$((ok+1)); }
note_fail() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating safe-fork-pr under $BASE =="

if [ ! -d "$WF" ]; then
  echo "FAIL: $WF does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

shopt -s nullglob
ymls=( "$WF"/*.yml )
if [ "${#ymls[@]}" -lt 2 ]; then
  note_fail "need at least 2 .yml files, found ${#ymls[@]}"
else
  note_ok "found ${#ymls[@]} .yml files"
fi

# All .yml parse
for f in "${ymls[@]}"; do
  if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    note_ok "$(basename "$f") parses"
  else
    note_fail "$(basename "$f") invalid YAML"
  fi
done

# Find at least one workflow A (pull_request + upload-artifact)
found_a=0
for f in "${ymls[@]}"; do
  if grep -Eq '^[[:space:]]*pull_request:' "$f" \
     && ! grep -q 'pull_request_target' "$f" \
     && grep -q 'actions/upload-artifact' "$f"; then
    found_a=1
    note_ok "$(basename "$f") is Workflow A (pull_request + upload-artifact)"
    break
  fi
done
if [ "$found_a" -eq 0 ]; then
  note_fail "no workflow with on: pull_request + actions/upload-artifact found"
fi

# Find at least one workflow B (workflow_run + pull-requests: write)
found_b=0
for f in "${ymls[@]}"; do
  if grep -Eq '^[[:space:]]*workflow_run:' "$f" \
     && grep -Eq 'pull-requests:[[:space:]]*write' "$f"; then
    found_b=1
    note_ok "$(basename "$f") is Workflow B (workflow_run + pull-requests: write)"
    break
  fi
done
if [ "$found_b" -eq 0 ]; then
  note_fail "no workflow with on: workflow_run + pull-requests: write found"
fi

# ANTI-PATTERN 1: pull_request_target + checkout of PR head
for f in "${ymls[@]}"; do
  if grep -q 'pull_request_target' "$f"; then
    if grep -A3 'actions/checkout' "$f" | grep -q 'pull_request\.head'; then
      note_fail "$(basename "$f") combines pull_request_target with checkout of PR head (ANTI-PATTERN)"
    else
      note_ok "$(basename "$f") uses pull_request_target without PR-head checkout"
    fi
  fi
done

# ANTI-PATTERN 2: pull_request_target + code-execution commands
dangerous='(npm install|npm ci|pip install|make[[:space:]]|bundle install|cargo build|go build|mvn|gradle)'
for f in "${ymls[@]}"; do
  if grep -q 'pull_request_target' "$f"; then
    if grep -Eq "$dangerous" "$f"; then
      note_fail "$(basename "$f") uses pull_request_target with code-execution commands (ANTI-PATTERN)"
    else
      note_ok "$(basename "$f") pull_request_target has no package-manager/build invocations"
    fi
  fi
done

# README exists and justifies
if [ -f "$WF/README.md" ]; then
  note_ok "workflows/README.md exists"
  if grep -Eiq 'secret|pattern|checkout|pull_request_target' "$WF/README.md"; then
    note_ok "workflows/README.md contains a justification"
  else
    note_fail "workflows/README.md does not justify the pattern"
  fi
else
  note_fail "workflows/README.md missing"
fi

# Optional actionlint
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF"/*.yml >/dev/null 2>&1; then
    note_ok "actionlint clean"
  else
    note_fail "actionlint reported issues"
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
