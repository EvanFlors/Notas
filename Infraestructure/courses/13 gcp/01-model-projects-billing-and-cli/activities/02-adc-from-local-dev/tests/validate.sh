#!/usr/bin/env bash
# Structural + light-semantic validation for gcp-01-02-adc-from-local-dev.
#
# Checks that adc-plan.md and verify-adc.sh exist and meet the content
# requirements of the activity README (sections, commands, no destructive
# gcloud calls).
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# posteriores con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria esos
# como fallos espurios.
#
# Does NOT grade semantic correctness in a real GCP account — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-01-adc}"
fail=0

echo "== Structural validation for $BASE =="

PLAN="$BASE/adc-plan.md"
SCRIPT="$BASE/verify-adc.sh"

# ---------- adc-plan.md ----------
if [ ! -f "$PLAN" ]; then
  echo "  FAIL $PLAN does not exist"
  fail=$((fail+1))
else
  echo "  OK   adc-plan.md exists"

  for section in "Problema" "Mecanismos" "Flujo +recomendado" "Chequeos" "Riesgos" "Antipatr[oó]n"; do
    label=$(echo "$section" | sed 's/ \+.*//')
    if grep -qiE "^#+ +${section}\\b" "$PLAN"; then
      echo "  OK   plan has '${label}' section"
    else
      echo "  FAIL plan missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # Must mention both commands.
  if grep -qF 'gcloud auth login' "$PLAN"; then
    echo "  OK   plan mentions 'gcloud auth login'"
  else
    echo "  FAIL plan does not mention 'gcloud auth login'"
    fail=$((fail+1))
  fi
  if grep -qF 'gcloud auth application-default login' "$PLAN"; then
    echo "  OK   plan mentions 'gcloud auth application-default login'"
  else
    echo "  FAIL plan does not mention 'gcloud auth application-default login'"
    fail=$((fail+1))
  fi

  # ADC file location.
  if grep -qF 'application_default_credentials.json' "$PLAN"; then
    echo "  OK   plan mentions application_default_credentials.json"
  else
    echo "  FAIL plan does not mention application_default_credentials.json"
    fail=$((fail+1))
  fi

  # Impersonation flag.
  if grep -qF -- '--impersonate-service-account' "$PLAN"; then
    echo "  OK   plan mentions --impersonate-service-account"
  else
    echo "  FAIL plan does not mention --impersonate-service-account"
    fail=$((fail+1))
  fi

  # Token-creator role.
  if grep -qF 'roles/iam.serviceAccountTokenCreator' "$PLAN"; then
    echo "  OK   plan mentions roles/iam.serviceAccountTokenCreator"
  else
    echo "  FAIL plan does not mention roles/iam.serviceAccountTokenCreator"
    fail=$((fail+1))
  fi

  # iamcredentials API.
  if grep -qE 'iamcredentials' "$PLAN"; then
    echo "  OK   plan mentions iamcredentials"
  else
    echo "  FAIL plan does not mention iamcredentials"
    fail=$((fail+1))
  fi

  # Metadata server / in-GCP ADC chain.
  if grep -qiE 'metadata +server|metadata\.google\.internal' "$PLAN"; then
    echo "  OK   plan mentions metadata server"
  else
    echo "  FAIL plan does not mention metadata server"
    fail=$((fail+1))
  fi

  # SA key antipattern.
  if grep -qiE 'private_key|service +account +key|SA +key|service-account +key' "$PLAN"; then
    echo "  OK   plan addresses the SA key antipattern"
  else
    echo "  FAIL plan does not address the SA key antipattern"
    fail=$((fail+1))
  fi

  # Placeholder project ID.
  if grep -q 'my-project-123' "$PLAN"; then
    echo "  OK   plan uses placeholder my-project-123"
  else
    echo "  FAIL plan does not use placeholder my-project-123"
    fail=$((fail+1))
  fi

  # Placeholder SA email.
  if grep -qE '[a-z0-9_-]+@my-project-123\.iam\.gserviceaccount\.com' "$PLAN"; then
    echo "  OK   plan references a SA placeholder (*@my-project-123.iam.gserviceaccount.com)"
  else
    echo "  FAIL plan does not reference a SA placeholder (*@my-project-123.iam.gserviceaccount.com)"
    fail=$((fail+1))
  fi
fi

# ---------- verify-adc.sh ----------
if [ ! -f "$SCRIPT" ]; then
  echo "  FAIL $SCRIPT does not exist"
  fail=$((fail+1))
