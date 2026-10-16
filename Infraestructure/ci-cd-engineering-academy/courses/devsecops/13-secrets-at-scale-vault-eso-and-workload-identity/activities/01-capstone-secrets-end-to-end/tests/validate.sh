#!/usr/bin/env bash
# Validate sec-13-01-capstone-secrets-end-to-end.
#
# Checks (SKIP gracefully if required tools are missing):
#  - Required tools present (docker, kind, kubectl, helm, vault, jq)
#  - starter/manifests/*.yaml contain NO literal secret value (sk_test_...)
#  - starter/manifests/*.yaml have no leftover REPLACE_ME placeholders
#  - kind cluster 'sec-13-capstone' exists
#  - Vault container 'sec-13-vault' is running
#  - ESO is installed and Running
#  - ClusterSecretStore 'vault-dev' is Valid
#  - ExternalSecret 'payments-stripe' is SecretSynced
#  - Secret 'payments-stripe' exists and STRIPE_API_KEY equals Vault's current value
#  - Deployment 'payments-app' is Available and exposes STRIPE_API_KEY env var
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# pipe into `grep -q`, which on a match closes the pipe early and causes the
# upstream producer (kubectl, docker, vault) to receive SIGPIPE (exit 141).
# pipefail would mark those as failures.
set -eu

CLUSTER=sec-13-capstone
CTX="kind-$CLUSTER"
HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter"

passed=0
failed=0
skipped=0
report=""

note_pass() { report+="OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="FAIL — $1\n"; failed=$((failed+1)); }
note_skip() { report+="SKIP — $1 ($2)\n"; skipped=$((skipped+1)); }

# ----- 0. Toolchain -----
missing=""
for tool in docker kind kubectl helm vault jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing="$missing $tool"
  fi
done
if [ -n "$missing" ]; then
  echo "SKIP: missing tools:$missing. Nothing to validate."
  echo "This is expected on machines without the full local toolchain."
  exit 0
fi

# ----- 1. Manifests: no literal secret values -----
if grep -rE 'sk_test_[A-Za-z0-9]+' "$STARTER/manifests/" >/dev/null 2>&1; then
  note_fail "manifests contain literal secret value (sk_test_...). The capstone forbids secret values in Git."
else
  note_pass "manifests contain no literal secret values"
fi

# ----- 2. Manifests: no leftover REPLACE_ME placeholders -----
if grep -r 'REPLACE_ME' "$STARTER/manifests/" >/dev/null 2>&1; then
  note_fail "manifests still contain REPLACE_ME placeholders (did you edit them?)"
else
  note_pass "manifests have no REPLACE_ME placeholders"
fi

# ----- 3. Vault container running -----
if docker ps --format '{{.Names}}' | grep -qx 'sec-13-vault'; then
  note_pass "docker container 'sec-13-vault' is running"
else
  note_skip "docker container 'sec-13-vault' not running" "run starter/01-start-vault.sh"
  echo
  printf "%b" "$report"
  echo
  echo "Summary: $passed passed, $failed failed, $skipped skipped."
  [ "$failed" -eq 0 ] && exit 0 || exit 1
fi

# ----- 4. kind cluster -----
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  note_pass "kind cluster '$CLUSTER' exists"
else
  note_skip "kind cluster '$CLUSTER' missing" "run starter/02-create-cluster.sh"
  echo
  printf "%b" "$report"
  echo
  echo "Summary: $passed passed, $failed failed, $skipped skipped."
  [ "$failed" -eq 0 ] && exit 0 || exit 1
fi

# ----- 5. ESO installed -----
if kubectl --context "$CTX" -n external-secrets get deploy external-secrets >/dev/null 2>&1; then
  ready="$(kubectl --context "$CTX" -n external-secrets get deploy external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
  if [ "${ready:-0}" -ge 1 ]; then
    note_pass "ESO deployment is Ready ($ready replica)"
  else
    note_fail "ESO deployment exists but has 0 ready replicas"
  fi
else
  note_skip "ESO not installed" "run starter/03-install-eso.sh"
fi

# ----- 6. ClusterSecretStore -----
if kubectl --context "$CTX" get clustersecretstore vault-dev >/dev/null 2>&1; then
  status="$(kubectl --context "$CTX" get clustersecretstore vault-dev -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo '')"
  if [ "$status" = "True" ]; then
    note_pass "ClusterSecretStore 'vault-dev' is Ready/Valid"
  else
    note_fail "ClusterSecretStore 'vault-dev' is NOT Ready (status='$status'). Check: kubectl describe clustersecretstore vault-dev"
  fi
else
  note_skip "ClusterSecretStore 'vault-dev' missing" "kubectl apply -f starter/manifests/"
fi

# ----- 7. ExternalSecret -----
if kubectl --context "$CTX" -n payments get externalsecret payments-stripe >/dev/null 2>&1; then
  es_status="$(kubectl --context "$CTX" -n payments get externalsecret payments-stripe -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo '')"
  if [ "$es_status" = "True" ]; then
    note_pass "ExternalSecret 'payments-stripe' is SecretSynced"
  else
    note_fail "ExternalSecret 'payments-stripe' is NOT Ready (status='$es_status'). Check: kubectl -n payments describe externalsecret payments-stripe"
  fi
else
  note_skip "ExternalSecret 'payments-stripe' missing" "kubectl apply -f starter/manifests/"
fi

# ----- 8. Secret value matches Vault -----
if kubectl --context "$CTX" -n payments get secret payments-stripe >/dev/null 2>&1; then
  k8s_value="$(kubectl --context "$CTX" -n payments get secret payments-stripe -o jsonpath='{.data.STRIPE_API_KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo '')"
  vault_value="$(VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault kv get -format=json kv/payments/stripe 2>/dev/null | jq -r '.data.data.api_key' 2>/dev/null || echo '')"
  if [ -n "$k8s_value" ] && [ "$k8s_value" = "$vault_value" ]; then
    note_pass "Secret 'payments-stripe' STRIPE_API_KEY matches Vault's current value"
  else
    note_fail "Secret value mismatch — k8s='$k8s_value' vault='$vault_value'"
  fi
else
  note_skip "Secret 'payments-stripe' not materialized yet" "wait refreshInterval or check ESO logs"
fi

# ----- 9. Consumer deployment -----
if kubectl --context "$CTX" -n payments get deployment payments-app >/dev/null 2>&1; then
  avail="$(kubectl --context "$CTX" -n payments get deployment payments-app -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)"
  if [ "${avail:-0}" -ge 1 ]; then
    note_pass "Deployment 'payments-app' has $avail available replica(s)"

    env_val="$(kubectl --context "$CTX" -n payments exec deploy/payments-app -- printenv STRIPE_API_KEY 2>/dev/null || echo '')"
    if [ -n "$env_val" ]; then
      note_pass "Pod payments-app exposes STRIPE_API_KEY env var (length=${#env_val})"
    else
      note_fail "Pod payments-app does NOT expose STRIPE_API_KEY env var"
    fi
  else
    note_fail "Deployment 'payments-app' not Available (availableReplicas=$avail)"
  fi
else
  note_skip "Deployment 'payments-app' missing" "kubectl apply -f starter/manifests/"
fi

echo
printf "%b" "$report"
echo
echo "Summary: $passed passed, $failed failed, $skipped skipped."
[ "$failed" -eq 0 ] && exit 0 || exit 1
