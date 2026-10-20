#!/usr/bin/env bash
# Structural validation for plat-04-01-local-backstage-with-github-auth.
# Checks BACKSTAGE-SETUP.md structure, absence of real-looking secrets,
# and (optionally) the create-app repo if node >= 20 is available.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Semantic correctness is NOT graded — compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-04-backstage}"
DOC="$BASE/BACKSTAGE-SETUP.md"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# -------- Section headings (A..E) --------
for sec in A B C D E; do
  if grep -qiE "^#+ *Secci[óo]n +${sec}\b" "$DOC"; then
    echo "  OK   BACKSTAGE-SETUP.md has 'Seccion ${sec}'"
  else
    echo "  FAIL BACKSTAGE-SETUP.md missing 'Seccion ${sec}'"
    fail=$((fail+1))
  fi
done

# -------- Required keywords --------
require_kw() {
  local pattern="$1"
  local label="$2"
  if grep -qiE "$pattern" "$DOC"; then
    echo "  OK   mentions ${label}"
  else
    echo "  FAIL does not mention ${label}"
    fail=$((fail+1))
  fi
}

require_kw 'create-app|@backstage/create-app' 'create-app'
require_kw 'packages/app'                     'packages/app'
require_kw 'packages/backend'                 'packages/backend'
require_kw 'app-config'                       'app-config'
require_kw 'postgres|pg\b'                    'Postgres'
require_kw 'sqlite'                           'SQLite'
require_kw 'github'                           'GitHub'
require_kw 'oauth|clientId|clientSecret'      'OAuth terminology'
require_kw 'callback'                         'OAuth callback'
require_kw '7007'                             'backend port 7007'
require_kw '3000'                             'frontend port 3000'
require_kw 'node[[:space:]]*>?=?[[:space:]]*20|node 20' 'Node 20+ requirement'

# -------- Diagram cue (ASCII) --------
# Count lines starting with a vertical-pipe-box character or plain pipe/dash
diagram_lines=$(grep -cE '^[[:space:]]*(│|\||\+|┌|└|├|─|▼|►)' "$DOC" || true)
if [ "$diagram_lines" -ge 4 ]; then
  echo "  OK   BACKSTAGE-SETUP.md has an ASCII diagram ($diagram_lines diagram lines)"
else
  echo "  FAIL BACKSTAGE-SETUP.md has only $diagram_lines diagram lines (expected >=4)"
  fail=$((fail+1))
fi

# -------- Secrets safety --------
# All token/clientSecret-looking strings MUST contain the word 'placeholder'
# or be ${VAR_NAME}-style references.
# Heuristic: find ghp_ or Iv1. literals that do NOT contain 'placeholder'.
bad_secrets=0

while IFS= read -r line; do
  # ghp_ real token pattern: ghp_<alnum>{36,} without 'placeholder'
  if printf '%s' "$line" | grep -qE 'ghp_[A-Za-z0-9]{30,}' \
     && ! printf '%s' "$line" | grep -qi 'placeholder\|xxxx\|example\|do_not_use'; then
    echo "  FAIL possible real GitHub token on line: $line"
    bad_secrets=$((bad_secrets+1))
  fi
  # Iv1. OAuth client id: must be placeholder-marked
  if printf '%s' "$line" | grep -qE 'Iv1\.[A-Za-z0-9]{10,}' \
     && ! printf '%s' "$line" | grep -qi 'placeholder\|xxxx\|example'; then
    echo "  FAIL possible real OAuth clientId on line: $line"
    bad_secrets=$((bad_secrets+1))
  fi
done < "$DOC"

if [ "$bad_secrets" -eq 0 ]; then
  echo "  OK   no real-looking secrets detected"
else
  fail=$((fail+bad_secrets))
fi

# -------- Optional: create-app repo checks --------
APP_DIR="$BASE/my-backstage"
node_ok=0
if command -v node >/dev/null 2>&1; then
  nv="$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
  if [ -n "${nv:-}" ] && [ "$nv" -ge 20 ] 2>/dev/null; then
    node_ok=1
  fi
fi

if [ "$node_ok" -eq 1 ] && [ -d "$APP_DIR" ]; then
  echo "== Optional create-app checks (node >=20 detected, repo present) =="
  for p in "package.json" "app-config.yaml" "packages/app" "packages/backend"; do
    if [ -e "$APP_DIR/$p" ]; then
      echo "  OK   $APP_DIR/$p exists"
    else
      echo "  FAIL $APP_DIR/$p missing"
      fail=$((fail+1))
    fi
  done
else
  reason=""
  if [ "$node_ok" -ne 1 ]; then
    reason="node >=20 not available"
  else
    reason="my-backstage/ not scaffolded (optional step)"
  fi
  echo "  SKIP create-app checks ($reason)"
  skipped=$((skipped+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed; $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida ($skipped SKIP). Compara BACKSTAGE-SETUP.md con solution/REFERENCE.md."
exit 0
