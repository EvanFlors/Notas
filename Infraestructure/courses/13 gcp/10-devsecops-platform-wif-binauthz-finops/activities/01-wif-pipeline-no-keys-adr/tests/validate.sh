#!/usr/bin/env bash
# Structural validation for gcp-10-01-wif-pipeline-no-keys-adr.
#
# Checks TF file (wif.tf), GHA workflow (publish.yml) and ADR
# (ADR-WIF-PIPELINE.md). Does NOT run terraform apply nor talk to GCP.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/gcp-10-01-wif}"
TF="$BASE/terraform/wif.tf"
WF="$BASE/.github/workflows/publish.yml"
ADR="$BASE/ADR-WIF-PIPELINE.md"
fail=0

echo "== Structural validation for $BASE =="

# --- terraform/wif.tf ----------------------------------------------------
if [ ! -f "$TF" ]; then
  echo "  FAIL $TF does not exist"
  fail=$((fail+1))
else
  echo "  OK   $TF exists"

  for res in \
      "google_iam_workload_identity_pool" \
      "google_iam_workload_identity_pool_provider" \
      "google_service_account" \
      "google_service_account_iam_member" \
      "google_artifact_registry_repository_iam_member"; do
    if grep -qE "resource +\"${res}\"" "$TF"; then
      echo "  OK   TF declares resource ${res}"
    else
      echo "  FAIL TF missing resource ${res}"
      fail=$((fail+1))
    fi
  done

  if grep -qE 'issuer_uri[[:space:]]*=[[:space:]]*"https://token\.actions\.githubusercontent\.com"' "$TF"; then
    echo "  OK   TF has GitHub OIDC issuer_uri"
  else
    echo "  FAIL TF missing GitHub OIDC issuer_uri"
    fail=$((fail+1))
  fi

  if grep -q 'attribute_mapping' "$TF" && grep -q 'attribute.repository' "$TF"; then
    echo "  OK   TF has attribute_mapping referencing attribute.repository"
  else
    echo "  FAIL TF missing attribute_mapping with attribute.repository"
    fail=$((fail+1))
  fi

  if grep -q 'attribute_condition' "$TF" && grep -q 'assertion.repository' "$TF"; then
    echo "  OK   TF pins provider via attribute_condition on assertion.repository"
  else
    echo "  FAIL TF does not pin provider via attribute_condition on assertion.repository"
    fail=$((fail+1))
  fi

  if grep -q 'roles/iam.workloadIdentityUser' "$TF"; then
    echo "  OK   TF grants roles/iam.workloadIdentityUser on SA"
  else
    echo "  FAIL TF does not grant roles/iam.workloadIdentityUser"
    fail=$((fail+1))
  fi

  if grep -q 'principalSet://' "$TF"; then
    echo "  OK   TF binding uses principalSet://"
  else
    echo "  FAIL TF binding does not use principalSet://"
    fail=$((fail+1))
  fi

  if grep -q 'roles/artifactregistry.writer' "$TF"; then
    echo "  OK   TF grants roles/artifactregistry.writer (least privilege)"
  else
    echo "  FAIL TF does not grant roles/artifactregistry.writer"
    fail=$((fail+1))
  fi

  # Must NOT create a SA key.
  if grep -qE 'google_service_account_key\b' "$TF"; then
    echo "  FAIL TF declares google_service_account_key (should NOT; WIF eliminates keys)"
    fail=$((fail+1))
  else
    echo "  OK   TF does NOT declare google_service_account_key"
  fi
fi

# --- .github/workflows/publish.yml --------------------------------------
if [ ! -f "$WF" ]; then
  echo "  FAIL $WF does not exist"
  fail=$((fail+1))
else
  echo "  OK   $WF exists"

  if grep -qE '^[[:space:]]*id-token:[[:space:]]*write' "$WF"; then
    echo "  OK   workflow sets id-token: write"
  else
    echo "  FAIL workflow missing id-token: write"
    fail=$((fail+1))
  fi

  if grep -q 'google-github-actions/auth' "$WF"; then
    echo "  OK   workflow uses google-github-actions/auth"
  else
    echo "  FAIL workflow does not use google-github-actions/auth"
    fail=$((fail+1))
  fi

  if grep -q 'workload_identity_provider' "$WF"; then
    echo "  OK   workflow references workload_identity_provider"
  else
    echo "  FAIL workflow missing workload_identity_provider"
    fail=$((fail+1))
  fi

  if grep -q 'service_account' "$WF"; then
    echo "  OK   workflow references service_account"
  else
    echo "  FAIL workflow missing service_account"
    fail=$((fail+1))
  fi

  # Must NOT use a static SA key secret.
  if grep -qiE 'GCP_SA_KEY|GOOGLE_CREDENTIALS|credentials_json' "$WF"; then
    echo "  FAIL workflow references a static SA key secret (GCP_SA_KEY / GOOGLE_CREDENTIALS / credentials_json)"
    fail=$((fail+1))
  else
    echo "  OK   workflow does NOT reference a static SA key"
  fi

  if grep -q 'docker.pkg.dev' "$WF"; then
    echo "  OK   workflow targets Artifact Registry (*.docker.pkg.dev)"
  else
    echo "  FAIL workflow does not target *.docker.pkg.dev"
    fail=$((fail+1))
  fi
fi

# --- ADR -----------------------------------------------------------------
if [ ! -f "$ADR" ]; then
  echo "  FAIL $ADR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $ADR exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR has 'ADR' heading"
  else
    echo "  FAIL ADR missing 'ADR' heading"
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

  if grep -qiE 'Workload +Identity +Federation|\\bWIF\\b' "$ADR"; then
    echo "  OK   ADR mentions Workload Identity Federation / WIF"
  else
    echo "  FAIL ADR does not mention WIF"
    fail=$((fail+1))
  fi

  if grep -qiE 'GitHub +Actions' "$ADR"; then
    echo "  OK   ADR mentions GitHub Actions"
  else
    echo "  FAIL ADR does not mention GitHub Actions"
    fail=$((fail+1))
  fi

  if grep -qiE 'Artifact +Registry' "$ADR"; then
    echo "  OK   ADR mentions Artifact Registry"
  else
    echo "  FAIL ADR does not mention Artifact Registry"
    fail=$((fail+1))
  fi

  if grep -qiE 'attribute_condition|attribute\.repository' "$ADR"; then
    echo "  OK   ADR mentions attribute_condition / attribute.repository (pin)"
  else
    echo "  FAIL ADR does not mention attribute_condition / attribute.repository"
    fail=$((fail+1))
  fi

  if grep -qiE 'no .*key|sin .*key|sin claves est|without .*key|eliminar? .*key' "$ADR"; then
    echo "  OK   ADR mentions explicitly 'no SA keys' / 'sin keys'"
  else
    echo "  FAIL ADR does not explicitly state the no-keys guarantee"
    fail=$((fail+1))
  fi

  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR lists >= 2 alternatives"
  else
    echo "  FAIL ADR lists < 2 alternatives"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness against a real GCP project is NOT verified here.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
