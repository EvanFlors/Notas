#!/usr/bin/env bash
# Validate gha-05-02-restrict-github-token in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail`. Several checks pipe into `grep -q`
# which closes stdin early and can produce SIGPIPE (exit 141) on long producers,
# which would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-05-restrict-github-token}}"
MODE="${MODE:-local}"

LOCAL="$BASE/local"
WF="$LOCAL/.github/workflows"
# The student may keep the original name or rename to hardened.yml.
TARGET=""
for candidate in vulnerable.yml hardened.yml ci.yml; do
  if [ -f "$WF/$candidate" ]; then
    TARGET="$WF/$candidate"
    break
  fi
done

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE =="

if [ -z "$TARGET" ]; then
  echo "FAIL: no workflow found at $WF/{vulnerable.yml,hardened.yml,ci.yml}. Run bootstrap first." >&2
  exit 1
fi

note_ok "workflow found: $(basename "$TARGET")"

# ---- 1. YAML parses ----
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$TARGET" >/dev/null 2>&1; then
    note_ok "workflow parses as valid YAML"
  else
    note_fail "workflow is not valid YAML (or PyYAML missing)"
  fi
else
  note_fail "python3 not available; cannot validate YAML syntax"
fi

# ---- 2. No write-all anywhere ----
if grep -Eq 'permissions:[[:space:]]*write-all' "$TARGET"; then
  note_fail "workflow still contains 'permissions: write-all' (BAD)"
else
  note_ok "workflow does not use 'permissions: write-all'"
fi

# ---- 3. Top-level permissions: contents: read ----
if awk '
    BEGIN { in_perm=0; found=0; has_other=0 }
    /^permissions:[[:space:]]*$/ { in_perm=1; next }
    in_perm==1 && /^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$/ { found=1; next }
    in_perm==1 && /^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*(write|read)/ { next }
    in_perm==1 && /^[^[:space:]]/ { in_perm=0 }
    END { exit (found==1 ? 0 : 1) }
  ' "$TARGET"; then
  note_ok "top-level 'permissions: contents: read' is declared"
else
  note_fail "missing top-level 'permissions:' block with 'contents: read'"
fi

# ---- 4. Any `contents: write` or `pull-requests: write` must have a 'justif' comment on the same line or the line above ----
#
# We walk the file and check every elevated-write key against:
#   - trailing comment on the same line matching "justif" (case-insensitive), OR
#   - a comment line immediately above (ignoring blank lines) matching "justif".
check_justified() {
  local key_regex="$1"
  local label="$2"
  python3 - "$TARGET" "$key_regex" "$label" <<'PYEOF'
import re, sys
path, key_rx, label = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines()
# Find every line matching key_rx (indented ok): "<ws>key: write"
hit_rx = re.compile(r'^\s+' + key_rx + r':\s*write\b(.*)$')
problems = []
findings = 0
for i, line in enumerate(lines):
    m = hit_rx.match(line)
    if not m:
        continue
    findings += 1
    trailing = m.group(1)
    # Same-line comment with "justif"?
    if '#' in trailing and 'justif' in trailing.lower():
        continue
    # Previous non-blank line as a full comment with "justif"?
    j = i - 1
    while j >= 0 and lines[j].strip() == '':
        j -= 1
    if j >= 0:
        prev = lines[j].strip()
        if prev.startswith('#') and 'justif' in prev.lower():
            continue
    problems.append(f"line {i+1}: '{line.strip()}' has no 'justif' comment on same or previous line")
if findings == 0:
    print(f"NONE::{label} not present in workflow")
    sys.exit(2)
if problems:
    for p in problems:
        print(f"BAD::{label}: {p}")
    sys.exit(1)
print(f"OK::all {label} occurrences are justified ({findings} found)")
sys.exit(0)
PYEOF
}

if out="$(check_justified 'contents' 'contents: write')"; then
  note_ok "$(echo "$out" | sed 's/^OK:://')"
else
  rc=$?
  if [ "$rc" = "2" ]; then
    note_fail "no 'contents: write' escalation found; publish-draft-release must declare one"
  else
    while IFS= read -r line; do
      [ -n "$line" ] && note_fail "$(echo "$line" | sed 's/^BAD:://')"
    done <<< "$out"
  fi
fi

if out="$(check_justified 'pull-requests' 'pull-requests: write')"; then
  note_ok "$(echo "$out" | sed 's/^OK:://')"
else
  rc=$?
  if [ "$rc" = "2" ]; then
    note_fail "no 'pull-requests: write' escalation found; comment-pr must declare one"
  else
    while IFS= read -r line; do
      [ -n "$line" ] && note_fail "$(echo "$line" | sed 's/^BAD:://')"
    done <<< "$out"
  fi
fi

# ---- 5. The lint job should NOT have its own permissions block (inherits top-level) ----
# Heuristic: parse YAML and inspect jobs.lint.
if command -v python3 >/dev/null 2>&1; then
  lint_check="$(python3 - "$TARGET" <<'PYEOF'
import sys, yaml
try:
    data = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print(f"ERR::yaml:{e}"); sys.exit(2)
jobs = (data or {}).get('jobs', {}) or {}
if 'lint' not in jobs:
    print("ERR::no job named 'lint'"); sys.exit(2)
if 'permissions' in jobs['lint']:
    print("BAD::'lint' job declares its own 'permissions:' - should inherit top-level"); sys.exit(1)
print("OK::'lint' job inherits top-level permissions (no own block)")
PYEOF
)"
  rc=$?
  if [ "$rc" = "0" ]; then
    note_ok "$(echo "$lint_check" | sed 's/^OK:://')"
  else
    note_fail "$(echo "$lint_check" | sed -E 's/^(BAD|ERR):://')"
  fi
fi

# ---- 6. MODE handling ----
if [ "$MODE" = "live" ]; then
  note_ok "MODE=live: structural checks identical to local (no network needed for this activity)"
elif [ "$MODE" != "local" ]; then
  note_fail "unknown MODE='$MODE' (use 'local' or 'live')"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT ($MODE): $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
