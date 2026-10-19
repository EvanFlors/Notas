#!/usr/bin/env bash
# Structural validation for jk-07-01-harden-fresh-jenkins.
#
# Checks that:
#   - jenkins.yaml exists and is valid YAML (via python3).
#   - It declares a local realm with allowsSignup: false and the bootstrap user.
#   - authorizationStrategy.roleBased.roles.global contains an 'admin' role
#     with Overall/Administer bound to the 'jenkins-admins' group.
#   - roles.items contains at least 2 project roles with regex patterns and
#     bound to groups 'team-a' and 'team-b'.
#   - No role references the 'anonymous' group.
#   - crumbIssuer.standard is declared (CSRF on).
#   - credentials.system.domainCredentials contains at least a string,
#     usernamePassword and basicSSHUserPrivateKey entry; every secret-ish
#     value is a ${...} env placeholder, not a literal.
#   - security.scriptApproval.approvedSignatures has at least 2 entries and
#     NEVER contains 'invoke' or 'evaluate' as approved method call.
#   - No obvious real-secret patterns (ghp_, AKIA, PRIVATE KEY) in jenkins.yaml.
#   - HARDENING-NOTES.md exists with the 5 required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/jk-07-harden}"
YAML="$BASE/jenkins.yaml"
DOC="$BASE/HARDENING-NOTES.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

# -------- jenkins.yaml --------
if [ ! -f "$YAML" ]; then
  echo "FAIL: $YAML does not exist. Student must produce it."
  exit 1
fi
echo "  OK   $YAML exists"

if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$YAML" >/dev/null 2>&1; then
  echo "  OK   jenkins.yaml is valid YAML"
else
  echo "  FAIL jenkins.yaml is not valid YAML"
  fail=$((fail+1))
fi

# Realm checks (grep is good enough for these string literals).
if grep -qE '^[[:space:]]*allowsSignup:[[:space:]]*false' "$YAML"; then
  echo "  OK   allowsSignup: false"
else
  echo "  FAIL allowsSignup must be false"
  fail=$((fail+1))
fi

if grep -q 'admin-bootstrap' "$YAML"; then
  echo "  OK   bootstrap admin user declared"
else
  echo "  FAIL missing bootstrap admin user (expected id: 'admin-bootstrap')"
  fail=$((fail+1))
fi

# Authorization — admin role with Overall/Administer bound to jenkins-admins.
if grep -q 'roleBased' "$YAML"; then
  echo "  OK   roleBased authorization strategy present"
else
  echo "  FAIL authorizationStrategy.roleBased missing"
  fail=$((fail+1))
fi

if grep -q 'Overall/Administer' "$YAML"; then
  echo "  OK   Overall/Administer declared"
else
  echo "  FAIL no Overall/Administer permission declared"
  fail=$((fail+1))
fi

if grep -q 'jenkins-admins' "$YAML"; then
  echo "  OK   admin role bound to group jenkins-admins"
else
  echo "  FAIL admin role not bound to group 'jenkins-admins'"
  fail=$((fail+1))
fi

for g in "team-a" "team-b" "all-staff"; do
  if grep -q "$g" "$YAML"; then
    echo "  OK   group '$g' referenced"
  else
    echo "  FAIL group '$g' not referenced"
    fail=$((fail+1))
  fi
done

# Items roles with regex pattern.
items_patterns=$(grep -cE '^[[:space:]]*pattern:[[:space:]]*' "$YAML" || true)
if [ "$items_patterns" -ge 2 ]; then
  echo "  OK   at least 2 items roles with regex pattern (found $items_patterns)"
else
  echo "  FAIL fewer than 2 items roles with regex pattern (found $items_patterns)"
  fail=$((fail+1))
fi

# Anonymous must not be assigned.
if grep -qE '(group|user):[[:space:]]*"?anonymous"?' "$YAML"; then
  echo "  FAIL some role is assigned to 'anonymous' (must be removed)"
  fail=$((fail+1))