else
  echo "  OK   verify-adc.sh exists"

  # Shebang
  if head -n1 "$SCRIPT" | grep -qE '^#!.*(bash|sh)'; then
    echo "  OK   verify-adc.sh has a shebang"
  else
    echo "  FAIL verify-adc.sh missing shebang"
    fail=$((fail+1))
  fi

  # Executable
  if [ -x "$SCRIPT" ]; then
    echo "  OK   verify-adc.sh is executable (chmod +x)"
  else
    echo "  FAIL verify-adc.sh is not executable (chmod +x missing)"
    fail=$((fail+1))
  fi

  # Syntactically valid bash
  if bash -n "$SCRIPT" 2>/dev/null; then
    echo "  OK   verify-adc.sh is syntactically valid bash"
  else
    echo "  FAIL verify-adc.sh has bash syntax errors"
    fail=$((fail+1))
  fi

  # set -eu (and NOT pipefail)
  if grep -qE '^set +-eu' "$SCRIPT"; then
    echo "  OK   verify-adc.sh uses 'set -eu'"
  else
    echo "  FAIL verify-adc.sh does not use 'set -eu'"
    fail=$((fail+1))
  fi
  if grep -qE '^[[:space:]]*set +-o +pipefail|^[[:space:]]*set +-[a-z]*o +pipefail|^[[:space:]]*set +-[a-z]*e[a-z]*u[a-z]*o +pipefail' "$SCRIPT"; then
    echo "  FAIL verify-adc.sh enables pipefail (should NOT; SIGPIPE risk)"
    fail=$((fail+1))
  else
    echo "  OK   verify-adc.sh does not enable pipefail"
  fi

  # Explicit comment about SIGPIPE / pipefail (self-documenting).
  if grep -qiE 'SIGPIPE|pipefail' "$SCRIPT"; then
    echo "  OK   verify-adc.sh documents the pipefail/SIGPIPE rationale"
  else
    echo "  FAIL verify-adc.sh does not document the pipefail/SIGPIPE rationale"
    fail=$((fail+1))
  fi

  # Tolerates missing gcloud.
  if grep -qE 'command +-v +gcloud' "$SCRIPT"; then
    echo "  OK   verify-adc.sh tolerates missing gcloud"
  else
    echo "  FAIL verify-adc.sh does not check for 'command -v gcloud'"
    fail=$((fail+1))
  fi

  # Required read-only commands.
  for cmd in "gcloud auth list" "gcloud config list" "gcloud auth application-default print-access-token"; do
    if grep -qF "$cmd" "$SCRIPT"; then
      echo "  OK   verify-adc.sh invokes '${cmd}'"
    else
      echo "  FAIL verify-adc.sh does not invoke '${cmd}'"
      fail=$((fail+1))
    fi
  done

  # Must mention the impersonation flag (in a comment or echo).
  if grep -qF -- '--impersonate-service-account' "$SCRIPT"; then
    echo "  OK   verify-adc.sh mentions --impersonate-service-account"
  else
    echo "  FAIL verify-adc.sh does not mention --impersonate-service-account"
    fail=$((fail+1))
  fi

  # Must NOT invoke destructive commands.
  destructive_found=0
  for pattern in \
      'gcloud [a-z-]+ create' \
      'gcloud [a-z-]+ delete' \
      'gcloud [a-z-]+ enable' \
      'gcloud [a-z-]+ disable' \
      'add-iam-policy-binding' \
      'remove-iam-policy-binding' \
      'set-iam-policy' \
      'gcloud auth revoke'; do
    if grep -qE "$pattern" "$SCRIPT"; then
      echo "  FAIL verify-adc.sh invokes a destructive pattern: ${pattern}"
      destructive_found=$((destructive_found+1))
    fi
  done
  if [ "$destructive_found" -eq 0 ]; then
    echo "  OK   verify-adc.sh contains no destructive gcloud commands"
  else
    fail=$((fail+destructive_found))
  fi

  # Placeholder consistency: if any my-project-* appears, it should be my-project-123.
  other=$(grep -oE 'my-project-[0-9]+' "$SCRIPT" | sort -u | grep -v '^my-project-123$' | head -n1 || true)
  if [ -n "$other" ]; then
    echo "  FAIL verify-adc.sh uses a non-placeholder projectId: ${other}"
    fail=$((fail+1))
  else
    echo "  OK   verify-adc.sh uses only the placeholder projectId (or none)"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in GCP is NOT verified here. Compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: adc-plan.md + verify-adc.sh pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
