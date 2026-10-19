#!/usr/bin/env bash
# Structural validation for jk-08-02-migration-adr-and-dual-run.
# Checks:
#   - ADR-MIGRATION.md: standard ADR sections + minimum content.
#   - Jenkinsfile: declarative pipeline with 3 stages + withCredentials in publish.
#   - .github/workflows/dual-run.yml: OIDC-based workflow (no static access keys).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md, solution/Jenkinsfile and solution/dual-run.yml.

set -eu

BASE="${1:-/tmp/jk-08-02}"
ADR="$BASE/ADR-MIGRATION.md"
JFILE="$BASE/Jenkinsfile"
GHA="$BASE/.github/workflows/dual-run.yml"
fail=0

echo "== Structural validation for $BASE =="

# -------------------------------------------------------------------------
# ADR-MIGRATION.md
# -------------------------------------------------------------------------
if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   ADR-MIGRATION.md exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR has an 'ADR' heading"
  else
    echo "  FAIL ADR missing an 'ADR' heading"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # At least one fenced code block.
  fences=$(grep -cE '^```' "$ADR")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ADR has at least one fenced code block (${fences} fence lines)"
  else
    echo "  FAIL ADR has only ${fences} code-fence lines (expected >=2)"
    fail=$((fail+1))
  fi

  # Target of migration.
  if grep -qiE 'GitHub +Actions|\bGHA\b|GitLab +CI|Argo +Workflows' "$ADR"; then
    echo "  OK   ADR names a migration target"
  else
    echo "  FAIL ADR does not name a migration target (GHA / GitLab CI / Argo Workflows)"
    fail=$((fail+1))
  fi

  # Classification tokens.
  for t in "migrar" "consolidar" "retirar"; do
    if grep -qi "$t" "$ADR"; then
      echo "  OK   ADR mentions classification token '${t}'"
    else
      echo "  FAIL ADR missing classification token '${t}'"
      fail=$((fail+1))
    fi
  done

  # Dual-run.
  if grep -qiE 'dual[- ]run' "$ADR"; then
    echo "  OK   ADR mentions dual-run"
  else
    echo "  FAIL ADR does not mention dual-run"
    fail=$((fail+1))
  fi

  # OIDC.
  if grep -qi 'OIDC' "$ADR"; then
    echo "  OK   ADR mentions OIDC"
  else
    echo "  FAIL ADR does not mention OIDC"
    fail=$((fail+1))
  fi

  # Retirement of long-lived creds language.
  if grep -qiE 'withCredentials|access +key|long[- ]lived|larga +duraci[oó]n' "$ADR"; then
    echo "  OK   ADR mentions retiring long-lived credentials / withCredentials"
  else
    echo "  FAIL ADR does not mention retiring long-lived credentials"
    fail=$((fail+1))
  fi

  # Shared Libraries and their replacement.
  if grep -qiE 'Shared +Librar' "$ADR"; then
    echo "  OK   ADR mentions Shared Libraries"
  else
    echo "  FAIL ADR does not mention Shared Libraries"
    fail=$((fail+1))
  fi
  if grep -qiE 'reusable +workflow|CI/CD +Component|WorkflowTemplate' "$ADR"; then
    echo "  OK   ADR mentions replacement (reusable workflow / Component / WorkflowTemplate)"
  else
    echo "  FAIL ADR does not mention a Shared Library replacement target"
    fail=$((fail+1))
  fi

  # Archive + compliance/retention.
  if grep -qi 'archiv' "$ADR"; then
    echo "  OK   ADR mentions historical archiving"
  else
    echo "  FAIL ADR does not mention historical archiving"
    fail=$((fail+1))
  fi
  if grep -qiE 'complianc|retenci[oó]n|retention|7 +a[nñ]os|7 +years' "$ADR"; then
    echo "  OK   ADR mentions compliance / retention"
  else
    echo "  FAIL ADR does not mention compliance / retention"
    fail=$((fail+1))
  fi

  # Cutover / rollback.
  if grep -qiE 'corte|cutover|apagad|shutdown|rollback' "$ADR"; then
    echo "  OK   ADR mentions cutover / rollback"
  else
    echo "  FAIL ADR does not mention cutover / rollback criteria"
    fail=$((fail+1))
  fi

  # Phased plan.
  if grep -qiE 'fase|phase' "$ADR"; then
    echo "  OK   ADR mentions phases"
  else
    echo "  FAIL ADR does not mention phases"
    fail=$((fail+1))
  fi

  # Canary pipelines mentioned.
  if grep -qi 'orders-api' "$ADR" && grep -qi 'docs-site' "$ADR"; then
    echo "  OK   ADR mentions both canary pipelines (orders-api, docs-site)"
  else
    echo "  FAIL ADR missing one of the canary pipelines (orders-api, docs-site)"
    fail=$((fail+1))
  fi

  # Alternatives: at least 2 subheadings or numbered items.
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR lists at least 2 alternatives"
  else
    echo "  FAIL ADR lists fewer than 2 alternatives"
    fail=$((fail+1))
  fi
fi

