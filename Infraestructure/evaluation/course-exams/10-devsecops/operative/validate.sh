#!/usr/bin/env bash
# Validation script for the DevSecOps certification operative exercise.
# Each check uses `|| fail` so the first failure stops the script and the
# student knows which sub-exercise regressed.

set -euo pipefail

cd "$(dirname "$0")"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

skip_known() {
  # If SKIP.md declares a sub-exercise skipped, surface it but keep going.
  if [[ -f SKIP.md ]] && grep -qE "^- $1:" SKIP.md; then
    echo "SKIP ($1) — declared in SKIP.md"
    return 0
  fi
  return 1
}

echo "== O1: SBOM =="
if ! skip_known O1; then
  [[ -s out/sbom.cdx.json ]] || fail "out/sbom.cdx.json missing or empty"
  jq -e '.bomFormat == "CycloneDX"' out/sbom.cdx.json >/dev/null \
    || fail "sbom.cdx.json is not valid CycloneDX JSON"
  jq -e '.components | length > 0' out/sbom.cdx.json >/dev/null \
    || fail "sbom.cdx.json has no components"
  [[ -s out/sbom-notes.md ]] || fail "out/sbom-notes.md missing"
fi

echo "== O2: Trivy + policy =="
if ! skip_known O2; then
  [[ -s out/trivy.sarif ]] || fail "out/trivy.sarif missing or empty"
  jq -e '.runs[0].tool.driver.name | test("Trivy"; "i")' out/trivy.sarif >/dev/null \
    || fail "trivy.sarif does not look like a Trivy SARIF report"
  [[ -s out/trivy-policy.md ]] || fail "out/trivy-policy.md missing"
  grep -Eiq 'EPSS|KEV' out/trivy-policy.md \
    || fail "trivy-policy.md must cite EPSS and/or KEV"
fi

echo "== O3: Rego + Conftest =="
if ! skip_known O3; then
  [[ -s policy/s3.rego ]] || fail "policy/s3.rego missing"
  [[ -s policy/s3_test.rego ]] || fail "policy/s3_test.rego missing"
  opa test policy || fail "opa test failed"
  conftest test --policy policy fixtures/tfplan.json \
    || fail "conftest reported violations (expected: deny on public bucket, warn on missing Owner tag)"
fi

echo "== O4: Kyverno verifyImages =="
if ! skip_known O4; then
  [[ -s policy/kyverno-verify-images.yaml ]] || fail "policy/kyverno-verify-images.yaml missing"
  grep -q 'kind: ClusterPolicy' policy/kyverno-verify-images.yaml \
    || fail "policy must be a ClusterPolicy"
  grep -q 'verifyImages' policy/kyverno-verify-images.yaml \
    || fail "policy must use verifyImages rule"
  grep -q 'token.actions.githubusercontent.com' policy/kyverno-verify-images.yaml \
    || fail "policy must pin GitHub Actions OIDC issuer"
  grep -q 'subject' policy/kyverno-verify-images.yaml \
    || fail "policy must pin certificate subject (identity)"
fi

echo "== O5: cosign verify reasoning =="
if ! skip_known O5; then
  [[ -s out/cosign-verify.md ]] || fail "out/cosign-verify.md missing"
  grep -q 'certificate-identity' out/cosign-verify.md \
    || fail "cosign-verify.md must discuss --certificate-identity"
  if grep -q 'insecure-ignore-tlog' out/cosign-verify.md \
    && ! grep -Eiq 'justifi|motivo|solo para' out/cosign-verify.md; then
    fail "cosign-verify.md uses --insecure-ignore-tlog without justification"
  fi
fi

echo "ALL OK"