else
  echo "  OK   no role assigned to anonymous"
fi

# CSRF.
if grep -q 'crumbIssuer' "$YAML"; then
  echo "  OK   crumbIssuer declared (CSRF on)"
else
  echo "  FAIL crumbIssuer missing (CSRF off by default elsewhere)"
  fail=$((fail+1))
fi

# Credentials — three required types.
for kind in "string:" "usernamePassword:" "basicSSHUserPrivateKey:"; do
  if grep -qE "^[[:space:]]*- ${kind}" "$YAML" \
     || grep -qE "^[[:space:]]*${kind}" "$YAML"; then
    echo "  OK   credentials include '$kind'"
  else
    echo "  FAIL credentials missing '$kind'"
    fail=$((fail+1))
  fi
done

# Every secret/password/privateKey value must be a ${...} env placeholder.
bad_secret_lines=$(grep -nE '^[[:space:]]*(secret|password|privateKey):[[:space:]]*' "$YAML" \
  | grep -v '\${' || true)
if [ -z "$bad_secret_lines" ]; then
  echo "  OK   all secret-ish values use \${ENV_VAR} placeholders"
else
  echo "  FAIL some secret value is not a \${ENV_VAR} placeholder:"
  printf '       %s\n' "$bad_secret_lines"
  fail=$((fail+1))
fi

# Obvious real-secret patterns.
if grep -qE 'ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----' "$YAML"; then
  echo "  FAIL jenkins.yaml contains a real-looking secret pattern (ghp_/AKIA/PRIVATE KEY)"
  fail=$((fail+1))
else
  echo "  OK   no real-looking secret patterns detected"
fi

# Script approval — at least 2 approved signatures, no 'invoke' or 'evaluate'.
if grep -q 'approvedSignatures' "$YAML"; then
  echo "  OK   security.scriptApproval.approvedSignatures block present"
else
  echo "  FAIL security.scriptApproval.approvedSignatures block missing"
  fail=$((fail+1))
fi

approved_count=$(grep -cE '^[[:space:]]*-[[:space:]]*"(method|staticMethod|new|field|staticField) ' "$YAML" || true)
if [ "$approved_count" -ge 2 ]; then
  echo "  OK   at least 2 approved signatures (found $approved_count)"
else
  echo "  FAIL fewer than 2 approved signatures (found $approved_count)"
  fail=$((fail+1))
fi

if grep -qE '"[^"]*(GroovyShell[[:space:]]+evaluate|MethodCall[[:space:]]+invoke|[[:space:]]invoke [[:space:]]|[[:space:]]evaluate [[:space:]])' "$YAML"; then
  echo "  FAIL approvedSignatures contains an 'invoke'/'evaluate' escape"
  fail=$((fail+1))
else
  # Secondary generic check: any approved signature that includes the words
  # 'invoke' or 'evaluate' as a bare method name is also rejected.
  if grep -qE '^[[:space:]]*-[[:space:]]*"(method|staticMethod)[^"]*(\sinvoke\s|\sevaluate\s|\sinvoke"|\sevaluate")' "$YAML"; then
    echo "  FAIL approvedSignatures contains an 'invoke'/'evaluate' method (sandbox escape)"
    fail=$((fail+1))
  else
    echo "  OK   no sandbox-escape methods (invoke/evaluate) in approvedSignatures"
  fi
fi

# -------- HARDENING-NOTES.md --------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   $DOC exists"
  for section in "Autenticacion" "Autorizacion" "Credentials" "Script Approval" "Pendiente"; do
    if grep -qE "^#+ +${section}" "$DOC"; then
      echo "  OK   HARDENING-NOTES.md has '${section}' section"
    else
      echo "  FAIL HARDENING-NOTES.md missing '${section}' section"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: jenkins.yaml y HARDENING-NOTES.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
