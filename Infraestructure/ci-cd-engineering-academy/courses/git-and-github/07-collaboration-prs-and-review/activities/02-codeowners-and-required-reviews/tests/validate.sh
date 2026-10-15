#!/usr/bin/env bash
# Validate gh-07-02-codeowners-and-required-reviews.
#
# Modes:
#   MODE=local (default): validate against local files in $BASE.
#   MODE=live           : additionally query gh api repos/$GH_REPO/codeowners/errors.
#
# Note: we deliberately do NOT set `set -o pipefail` — some pipelines use
# `grep -q` after a long producer, which can SIGPIPE and spuriously fail.

BASE="${1:-${BASE_DIR:-/tmp/codeowners-lab}}"
MODE="${MODE:-local}"
fail=0

ok()   { echo "  OK   $*"; }
nok()  { echo "  FAIL $*"; fail=$((fail+1)); }

echo "== Validating gh-07-02 in MODE=$MODE at $BASE =="

if [ ! -d "$BASE/.git" ]; then
  echo "FAIL: $BASE is not a Git repo. Run: bash starter/build-repo.sh $BASE"
  exit 1
fi
cd "$BASE"

CODEOWNERS=".github/CODEOWNERS"
PR_TPL=".github/PULL_REQUEST_TEMPLATE.md"
POLICY=".github/review-policy.yaml"

# ───────────────────────── CODEOWNERS existence ───────────────────────────
if [ -f "$CODEOWNERS" ]; then
  ok "$CODEOWNERS exists"
else
  nok "$CODEOWNERS missing"
  # Can't continue meaningfully.
  echo
  echo "RESULT: $fail check(s) failed."
  exit 1
fi

# ───────────────────────── CODEOWNERS syntax ──────────────────────────────
# Each non-comment, non-empty line must be: <pattern> <@owner...>
bad_lines=0
default_rules=0
glob_rules=0
path_rules=0
while IFS= read -r line; do
  stripped=$(echo "$line" | sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$stripped" ] && continue

  pattern=$(echo "$stripped" | awk '{print $1}')
  owners=$(echo "$stripped" | cut -d' ' -f2- | sed 's/^ *//')

  if [ -z "$pattern" ] || [ -z "$owners" ]; then
    nok "line without owner: '$line'"
    bad_lines=$((bad_lines+1))
    continue
  fi

  # owners must all start with @
  bad_owner=0
  for o in $owners; do
    case "$o" in
      @*) : ;;
      *) bad_owner=1 ;;
    esac
  done
  if [ "$bad_owner" -eq 1 ]; then
    nok "line has owner without '@': '$line'"
    bad_lines=$((bad_lines+1))
    continue
  fi

  # Classify
  if [ "$pattern" = "*" ]; then
    default_rules=$((default_rules+1))
  elif [ "${pattern%\/}" != "$pattern" ]; then
    path_rules=$((path_rules+1))
  elif case "$pattern" in \**) true ;; *) false ;; esac; then
    glob_rules=$((glob_rules+1))
  else
    # Specific file — count as path for the purpose of granularity
    path_rules=$((path_rules+1))
  fi
done < "$CODEOWNERS"

if [ "$bad_lines" -eq 0 ]; then
  ok "all CODEOWNERS rules have valid shape"
fi

if [ "$default_rules" -ge 1 ]; then
  ok "default rule (*) present: $default_rules"
else
  nok "no default rule '*' found"
fi

if [ "$glob_rules" -ge 2 ]; then
  ok "glob rules present: $glob_rules (>=2)"
else
  nok "fewer than 2 glob rules (e.g., *.py, *.md); found $glob_rules"
fi

if [ "$path_rules" -ge 3 ]; then
  ok "path-specific rules present: $path_rules (>=3)"
else
  nok "fewer than 3 path/specific rules (ending with /); found $path_rules"
fi

# ──────── Double owner on sensitive paths ─────────────────────────────────
check_double_owner() {
  local re="$1"
  local label="$2"
  local line owners_count
  line=$(grep -E "^${re}" "$CODEOWNERS" | tail -1)
  if [ -z "$line" ]; then
    nok "no rule for $label"
    return
  fi
  owners_count=$(echo "$line" | awk '{for(i=2;i<=NF;i++) if($i ~ /^@/) c++} END{print c+0}')
  if [ "$owners_count" -ge 2 ]; then
    ok "$label has $owners_count owners"
  else
    nok "$label has only $owners_count owner(s); need >=2"
  fi
}
check_double_owner '/\.github/workflows/' '/.github/workflows/'
check_double_owner '/\.github/CODEOWNERS' '/.github/CODEOWNERS'

# ──────── Ownership simulation for 6 file paths ───────────────────────────
# Produce (path, must-contain-owner) pairs and resolve via last-match rule.
python3 - "$CODEOWNERS" <<'PY'
import sys, fnmatch, re
owners_file = sys.argv[1]
rules = []
with open(owners_file) as f:
    for raw in f:
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        pattern = parts[0]
        owners  = [p for p in parts[1:] if p.startswith('@')]
        if not owners:
            continue
        rules.append((pattern, owners))

