#!/usr/bin/env bash
# Structural validation for ans-04-02-role-dependency-chain.
#
# Checks that the student built 3 roles (common, webserver, fastapi-app)
# under $BASE/roles/, each with the canonical structure, that site.yml
# is coherent with the chaining option chosen (A: dependencies in meta,
# B: explicit composition in site.yml), and that README-INTENT.md
# documents the decision. Also runs ansible-playbook --syntax-check IF
# ansible is installed; otherwise skips with INFO.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness on a real host — compare with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-04-chain}"
ROLES="$BASE/roles"
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

check_yaml() {
  local f="$1"
  if [ ! -f "$f" ]; then return 0; fi
  if python3 -c "import sys, yaml; yaml.safe_load(open('$f'))" >/dev/null 2>&1; then
    echo "  OK   $f parses as YAML"
  else
    echo "  FAIL $f is not valid YAML"
    issues=$((issues+1))
  fi
}

check_grep() {
  local f="$1"; local pattern="$2"; local label="$3"
  if [ ! -f "$f" ]; then return 0; fi
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: $label"
  else
    echo "  FAIL $f: $label (pattern: $pattern)"
    issues=$((issues+1))
  fi
}

# --- Per-role structure ---------------------------------------------------
for role in common webserver fastapi-app; do
  R="$ROLES/$role"
  check_dir "$R"
  check_dir "$R/defaults"
  check_dir "$R/tasks"
  check_dir "$R/meta"
  check_file "$R/defaults/main.yml"
  check_yaml "$R/defaults/main.yml"
  check_file "$R/tasks/main.yml"
  check_yaml "$R/tasks/main.yml"
  check_file "$R/meta/main.yml"
  check_yaml "$R/meta/main.yml"
  check_file "$R/README.md"
done

# --- Role-specific content ------------------------------------------------
check_grep "$ROLES/common/defaults/main.yml" '^common_timezone:' 'defines common_timezone'
check_grep "$ROLES/common/defaults/main.yml" '^common_appuser:' 'defines common_appuser'
check_grep "$ROLES/common/tasks/main.yml" '(ansible\.builtin\.)?user:' 'uses user module'

check_grep "$ROLES/webserver/defaults/main.yml" '^webserver_port:' 'defines webserver_port'
check_grep "$ROLES/webserver/defaults/main.yml" '^webserver_upstream_port:' 'defines webserver_upstream_port'
check_grep "$ROLES/webserver/tasks/main.yml" '(ansible\.builtin\.)?(template|copy):' 'deploys a template/copy'
check_file "$ROLES/webserver/handlers/main.yml"
check_yaml "$ROLES/webserver/handlers/main.yml"
check_file "$ROLES/webserver/templates/nginx.conf.j2"
check_grep "$ROLES/webserver/templates/nginx.conf.j2" 'proxy_pass' 'template uses proxy_pass'
check_grep "$ROLES/webserver/templates/nginx.conf.j2" '\{\{ *webserver_upstream_port *\}\}' 'template references upstream port'

check_grep "$ROLES/fastapi-app/defaults/main.yml" '^fastapi_app_name:' 'defines fastapi_app_name'
check_grep "$ROLES/fastapi-app/defaults/main.yml" '^fastapi_app_port:' 'defines fastapi_app_port'
check_grep "$ROLES/fastapi-app/defaults/main.yml" '^fastapi_app_user:' 'defines fastapi_app_user'
check_file "$ROLES/fastapi-app/handlers/main.yml"
check_yaml "$ROLES/fastapi-app/handlers/main.yml"
check_file "$ROLES/fastapi-app/templates/fastapi-app.service.j2"
check_grep "$ROLES/fastapi-app/templates/fastapi-app.service.j2" '\[Service\]' 'systemd unit has [Service] section'
check_grep "$ROLES/fastapi-app/templates/fastapi-app.service.j2" '\[Install\]' 'systemd unit has [Install] section'

# --- site.yml -------------------------------------------------------------
SITE="$BASE/site.yml"
check_file "$SITE"
check_yaml "$SITE"
check_grep "$SITE" 'hosts: *localhost|hosts: *all' 'site.yml targets localhost or all'
check_grep "$SITE" 'connection: *local|ansible_connection=local' 'site.yml uses local connection'

# --- Chaining coherence (option A OR option B) ----------------------------
# Option A: meta/main.yml of fastapi-app or webserver declare non-empty deps
# Option B: site.yml lists all 3 roles explicitly
opt_a=0
opt_b=0
if [ -f "$ROLES/fastapi-app/meta/main.yml" ]; then
  if grep -A5 '^dependencies:' "$ROLES/fastapi-app/meta/main.yml" | grep -qE '(role: *webserver|- +webserver)'; then
    opt_a=1
  fi
fi
if [ -f "$ROLES/webserver/meta/main.yml" ]; then
  if grep -A5 '^dependencies:' "$ROLES/webserver/meta/main.yml" | grep -qE '(role: *common|- +common)'; then
    opt_a=$((opt_a+1))
  fi
fi
if [ -f "$SITE" ]; then
  if grep -qE 'common' "$SITE" && grep -qE 'webserver' "$SITE" && grep -qE 'fastapi-app' "$SITE"; then
    opt_b=1
  fi
fi

if [ "$opt_a" -ge 1 ] || [ "$opt_b" -eq 1 ]; then
  if [ "$opt_a" -ge 1 ]; then
    echo "  OK   chaining via meta/main.yml:dependencies detected (Option A)"
  fi
  if [ "$opt_b" -eq 1 ]; then
    echo "  OK   chaining via explicit composition in site.yml detected (Option B)"
  fi
else
  echo "  FAIL no chaining detected: neither meta dependencies nor 3 roles in site.yml"
  issues=$((issues+1))
fi

# --- README-INTENT.md -----------------------------------------------------
DOC="$BASE/README-INTENT.md"
check_file "$DOC"
if [ -f "$DOC" ]; then
  for section in "Decision" "common" "webserver" "fastapi-app" "Trade-offs"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      issues=$((issues+1))
    fi
  done
  for term in "meta/main.yml" "dependencies" "composicion|composición"; do
    if grep -qiE "$term" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${term}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${term}'"
      issues=$((issues+1))
    fi
  done
fi

# --- Optional ansible --syntax-check --------------------------------------
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
