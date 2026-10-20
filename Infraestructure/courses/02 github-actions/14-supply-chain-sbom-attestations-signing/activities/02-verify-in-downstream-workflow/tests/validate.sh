#!/usr/bin/env bash
# Validator for gha-14-02-verify-in-downstream-workflow.
#
# NOTE: deliberately NOT using `set -o pipefail` — many checks pipe long
# producers into grep -q, which emits SIGPIPE (141) and would be spurious.

BASE="${1:-${BASE_DIR:-/tmp/gha-14-02}}"
VERIFY="$BASE/verify.sh"
WORKFLOW="$BASE/.github/workflows/consume.yml"

pass=0
fail=0
skip=0
report=""

ok()   { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL — $1\n"; fail=$((fail+1)); }
skp()  { report+="  SKIP — $1\n"; skip=$((skip+1)); }

echo "== Validating gha-14-02 under $BASE =="

# --- Base ---
if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE. Run starter/bootstrap.sh first."
  echo; printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
ok "base dir present"

if [ -f "$BASE/image-info.env" ]; then
  ok "image-info.env present"
else
  bad "image-info.env missing (bootstrap did not run or was overwritten)"
fi

# --- verify.sh checks ---
if [ ! -f "$VERIFY" ]; then
  bad "verify.sh missing at $VERIFY"
else
  ok "verify.sh present"

  if [ -x "$VERIFY" ]; then
    ok "verify.sh is executable"
  else
    bad "verify.sh is NOT executable (chmod +x)"
  fi

  # Must reference all 4 expected vars
  for v in IMAGE_REF EXPECTED_REPO EXPECTED_WORKFLOW_REGEX EXPECTED_OIDC_ISSUER; do
    if grep -qF "$v" "$VERIFY"; then
      ok "verify.sh references \$$v"
    else
      bad "verify.sh does not reference \$$v"
    fi
  done

  # Must call cosign verify with BOTH identity-regexp and oidc-issuer flags
  if grep -q "cosign verify" "$VERIFY"; then
    ok "verify.sh invokes 'cosign verify'"
  else
    bad "verify.sh does NOT invoke 'cosign verify'"
  fi

  if grep -q "certificate-identity-regexp" "$VERIFY"; then
    ok "verify.sh uses --certificate-identity-regexp"
  else
    bad "verify.sh does NOT pass --certificate-identity-regexp"
  fi

  if grep -q "certificate-oidc-issuer" "$VERIFY"; then
    ok "verify.sh uses --certificate-oidc-issuer"
  else
    bad "verify.sh does NOT pass --certificate-oidc-issuer"
  fi

  # Must call gh attestation verify with --repo
  if grep -q "gh attestation verify" "$VERIFY"; then
    ok "verify.sh invokes 'gh attestation verify'"
  else
    bad "verify.sh does NOT invoke 'gh attestation verify'"
  fi

  if grep -qE "gh attestation verify[^|]*--repo" "$VERIFY"; then
    ok "verify.sh passes --repo to gh attestation verify"
  else
    bad "verify.sh does NOT pass --repo to gh attestation verify"
  fi

  # Anti-pattern: identity regex hardcoded as laxo (literal .*)
  if grep -qE "certificate-identity-regexp[[:space:]]+['\"]?[.][*]['\"]?" "$VERIFY"; then
    bad "verify.sh uses laxo regex '.*' as --certificate-identity-regexp (anti-pattern)"
  else
    ok "verify.sh does not use laxo identity regex"
  fi

  # Fail-closed semantics: should exit non-zero on missing cosign or gh.
  # Detect `exit 2` (or similar) after a `command -v` or missing-tool branch.
  if grep -qE "command -v cosign|command -v gh" "$VERIFY" && grep -qE "exit (1|2)" "$VERIFY"; then
    ok "verify.sh has fail-closed branch for missing tools"
  else
    skp "fail-closed on missing tools not clearly detected (recomendado)"
  fi
fi

# --- consume.yml checks ---
if [ ! -f "$WORKFLOW" ]; then
  bad "workflow consume.yml missing at $WORKFLOW"
else
  ok "consume.yml present"

  if python3 -c "import yaml,sys; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
    ok "consume.yml is valid YAML"
  else
    bad "consume.yml is NOT valid YAML"
  fi

  # Two jobs: verify + deploy
  if grep -qE "^\s*verify:" "$WORKFLOW" && grep -qE "^\s*deploy:" "$WORKFLOW"; then
    ok "consume.yml defines both 'verify' and 'deploy' jobs"
  else
    bad "consume.yml must define jobs 'verify' and 'deploy'"
  fi

  # deploy must depend on verify
  if grep -qE "needs:\s*(verify|\[\s*verify)" "$WORKFLOW"; then
    ok "deploy depends on verify (needs:)"
  else
    bad "deploy must declare 'needs: verify'"
  fi

  # Must use cosign installer or install cosign
  if grep -q "sigstore/cosign-installer" "$WORKFLOW"; then
    ok "consume.yml installs cosign (sigstore/cosign-installer)"
  else
    bad "consume.yml must use sigstore/cosign-installer"
  fi

  # Must invoke verify.sh
  if grep -q "verify.sh" "$WORKFLOW"; then
    ok "consume.yml invokes verify.sh"
  else
    bad "consume.yml must invoke verify.sh"
  fi

  # Permissions must NOT be write-all; must NOT grant packages:write
  if grep -qE "permissions:\s*write-all" "$WORKFLOW"; then
    bad "consume.yml uses 'permissions: write-all' (too broad)"
  else
    ok "consume.yml does not use write-all"
  fi

  if grep -qE "packages:\s*write" "$WORKFLOW"; then
    bad "consume.yml should not grant 'packages: write' (consumer, no need)"
  else
    ok "consume.yml does not grant unnecessary packages:write"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass OK / $skip SKIP)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
