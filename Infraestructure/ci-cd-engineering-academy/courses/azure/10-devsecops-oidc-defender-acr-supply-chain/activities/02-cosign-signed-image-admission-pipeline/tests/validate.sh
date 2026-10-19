#!/usr/bin/env bash
# Structural validation for az-10-02-cosign-signed-image-admission-pipeline.
# Checks that the GitHub Actions workflow signs with cosign keyless (no
# secrets), that at least one admission policy (Kyverno or Ratify) exists
# and pins certificate-identity to the concrete workflow + the GHA OIDC
# issuer, and that README-INTENT.md has the required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run cosign, kubectl or talk to any cluster. Semantic correctness
# must be compared against solution/.

set -eu

BASE="${1:-/tmp/az-10-02}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: base directory $BASE does not exist. Student must create it."
  exit 1
fi

# --- Workflow ------------------------------------------------------------
WF="$BASE/.github/workflows/build-sign-push.yml"
if [ ! -f "$WF" ]; then
  echo "  FAIL $WF does not exist"
  fail=$((fail+1))
else
  echo "  OK   workflow $WF exists"

  if grep -qE 'id-token:[[:space:]]*write' "$WF"; then
    echo "  OK   workflow declares permissions.id-token: write"
  else
    echo "  FAIL workflow missing 'id-token: write' permission"
    fail=$((fail+1))
  fi
  if grep -qE 'uses:[[:space:]]*azure/login@' "$WF"; then
    echo "  OK   workflow uses azure/login@"
  else
    echo "  FAIL workflow does not use azure/login@..."
    fail=$((fail+1))
  fi
  if grep -qE 'uses:[[:space:]]*sigstore/cosign-installer@' "$WF"; then
    echo "  OK   workflow installs cosign (sigstore/cosign-installer@...)"
  else
    echo "  FAIL workflow missing sigstore/cosign-installer@..."
    fail=$((fail+1))
  fi
  if grep -qE 'cosign +sign' "$WF"; then
    echo "  OK   workflow runs 'cosign sign'"
  else
    echo "  FAIL workflow does not run 'cosign sign ...'"
    fail=$((fail+1))
  fi
  # Must push the image somehow
  if grep -qE 'docker/build-push-action@|az +acr +build|docker +push' "$WF"; then
    echo "  OK   workflow builds and pushes the image"
  else
    echo "  FAIL workflow does not build/push the image (docker/build-push-action, az acr build, or docker push)"
    fail=$((fail+1))
  fi
  # No forbidden secrets
  if grep -qE 'client-secret|AZURE_CREDENTIALS|password:' "$WF"; then
    echo "  FAIL workflow contains forbidden fields (client-secret / AZURE_CREDENTIALS / password:)"
    fail=$((fail+1))
  else
    echo "  OK   workflow has no client-secret / AZURE_CREDENTIALS / password:"
  fi
fi

# --- Admission policy (Kyverno OR Ratify) --------------------------------
KYV="$BASE/admission/kyverno-verify-signature.yaml"
RAT="$BASE/admission/ratify-verifier-cosign.yaml"
have_policy=0

