#!/usr/bin/env bash
# Structural + optional dynamic validation for ans-02-01-nginx-reverse-proxy.
#
# Checks:
#   - playbook.yml exists and contains the required modules, handler and notify
#   - templates/nginx-proxy.conf.j2 exists and parametrizes server_name,
#     upstream_host, upstream_port with Jinja2 placeholders
#   - group_vars/web.yml exists with the three required variables
#   - inventory.ini exists
#   - no `shell:` or `command:` modules present
#   - (optional) `ansible-playbook --syntax-check` if ansible is installed
#   - (optional) `ansible-lint` if available — WARN, never fail
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness (whether nginx really proxies). Compare
# manually with solution/.

set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Default: validate the student solution (one dir up). Override with $1.
BASE="${1:-$HERE/..}"
BASE="$(cd "$BASE" && pwd)"

fail=0
echo "== Structural validation for $BASE =="

PLAYBOOK="$BASE/playbook.yml"
TEMPLATE="$BASE/templates/nginx-proxy.conf.j2"
GROUPVARS="$BASE/group_vars/web.yml"
INVENTORY="$BASE/inventory.ini"

check_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
  else
    echo "  FAIL $(basename "$f") does not exist at $f"
    fail=$((fail+1))
  fi
}

check_grep() {
  local f="$1" pat="$2" label="$3"
  if [ ! -f "$f" ]; then
    echo "  FAIL ${label} (file missing: $f)"
    fail=$((fail+1)); return
  fi
  if grep -qE "$pat" "$f"; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (pattern: $pat)"
    fail=$((fail+1))
  fi
}

check_grep_not() {
  local f="$1" pat="$2" label="$3"
  if [ ! -f "$f" ]; then return; fi
  if grep -qE "$pat" "$f"; then
    echo "  FAIL $(basename "$f"): ${label} (unexpected pattern: $pat)"
    fail=$((fail+1))
  else
    echo "  OK   $(basename "$f"): ${label}"
  fi
}

# ---------------------------------------------------------------- Files --
check_file "$PLAYBOOK"
check_file "$TEMPLATE"
check_file "$GROUPVARS"
check_file "$INVENTORY"

# ---------------------------------------------------------- playbook.yml --
check_grep "$PLAYBOOK" '^-[[:space:]]+name:' "declares at least one play with 'name:'"
check_grep "$PLAYBOOK" 'hosts:[[:space:]]*web' "targets hosts: web"
check_grep "$PLAYBOOK" 'become:[[:space:]]*true' "uses become: true"
check_grep "$PLAYBOOK" '(ansible\.builtin\.)?(apt|package)\b' "installs nginx with apt/package module"
check_grep "$PLAYBOOK" '(ansible\.builtin\.)?template:' "uses the template module"
check_grep "$PLAYBOOK" '(ansible\.builtin\.)?file:' "uses the file module (symlink/absent)"
check_grep "$PLAYBOOK" '(ansible\.builtin\.)?(service|systemd):' "uses service/systemd module"
check_grep "$PLAYBOOK" '^[[:space:]]*handlers:' "defines a handlers: section"
check_grep "$PLAYBOOK" 'name:[[:space:]]*Reload nginx' "defines handler 'Reload nginx'"
check_grep "$PLAYBOOK" 'notify:[[:space:]]*(Reload nginx|\[[^]]*Reload nginx)' "at least one notify: Reload nginx"
check_grep "$PLAYBOOK" 'state:[[:space:]]*reloaded' "handler reloads nginx (state: reloaded)"

# Forbidden: raw shell/command for operations that have a native module
check_grep_not "$PLAYBOOK" '^[[:space:]]*(ansible\.builtin\.)?shell:' "does NOT use shell: module"
check_grep_not "$PLAYBOOK" '^[[:space:]]*(ansible\.builtin\.)?command:' "does NOT use command: module"

# ---------------------------------------------------- template parametrize --
check_grep "$TEMPLATE" '\{\{[[:space:]]*server_name[[:space:]]*\}\}' "template references {{ server_name }}"
check_grep "$TEMPLATE" '\{\{[[:space:]]*upstream_host[[:space:]]*\}\}' "template references {{ upstream_host }}"
check_grep "$TEMPLATE" '\{\{[[:space:]]*upstream_port[[:space:]]*\}\}' "template references {{ upstream_port }}"
check_grep "$TEMPLATE" 'proxy_pass' "template contains proxy_pass directive"

# -------------------------------------------------------------- group_vars --
check_grep "$GROUPVARS" '^server_name:' "group_vars/web.yml declares server_name"
check_grep "$GROUPVARS" '^upstream_host:' "group_vars/web.yml declares upstream_host"
check_grep "$GROUPVARS" '^upstream_port:' "group_vars/web.yml declares upstream_port"

# --------------------------------------------- Optional: ansible available --
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

# ---------------------------------------------------- Repo hygiene --------
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE contains ANALYSIS.md — this repo convention does NOT use ANALYSIS.md"
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md present"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Semantic correctness — that nginx truly proxies — is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Playbook, template y vars pasan validacion estructural."
echo "        Compara con solution/ para autoevaluacion semantica."
exit 0
