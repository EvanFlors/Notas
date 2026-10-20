#!/usr/bin/env bash
# Structural validation for ans-02-02-fix-non-idempotent-task.
#
# Checks that the student's playbook.yml:
#   - no longer uses raw `shell:` / `command:` without `creates:`/`removes:`/`changed_when:`
#   - uses the expected native modules (user, file, lineinfile, get_url or copy)
#   - carries at least 4 `# FIX:` comments justifying the changes
#   - (optional) passes `ansible-playbook --syntax-check` if ansible is installed
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${1:-$HERE/..}"
BASE="$(cd "$BASE" && pwd)"

fail=0
echo "== Structural validation for $BASE =="

PLAYBOOK="$BASE/playbook.yml"
INVENTORY="$BASE/inventory.ini"

if [ ! -f "$PLAYBOOK" ]; then
  echo "  FAIL playbook.yml not found at $PLAYBOOK"
  echo
  echo "RESULT: 1 issue(s)."
  exit 1
fi
echo "  OK   playbook.yml exists"

if [ -f "$INVENTORY" ]; then
  echo "  OK   inventory.ini exists"
else
  echo "  FAIL inventory.ini not found at $INVENTORY"
  fail=$((fail+1))
fi

# ---- Native modules present -------------------------------------------
check_native() {
  local pat="$1" label="$2"
  if grep -qE "$pat" "$PLAYBOOK"; then
    echo "  OK   usa ${label}"
  else
    echo "  FAIL falta ${label} (patron: $pat)"
    fail=$((fail+1))
  fi
}
check_native '^[[:space:]]{2,8}(ansible\.builtin\.)?user:[[:space:]]*$' 'modulo user'
check_native '^[[:space:]]{2,8}(ansible\.builtin\.)?file:[[:space:]]*$' 'modulo file'
check_native '^[[:space:]]{2,8}(ansible\.builtin\.)?lineinfile:[[:space:]]*$' 'modulo lineinfile'
check_native '^[[:space:]]{2,8}(ansible\.builtin\.)?(get_url|copy):[[:space:]]*$' 'modulo get_url o copy'

# ---- Any remaining shell/command must be qualified --------------------
# Count tasks that use shell: or command: without a creates/removes/changed_when nearby.
#
# Heuristic: for every line that opens a `shell:` or `command:` task we look
# at the next 10 lines for `creates:`, `removes:`, or `changed_when:`. If none,
# we count it as a bare raw task.

bare=0
# -n to print line numbers; sort by file order already.
# Match shell:/command: only at task-module indent (2-6 leading spaces, not deeper
# — which would be a parameter of another module like `user: { shell: /bin/bash }`).
mapfile -t raw_lines < <(grep -nE '^[[:space:]]{2,6}(ansible\.builtin\.)?(shell|command):[[:space:]]+[^[:space:]]' "$PLAYBOOK" || true)
for entry in "${raw_lines[@]}"; do
  lineno="${entry%%:*}"
  # look ahead 10 lines
  window=$(sed -n "${lineno},$((lineno+10))p" "$PLAYBOOK")
  if ! printf '%s\n' "$window" | grep -qE '(creates|removes|changed_when):'; then
    bare=$((bare+1))
  fi
done

if [ "$bare" -eq 0 ]; then
  echo "  OK   ningun shell:/command: sin creates/removes/changed_when"
else
  echo "  FAIL ${bare} shell:/command: tasks sin creates/removes/changed_when"
  fail=$((fail+1))
fi

# ---- At least 4 FIX comments -----------------------------------------
fixes=$(grep -cE '^[[:space:]]*#[[:space:]]*FIX' "$PLAYBOOK" || true)
if [ "$fixes" -ge 4 ]; then
  echo "  OK   ${fixes} comentarios '# FIX:' justifican los cambios (>=4)"
else
  echo "  FAIL solo ${fixes} comentarios '# FIX:' encontrados (>=4 esperados)"
  fail=$((fail+1))
fi

# ---- Must not keep the raw duplication antipattern -------------------
if grep -qE 'echo[[:space:]]+"?FOO=bar"?[[:space:]]*>>' "$PLAYBOOK"; then
  echo "  FAIL sigue el antipattern 'echo FOO=bar >> /etc/environment'"
  fail=$((fail+1))
else
  echo "  OK   no queda 'echo FOO=bar >>' en el playbook"
fi

# ---- Optional: syntax-check ------------------------------------------
if command -v ansible-playbook >/dev/null 2>&1; then
  if ansible-playbook --syntax-check -i "$INVENTORY" "$PLAYBOOK" >/dev/null 2>&1; then
    echo "  OK   ansible-playbook --syntax-check passes"
  else
    echo "  FAIL ansible-playbook --syntax-check failed"
    fail=$((fail+1))
  fi
else
  echo "  SKIP ansible-playbook not installed; syntax check skipped"
fi

if command -v ansible-lint >/dev/null 2>&1; then
  if ansible-lint "$PLAYBOOK" >/dev/null 2>&1; then
    echo "  OK   ansible-lint clean"
  else
    echo "  WARN ansible-lint reported issues (non-blocking)"
  fi
else
  echo "  SKIP ansible-lint not installed; lint skipped"
fi

# ---- Repo hygiene ---------------------------------------------------
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE contains ANALYSIS.md — this repo convention does NOT use ANALYSIS.md"
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md present"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s). Playbook idempotente y comentado."
echo "        Compara con solution/playbook.yml para autoevaluacion."
exit 0
