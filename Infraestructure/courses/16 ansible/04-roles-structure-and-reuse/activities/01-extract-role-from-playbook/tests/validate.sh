#!/usr/bin/env bash
# Structural validation for ans-04-01-extract-role-from-playbook.
#
# Checks that the student built a role 'webserver' under $BASE/roles/webserver
# with the canonical structure (defaults, tasks split in install/configure/
# service, handlers, templates, meta) and a top-level site.yml that invokes
# it. Also runs ansible-playbook --syntax-check IF ansible is installed; if
# not, it reports why and skips that step without failing.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real target host — compare with
# solution/REFERENCE.md and solution/roles/webserver/ for self-assessment.

set -eu

BASE="${1:-/tmp/ans-04-extract}"
ROLE="$BASE/roles/webserver"
issues=0

echo "== Structural validation for $BASE =="

check_dir() {
  local d="$1"
  if [ -d "$d" ]; then
    echo "  OK   $d exists"
  else
    echo "  FAIL $d does not exist"
    issues=$((issues+1))
  fi
}

check_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f does not exist"
    issues=$((issues+1))
  fi
}

check_yaml_parses() {
  local f="$1"
  if [ ! -f "$f" ]; then
    return 0  # already reported as missing
  fi
  if python3 -c "import sys, yaml; yaml.safe_load(open('$f'))" >/dev/null 2>&1; then
    echo "  OK   $f parses as YAML"
  else
    echo "  FAIL $f is not valid YAML"
    issues=$((issues+1))
  fi
}

check_grep() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if [ ! -f "$f" ]; then
    return 0
  fi
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: $label"
  else
    echo "  FAIL $f: $label (pattern: $pattern)"
    issues=$((issues+1))
  fi
}

# --- Top-level site.yml ---------------------------------------------------
SITE="$BASE/site.yml"
check_file "$SITE"
check_yaml_parses "$SITE"
check_grep "$SITE" '^- +(name:|hosts:)' 'declares a play'
check_grep "$SITE" 'hosts: *localhost|hosts: *all' 'targets localhost or all'
check_grep "$SITE" 'connection: *local|ansible_connection=local' 'uses local connection'
check_grep "$SITE" 'webserver' 'invokes the webserver role'

# --- Role structure -------------------------------------------------------
check_dir "$ROLE"
check_dir "$ROLE/defaults"
check_dir "$ROLE/tasks"
check_dir "$ROLE/handlers"
check_dir "$ROLE/templates"
check_dir "$ROLE/meta"

# --- defaults/main.yml ----------------------------------------------------
DEF="$ROLE/defaults/main.yml"
check_file "$DEF"
check_yaml_parses "$DEF"
for var in webserver_port webserver_server_name webserver_worker_processes; do
  check_grep "$DEF" "^${var}:" "defines $var"
done

# --- tasks/main.yml + split -----------------------------------------------
TM="$ROLE/tasks/main.yml"
check_file "$TM"
check_yaml_parses "$TM"
check_grep "$TM" 'import_tasks: *install\.yml' 'imports install.yml'
check_grep "$TM" 'import_tasks: *configure\.yml' 'imports configure.yml'
check_grep "$TM" 'import_tasks: *service\.yml' 'imports service.yml'

INST="$ROLE/tasks/install.yml"
check_file "$INST"
check_yaml_parses "$INST"
check_grep "$INST" '(ansible\.builtin\.)?(package|apt|yum|dnf):' 'uses a package module'

CONF="$ROLE/tasks/configure.yml"
check_file "$CONF"
check_yaml_parses "$CONF"
check_grep "$CONF" '(ansible\.builtin\.)?template:' 'uses the template module'
check_grep "$CONF" 'notify:' 'notifies a handler'

SVC="$ROLE/tasks/service.yml"
check_file "$SVC"
check_yaml_parses "$SVC"
check_grep "$SVC" '(ansible\.builtin\.)?(service|systemd):' 'uses service/systemd module'
check_grep "$SVC" 'state: *started' 'ensures state=started'

# --- handlers/main.yml ----------------------------------------------------
H="$ROLE/handlers/main.yml"
check_file "$H"
check_yaml_parses "$H"
check_grep "$H" '^- +name:' 'defines at least one handler with name'

# --- templates/nginx.conf.j2 ----------------------------------------------
T="$ROLE/templates/nginx.conf.j2"
check_file "$T"
check_grep "$T" '\{\{ *webserver_port *\}\}' 'template references webserver_port'
check_grep "$T" '\{\{ *webserver_server_name *\}\}' 'template references webserver_server_name'

# --- meta/main.yml --------------------------------------------------------
M="$ROLE/meta/main.yml"
check_file "$M"
check_yaml_parses "$M"
check_grep "$M" 'galaxy_info:' 'has galaxy_info block'
check_grep "$M" '^ +author:' 'has author field'
check_grep "$M" 'platforms:' 'has platforms list'
check_grep "$M" '^dependencies:' 'has dependencies key (even if empty)'

# --- README.md ------------------------------------------------------------
R="$ROLE/README.md"
check_file "$R"
if [ -f "$R" ]; then
  for section in "[Vv]ariable" "OS" "[Ee]jemplo|[Ee]xample"; do
    if grep -qE "^#+ .*(${section})" "$R"; then
      echo "  OK   README.md has section matching '${section}'"
    else
      echo "  FAIL README.md missing section matching '${section}'"
      issues=$((issues+1))
    fi
  done
fi

# --- Optional: ansible-playbook --syntax-check ---------------------------
echo
if command -v ansible-playbook >/dev/null 2>&1; then
  echo "== Running ansible-playbook --syntax-check =="
  if [ -f "$SITE" ]; then
    if ( cd "$BASE" && ansible-playbook -i localhost, -c local site.yml --syntax-check ) >/dev/null 2>&1; then
      echo "  OK   site.yml passes --syntax-check"
    else
      echo "  FAIL site.yml does not pass --syntax-check"
      issues=$((issues+1))
    fi
  else
    echo "  SKIP site.yml missing, syntax-check skipped"
  fi
else
  echo "== Skipping ansible-playbook --syntax-check =="
  echo "  INFO ansible-playbook not installed; structural checks still ran."
fi

echo
if [ "$issues" -gt 0 ]; then
  echo "RESULT: $issues issue(s)."
  echo "        (Semantic correctness on a real host is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Structural validation passed."
echo "        Compare with solution/REFERENCE.md for self-assessment."
exit 0
