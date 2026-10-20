#!/usr/bin/env bash
# Structural validation for gl-09-01-apply-compliance-framework.
# Checks that the compliance-pipeline.yml, CODEOWNERS, approval-rules.yml and
# README-INTENT.md exist, parse as YAML where applicable, and include the
# minimum keys / sections required by the module's baseline.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab instance — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-09-framework}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

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

# Parse a YAML file via python3+yaml. Returns 0 iff parses and the python
# expression (passed as $2) evaluates truthy. The python code receives `data`
# as the parsed YAML.
yaml_check() {
  local f="$1"
  local label="$2"
  local pycode="$3"
  if python3 - "$f" <<PYEOF >/dev/null 2>&1
import sys, yaml
try:
    with open(sys.argv[1]) as fh:
        data = yaml.safe_load(fh)
except Exception:
    sys.exit(2)
try:
    ok = bool(${pycode})
except Exception:
    sys.exit(3)
sys.exit(0 if ok else 1)
PYEOF
  then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label}"
    fail=$((fail+1))
  fi
}

yaml_parses() {
  local f="$1"
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    echo "  OK   $(basename "$f") is valid YAML"
  else
    echo "  FAIL $(basename "$f") is not valid YAML"
    fail=$((fail+1))
  fi
}

# --- compliance-pipeline.yml ---------------------------------------------
F1="$BASE/compliance-pipeline.yml"
if check_file_exists "$F1"; then
  yaml_parses "$F1"
  yaml_check "$F1" 'has top-level include' \
    "'include' in data"
  yaml_check "$F1" "include references \$CI_PROJECT_PATH" \
    "'CI_PROJECT_PATH' in yaml.dump(data.get('include'))"
  yaml_check "$F1" "include references \$CI_CONFIG_PATH" \
    "'CI_CONFIG_PATH' in yaml.dump(data.get('include'))"
  yaml_check "$F1" 'declares stages list including compliance' \
    "'compliance' in (data.get('stages') or [])"
  yaml_check "$F1" 'declares a build stage the project can extend' \
    "'build' in (data.get('stages') or [])"
  yaml_check "$F1" 'declares a test stage the project can extend' \
    "'test' in (data.get('stages') or [])"
  yaml_check "$F1" 'declares at least 2 compliance:* jobs' \
    "sum(1 for k in data.keys() if isinstance(k,str) and k.startswith('compliance:')) >= 2"
  yaml_check "$F1" 'all compliance:* jobs live in compliance or compliance-post stage' \
    "all((isinstance(v,dict) and v.get('stage') in ('compliance','compliance-post')) for k,v in data.items() if isinstance(k,str) and k.startswith('compliance:'))"
  yaml_check "$F1" 'all compliance:* jobs have allow_failure: false' \
    "all((isinstance(v,dict) and v.get('allow_failure') is False) for k,v in data.items() if isinstance(k,str) and k.startswith('compliance:'))"
fi

# --- CODEOWNERS -----------------------------------------------------------
F2="$BASE/CODEOWNERS"
if check_file_exists "$F2"; then
  # at least one default * rule
  if grep -qE '^\*[[:space:]]+@' "$F2"; then
    echo "  OK   CODEOWNERS has a default '*' rule with an owner"
  else
    echo "  FAIL CODEOWNERS missing default '*' owner rule"
    fail=$((fail+1))
  fi
  # at least 3 named sections [Name]
  sections=$(grep -cE '^\[[A-Za-z0-9 _-]+\]' "$F2" || true)
  if [ "$sections" -ge 3 ]; then
    echo "  OK   CODEOWNERS has >=3 named sections ($sections)"
  else
    echo "  FAIL CODEOWNERS has only $sections named sections (expected >=3)"
    fail=$((fail+1))
  fi
  # at least 3 distinct @group/ owners
  distinct_groups=$(grep -oE '@group/[A-Za-z0-9_-]+' "$F2" | sort -u | wc -l | tr -d ' ')
  if [ "$distinct_groups" -ge 3 ]; then
    echo "  OK   CODEOWNERS references >=3 distinct @group/ owners ($distinct_groups)"
  else
    echo "  FAIL CODEOWNERS references only $distinct_groups distinct @group/ owners (expected >=3)"
    fail=$((fail+1))
  fi
  # mentions compliance config (.gitlab-ci.yml OR /.gitlab/)
  if grep -qE '(\.gitlab-ci\.yml|/\.gitlab/)' "$F2"; then
    echo "  OK   CODEOWNERS protects CI config (.gitlab-ci.yml or /.gitlab/)"
  else
    echo "  FAIL CODEOWNERS does not protect .gitlab-ci.yml or /.gitlab/"
    fail=$((fail+1))
  fi
fi

# --- approval-rules.yml ---------------------------------------------------
F3="$BASE/approval-rules.yml"
if check_file_exists "$F3"; then
  yaml_parses "$F3"
  yaml_check "$F3" 'has top-level project key' \
    "'project' in data"
  yaml_check "$F3" 'has rules list with >=3 entries' \
    "isinstance(data.get('rules'), list) and len(data.get('rules')) >= 3"
  yaml_check "$F3" 'at least one rule with approvals_required: 2 and prevent_author_approval' \
    "any((isinstance(r,dict) and r.get('approvals_required')==2 and r.get('prevent_author_approval') is True and r.get('prevent_committers_approval') is True) for r in (data.get('rules') or []))"
  yaml_check "$F3" 'at least one rule with code_owner_approval_required: true' \
    "any((isinstance(r,dict) and r.get('code_owner_approval_required') is True) for r in (data.get('rules') or []))"
  yaml_check "$F3" 'at least one rule with report_type vulnerability and high/critical severities' \
    "any((isinstance(r,dict) and r.get('report_type')=='vulnerability' and set(r.get('severity_levels') or []).intersection({'high','critical'})) for r in (data.get('rules') or []))"
fi

# --- README-INTENT.md -----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "compliance-pipeline" "CODEOWNERS" "approval-rules" "sobrescribir"; do
    if grep -qiE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  for term in "SAST" "Secret Detection" "Code Owners" "approval rules" "Compliance Framework"; do
    if grep -qi "$term" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${term}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${term}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'extend|extiende|puede extender' "$DOC" && grep -qiE 'omit|no puede (omitir|sobres|evitar|evadir)' "$DOC"; then
    echo "  OK   README-INTENT.md explains extend vs omit"
  else
    echo "  FAIL README-INTENT.md does not explain extend vs omit"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real GitLab instance is NOT verified here.)"
  exit 1
fi
echo "OK: compliance framework skeleton pasa validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