if [ -f "$KYV" ]; then
  echo "  OK   Kyverno policy $KYV exists"
  have_policy=1
  if grep -qE '^apiVersion:[[:space:]]*kyverno\.io' "$KYV"; then
    echo "  OK   Kyverno policy declares apiVersion: kyverno.io/..."
  else
    echo "  FAIL Kyverno policy missing apiVersion: kyverno.io/..."
    fail=$((fail+1))
  fi
  if grep -qE '^kind:[[:space:]]*ClusterPolicy' "$KYV"; then
    echo "  OK   Kyverno policy is kind: ClusterPolicy"
  else
    echo "  FAIL Kyverno policy must be kind: ClusterPolicy"
    fail=$((fail+1))
  fi
  if grep -qE 'validationFailureAction:[[:space:]]*Enforce' "$KYV"; then
    echo "  OK   Kyverno policy uses validationFailureAction: Enforce"
  else
    echo "  FAIL Kyverno policy must use validationFailureAction: Enforce (not Audit)"
    fail=$((fail+1))
  fi
  if grep -qE 'verifyImages' "$KYV" && grep -qE 'keyless' "$KYV"; then
    echo "  OK   Kyverno policy declares verifyImages + keyless attestor"
  else
    echo "  FAIL Kyverno policy must declare verifyImages: with a keyless attestor"
    fail=$((fail+1))
  fi
  if grep -qF '.github/workflows/build-sign-push.yml@refs/heads/main' "$KYV"; then
    echo "  OK   Kyverno policy pins subject to concrete workflow@main"
  else
    echo "  FAIL Kyverno policy must pin subject to '.github/workflows/build-sign-push.yml@refs/heads/main'"
    fail=$((fail+1))
  fi
  if grep -qF 'https://token.actions.githubusercontent.com' "$KYV"; then
    echo "  OK   Kyverno policy pins issuer to GitHub Actions OIDC"
  else
    echo "  FAIL Kyverno policy must pin issuer to https://token.actions.githubusercontent.com"
    fail=$((fail+1))
  fi
fi

if [ -f "$RAT" ]; then
  echo "  OK   Ratify verifier $RAT exists"
  have_policy=1
  if grep -qE '^apiVersion:[[:space:]]*config\.ratify\.deislabs\.io' "$RAT"; then
    echo "  OK   Ratify declares apiVersion: config.ratify.deislabs.io/..."
  else
    echo "  FAIL Ratify missing apiVersion: config.ratify.deislabs.io/..."
    fail=$((fail+1))
  fi
  if grep -qE '^kind:[[:space:]]*Verifier' "$RAT"; then
    echo "  OK   Ratify is kind: Verifier"
  else
    echo "  FAIL Ratify must be kind: Verifier"
    fail=$((fail+1))
  fi
  if grep -qF 'certificate-identity' "$RAT" && grep -qF '.github/workflows/build-sign-push.yml@refs/heads/main' "$RAT"; then
    echo "  OK   Ratify pins certificate-identity to concrete workflow@main"
  else
    echo "  FAIL Ratify must set certificate-identity ending with '.github/workflows/build-sign-push.yml@refs/heads/main'"
    fail=$((fail+1))
  fi
  if grep -qF 'certificate-oidc-issuer' "$RAT" && grep -qF 'https://token.actions.githubusercontent.com' "$RAT"; then
    echo "  OK   Ratify pins certificate-oidc-issuer to GHA OIDC"
  else
    echo "  FAIL Ratify must set certificate-oidc-issuer: https://token.actions.githubusercontent.com"
    fail=$((fail+1))
  fi
fi

if [ "$have_policy" -eq 0 ]; then
  echo "  FAIL no admission policy found. Expected Kyverno at admission/kyverno-verify-signature.yaml OR Ratify at admission/ratify-verifier-cosign.yaml"
  fail=$((fail+1))
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if [ ! -f "$DOC" ]; then
  echo "  FAIL $DOC does not exist"
  fail=$((fail+1))
else
  echo "  OK   $DOC exists"
  for section in "Pipeline de firma" "Policy de admission" "Excepciones"; do
    if grep -qiE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  for tok in "cosign" "keyless" "Rekor|rekor" "Enforce" "ACR|Container +Registry" "AKS"; do
    label="${tok%%|*}"
    if grep -qE "$tok" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${label}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${label}'"
      fail=$((fail+1))
    fi
  done
fi

# --- Forbidden filename: ANALYSIS.md ------------------------------------
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE/ANALYSIS.md exists; use README-INTENT.md instead (ANALYSIS.md is reserved)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/.)"
  exit 1
fi
echo "OK: pipeline y admission policy pasan validacion estructural."
exit 0