# -------------------------------------------------------------------------
# Jenkinsfile
# -------------------------------------------------------------------------
if [ ! -f "$JFILE" ]; then
  echo "FAIL: $JFILE does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   Jenkinsfile exists"

  if grep -q '^pipeline[[:space:]]*{' "$JFILE"; then
    echo "  OK   Jenkinsfile starts with declarative 'pipeline {'"
  else
    echo "  FAIL Jenkinsfile does not start with 'pipeline {'"
    fail=$((fail+1))
  fi

  if grep -qE '^[[:space:]]*agent[[:space:]]' "$JFILE"; then
    echo "  OK   Jenkinsfile declares an 'agent'"
  else
    echo "  FAIL Jenkinsfile does not declare an 'agent'"
    fail=$((fail+1))
  fi

  if grep -qE '^[[:space:]]*stages[[:space:]]*{' "$JFILE"; then
    echo "  OK   Jenkinsfile has 'stages {' block"
  else
    echo "  FAIL Jenkinsfile missing 'stages {' block"
    fail=$((fail+1))
  fi

  # At least 3 stage(...) declarations.
  st=$(grep -cE "^[[:space:]]*stage\\(" "$JFILE" || true)
  if [ "$st" -ge 3 ]; then
    echo "  OK   Jenkinsfile has at least 3 stages (${st} found)"
  else
    echo "  FAIL Jenkinsfile has only ${st} stages (expected >=3)"
    fail=$((fail+1))
  fi

  # withCredentials pattern — the "old" pattern the migration eliminates.
  if grep -q 'withCredentials' "$JFILE"; then
    echo "  OK   Jenkinsfile uses withCredentials (old pattern to be migrated)"
  else
    echo "  FAIL Jenkinsfile does not use withCredentials (needed to show the before/after)"
    fail=$((fail+1))
  fi

  # Publish destination hint.
  if grep -qiE 's3://|ecr|artifact' "$JFILE"; then
    echo "  OK   Jenkinsfile references publish destination (s3/ecr/artifact)"
  else
    echo "  FAIL Jenkinsfile does not reference a publish destination"
    fail=$((fail+1))
  fi
fi

# -------------------------------------------------------------------------
# .github/workflows/dual-run.yml
# -------------------------------------------------------------------------
if [ ! -f "$GHA" ]; then
  echo "FAIL: $GHA does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   dual-run.yml exists"

  if grep -qE '^name:' "$GHA"; then
    echo "  OK   dual-run.yml has 'name:'"
  else
    echo "  FAIL dual-run.yml missing 'name:'"
    fail=$((fail+1))
  fi

  if grep -qE '^on:' "$GHA"; then
    echo "  OK   dual-run.yml has 'on:' trigger block"
  else
    echo "  FAIL dual-run.yml missing 'on:' trigger block"
    fail=$((fail+1))
  fi

  if grep -qE '^permissions:' "$GHA"; then
    echo "  OK   dual-run.yml declares 'permissions:'"
  else
    echo "  FAIL dual-run.yml missing 'permissions:' block"
    fail=$((fail+1))
  fi

  if grep -qE 'id-token:[[:space:]]*write' "$GHA"; then
    echo "  OK   dual-run.yml requests OIDC (id-token: write)"
  else
    echo "  FAIL dual-run.yml does not request OIDC (id-token: write)"
    fail=$((fail+1))
  fi

  if grep -qE '^jobs:' "$GHA"; then
    echo "  OK   dual-run.yml defines 'jobs:'"
  else
    echo "  FAIL dual-run.yml missing 'jobs:' block"
    fail=$((fail+1))
  fi

  if grep -q 'actions/checkout@' "$GHA"; then
    echo "  OK   dual-run.yml uses actions/checkout"
  else
    echo "  FAIL dual-run.yml does not use actions/checkout"
    fail=$((fail+1))
  fi

  if grep -q 'aws-actions/configure-aws-credentials@' "$GHA"; then
    echo "  OK   dual-run.yml uses aws-actions/configure-aws-credentials"
  else
    echo "  FAIL dual-run.yml does not use aws-actions/configure-aws-credentials"
    fail=$((fail+1))
  fi

  if grep -qE 'role-to-assume:[[:space:]]+arn:aws:iam::.+:role/' "$GHA"; then
    echo "  OK   dual-run.yml declares a role-to-assume ARN"
  else
    echo "  FAIL dual-run.yml does not declare a valid role-to-assume ARN"
    fail=$((fail+1))
  fi

  # OIDC federation: NO static access key inputs.
  if grep -qiE 'aws-access-key-id:|aws-secret-access-key:' "$GHA"; then
    echo "  FAIL dual-run.yml uses static access key inputs (OIDC federation requires removing them)"
    fail=$((fail+1))
  else
    echo "  OK   dual-run.yml does not use static access key inputs"
  fi

  # Three logical phases: install/build, test, publish/deploy.
  phase_hits=0
  for p in "install" "build" "test" "publish" "deploy" "upload"; do
    if grep -qi "$p" "$GHA"; then
      phase_hits=$((phase_hits+1))
    fi
  done
  if [ "$phase_hits" -ge 3 ]; then
    echo "  OK   dual-run.yml covers at least 3 phases (${phase_hits} tokens found)"
  else
    echo "  FAIL dual-run.yml covers only ${phase_hits} phases (expected >=3)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/.)"
  exit 1
fi
echo "OK: ADR + Jenkinsfile + dual-run.yml pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md, solution/Jenkinsfile y solution/dual-run.yml."
exit 0