def match(pattern: str, path: str) -> bool:
    # path is absolute from repo root, without leading slash
    if pattern == '*':
        return True
    # Directory pattern: starts with / and ends with /
    if pattern.startswith('/') and pattern.endswith('/'):
        prefix = pattern.strip('/')
        return path == prefix or path.startswith(prefix + '/')
    # Absolute file pattern
    if pattern.startswith('/'):
        return fnmatch.fnmatchcase(path, pattern.lstrip('/'))
    # Glob — match basename (git CODEOWNERS semantics: anywhere)
    if '*' in pattern or '?' in pattern or '[' in pattern:
        return (fnmatch.fnmatchcase(path, pattern)
                or fnmatch.fnmatchcase(path.split('/')[-1], pattern)
                or fnmatch.fnmatchcase('/' + path, '*/' + pattern))
    # Plain name — match anywhere
    return path.endswith('/' + pattern) or path == pattern

def owners_for(path: str):
    hit = None
    for pat, own in rules:
        if match(pat, path):
            hit = own
    return hit or []

cases = [
    ('src/api/handlers.py',     '@acme/api-team'),
    ('src/web/app.ts',          '@acme/frontend-team'),
    ('docs/runbook.md',         '@acme/docs-team'),
    ('infra/main.tf',           '@acme/platform-team'),
    ('tests/test_handlers.py',  '@acme/python-maintainers'),
    ('.github/workflows/ci.yml','@acme/devops'),
]
failures = 0
for path, need in cases:
    got = owners_for(path)
    if need in got:
        print(f"  OK   simulated owner for {path} contains {need} (owners={got})")
    else:
        print(f"  FAIL simulated owner for {path} missing {need} (owners={got})")
        failures += 1

sys.exit(1 if failures else 0)
PY
sim_rc=$?
if [ "$sim_rc" -ne 0 ]; then
  fail=$((fail+1))
fi

# ──────── PR template ──────────────────────────────────────────────────────
if [ -f "$PR_TPL" ]; then
  ok "$PR_TPL exists"
  for sec in "Summary" "Changes" "Linked issues" "Test plan" "Risk / rollback"; do
    if grep -q "^##[[:space:]]\+${sec}" "$PR_TPL"; then
      ok "PR template has '## $sec'"
    else
      nok "PR template missing '## $sec'"
    fi
  done
  if grep -Eq '(Fixes|Closes|Resolves)[[:space:]]+#' "$PR_TPL"; then
    ok "PR template includes a closing keyword placeholder (Fixes/Closes/Resolves #)"
  else
    nok "PR template missing a closing keyword placeholder"
  fi
else
  nok "$PR_TPL missing"
fi

# ──────── review-policy.yaml ───────────────────────────────────────────────
if [ -f "$POLICY" ]; then
  ok "$POLICY exists"
  python3 - "$POLICY" <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("  WARN pyyaml not installed; falling back to plain-text key check")
    data = open(sys.argv[1]).read()
    required = ['required_approvals',
                'require_codeowner_review',
                'dismiss_stale_reviews_on_push',
                'require_up_to_date_before_merge',
                'restrict_who_can_push_to_main']
    missing = [k for k in required if k not in data]
    if missing:
        print(f"  FAIL policy missing keys: {missing}")
        sys.exit(1)
    print("  OK   policy contains required keys (text match)")
    sys.exit(0)

try:
    d = yaml.safe_load(open(sys.argv[1]))
except yaml.YAMLError as e:
    print(f"  FAIL policy is invalid YAML: {e}")
    sys.exit(1)

if not isinstance(d, dict):
    print("  FAIL policy is not a YAML mapping")
    sys.exit(1)

required = {
    'required_approvals':              lambda v: isinstance(v, int) and v >= 1,
    'require_codeowner_review':        lambda v: isinstance(v, bool),
    'dismiss_stale_reviews_on_push':   lambda v: isinstance(v, bool),
    'require_up_to_date_before_merge': lambda v: isinstance(v, bool),
    'restrict_who_can_push_to_main':   lambda v: isinstance(v, list) and len(v) >= 1,
}
failures = 0
for key, check in required.items():
    if key not in d:
        print(f"  FAIL policy missing key '{key}'")
        failures += 1
    elif not check(d[key]):
        print(f"  FAIL policy key '{key}' has invalid value: {d[key]!r}")
        failures += 1
    else:
        print(f"  OK   policy key '{key}' = {d[key]!r}")

sys.exit(1 if failures else 0)
PY
  policy_rc=$?
  if [ "$policy_rc" -ne 0 ]; then
    fail=$((fail+1))
  fi
else
  nok "$POLICY missing"
fi

# ──────── Live mode: query gh api ──────────────────────────────────────────
if [ "$MODE" = "live" ]; then
  if command -v gh >/dev/null 2>&1 && [ -n "${GH_REPO:-}" ]; then
    if gh auth status >/dev/null 2>&1; then
      errs=$(gh api "repos/${GH_REPO}/codeowners/errors" 2>/dev/null \
               | python3 -c 'import sys,json;print(len((json.load(sys.stdin) or {}).get("errors",[])))' 2>/dev/null || echo "?")
      if [ "$errs" = "0" ]; then
        ok "gh api codeowners/errors reports 0 errors"
      else
        nok "gh api codeowners/errors reports $errs errors"
      fi
    else
      nok "MODE=live but gh auth status failed"
    fi
  else
    nok "MODE=live requires gh CLI and GH_REPO=<owner/repo>"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
