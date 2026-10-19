#!/usr/bin/env bash
# Structural validation for jk-07-02-audit-and-remediate-legacy.
#
# Checks that AUDIT.md and REMEDIATION-PLAN.md exist and contain the
# required sections, severities, and keywords tying the audit to the real
# snapshot (anonymous, sandbox-escape, plugin names, credential ids).
# Also checks the remediation plan includes the 4 required phases + success
# criteria + rollback.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/jk-07-audit}"
AUDIT="$BASE/AUDIT.md"
PLAN="$BASE/REMEDIATION-PLAN.md"
fail=0

echo "== Structural validation for $BASE =="

# -------- AUDIT.md --------
if [ ! -f "$AUDIT" ]; then
  echo "FAIL: $AUDIT does not exist. Student must produce it."
  exit 1
fi
echo "  OK   $AUDIT exists"

for section in "Resumen ejecutivo" "Hallazgos" "Matriz severidad"; do
  if grep -qiE "^#+ +${section}" "$AUDIT"; then
    echo "  OK   AUDIT.md has '${section}' section"
  else
    echo "  FAIL AUDIT.md missing '${section}' section"
    fail=$((fail+1))
  fi
done

# Must have at least 6 finding sub-headings and cover at least 3 severities.
findings=$(grep -cE '^###[[:space:]]+(Critical|High|Medium|Low)' "$AUDIT" || true)
if [ "$findings" -ge 6 ]; then
  echo "  OK   AUDIT.md has at least 6 findings (found $findings)"
else
  echo "  FAIL AUDIT.md has fewer than 6 findings (found $findings)"
  fail=$((fail+1))
fi

distinct_sev=0
for sev in "Critical" "High" "Medium" "Low"; do
  if grep -qE "^###[[:space:]]+${sev}" "$AUDIT"; then
    distinct_sev=$((distinct_sev+1))
  fi
done
if [ "$distinct_sev" -ge 3 ]; then
  echo "  OK   AUDIT.md spans at least 3 severity levels (found $distinct_sev)"
else
  echo "  FAIL AUDIT.md covers only $distinct_sev severity levels (expected >=3)"
  fail=$((fail+1))
fi

# Required keywords tying the audit to the 4 obligatory categories.
if grep -qi 'anonymous' "$AUDIT"; then
  echo "  OK   AUDIT.md mentions 'anonymous' (authorization finding)"
else
  echo "  FAIL AUDIT.md does not mention 'anonymous'"
  fail=$((fail+1))
fi

if grep -qiE 'sandbox|invoke|evaluate' "$AUDIT"; then
  echo "  OK   AUDIT.md mentions sandbox/invoke/evaluate (script approval finding)"
else
  echo "  FAIL AUDIT.md does not mention sandbox/invoke/evaluate"
  fail=$((fail+1))
fi

# At least one plugin name from plugins.txt should appear.
plugin_hits=0
for p in "script-security" "workflow-cps" "blueocean" "cvs" "subversion" "kubernetes" "credentials" "groovy-postbuild"; do
  if grep -qi "$p" "$AUDIT"; then
    plugin_hits=$((plugin_hits+1))
  fi
done
if [ "$plugin_hits" -ge 1 ]; then
  echo "  OK   AUDIT.md mentions at least 1 plugin by name (found $plugin_hits)"
else
  echo "  FAIL AUDIT.md does not mention any plugin from plugins.txt"
  fail=$((fail+1))
fi

# At least one credential id should appear.
cred_hits=0
for c in "gh-pat-legacy" "gh-pat-personal-jose" "aws-prod-keys" "docker-hub" "old-svn-password" "k8s-prod-sa" "signing-key" "vault-approle"; do
  if grep -q "$c" "$AUDIT"; then
    cred_hits=$((cred_hits+1))
  fi
done
if [ "$cred_hits" -ge 1 ]; then
  echo "  OK   AUDIT.md mentions at least 1 credential id (found $cred_hits)"
else
  echo "  FAIL AUDIT.md does not mention any credential id from the inventory"
  fail=$((fail+1))
fi

# -------- REMEDIATION-PLAN.md --------
if [ ! -f "$PLAN" ]; then
  echo "FAIL: $PLAN does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   $PLAN exists"
  for section in "Fase 1" "Fase 2" "Fase 3" "Fase 4" "Criterios de exito" "Rollback"; do
    if grep -qiE "^#+ +${section}" "$PLAN"; then
      echo "  OK   REMEDIATION-PLAN.md has '${section}' section"
    else
      echo "  FAIL REMEDIATION-PLAN.md missing '${section}' section"
      fail=$((fail+1))
    fi
  done

  # Must mention 'desinstalar' or 'uninstall' somewhere — reducing surface
  # is the explicit lesson in the module.
  if grep -qiE 'desinstalar|uninstall' "$PLAN"; then
    echo "  OK   REMEDIATION-PLAN.md includes 'desinstalar'/'uninstall' action"
  else
    echo "  FAIL REMEDIATION-PLAN.md does not include a 'desinstalar'/'uninstall' action"
    fail=$((fail+1))
  fi

  # Phase 1 should mention script-security or sandbox (urgency items).
  if grep -qiE 'script-security|sandbox|anonymous' "$PLAN"; then
    echo "  OK   REMEDIATION-PLAN.md addresses critical items (script-security/sandbox/anonymous)"
  else
    echo "  FAIL REMEDIATION-PLAN.md does not address critical items"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: AUDIT.md y REMEDIATION-PLAN.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
