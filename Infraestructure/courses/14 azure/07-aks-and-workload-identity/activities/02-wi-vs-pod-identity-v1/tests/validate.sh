#!/usr/bin/env bash
# Structural validation for az-07-02-wi-vs-pod-identity-v1.
#
# Checks that MIGRATION.md + both manifests exist and contain the required
# markers (Pod Identity v1 vs Workload Identity, federated credential, scenarios).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-07-02}"
PI1="$BASE/manifests/sa-pod-identity-v1.yaml"
WI="$BASE/manifests/sa-wi.yaml"
DOC="$BASE/docs/MIGRATION.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$PI1" "$WI" "$DOC"; do
  if [ -f "$f" ]; then
    echo "  OK   exists: ${f#$BASE/}"
  else
    echo "  FAIL missing: ${f#$BASE/}"
    fail=$((fail+1))
  fi
done

# Pod Identity v1 manifest markers.
if [ -f "$PI1" ]; then
  for marker in \
      "AzureIdentity" \
      "AzureIdentityBinding" \
      "aadpodidbinding" \
      "aadpodidentity.k8s.io" \
      "ServiceAccount" \
      "Deployment"; do
    if grep -q "$marker" "$PI1"; then
      echo "  OK   sa-pod-identity-v1.yaml mentions '$marker'"
    else
      echo "  FAIL sa-pod-identity-v1.yaml missing '$marker'"
      fail=$((fail+1))
    fi
  done
  if grep -q "33333333-3333-3333-3333-333333333333" "$PI1"; then
    echo "  OK   sa-pod-identity-v1.yaml uses placeholder clientID"
  else
    echo "  FAIL sa-pod-identity-v1.yaml should use placeholder 33333333-3333-3333-3333-333333333333"
    fail=$((fail+1))
  fi
fi

# Workload Identity manifest markers.
if [ -f "$WI" ]; then
  for marker in \
      "azure.workload.identity/client-id" \
      "azure.workload.identity/use" \
      "system:serviceaccount:apps:app" \
      "api://AzureADTokenExchange" \
      "ServiceAccount" \
      "Deployment"; do
    if grep -qF "$marker" "$WI"; then
      echo "  OK   sa-wi.yaml mentions '$marker'"
    else
      echo "  FAIL sa-wi.yaml missing '$marker'"
      fail=$((fail+1))
    fi
  done
  # Must mention the OIDC issuer URL or 'issuer' concept.
  if grep -qiE 'oidc|issuer' "$WI"; then
    echo "  OK   sa-wi.yaml mentions OIDC issuer"
  else
    echo "  FAIL sa-wi.yaml missing OIDC issuer / federated issuer reference"
    fail=$((fail+1))
  fi
  # Must mention Terraform federated identity credential resource.
  if grep -q "azurerm_federated_identity_credential" "$WI"; then
    echo "  OK   sa-wi.yaml references azurerm_federated_identity_credential (Terraform)"
  else
    echo "  FAIL sa-wi.yaml should reference azurerm_federated_identity_credential"
    fail=$((fail+1))
  fi
  # Must NOT carry an ACTIVE aadpodidbinding label (would be contradictory).
  # Comments mentioning it are fine; we reject lines that look like active YAML.
  if grep -qE '^[[:space:]]*aadpodidbinding:' "$WI"; then
    echo "  FAIL sa-wi.yaml still has an ACTIVE aadpodidbinding label line"
    fail=$((fail+1))
  else
    echo "  OK   sa-wi.yaml has no active aadpodidbinding label"
  fi
  if grep -q "33333333-3333-3333-3333-333333333333" "$WI"; then
    echo "  OK   sa-wi.yaml uses placeholder client-id"
  else
    echo "  FAIL sa-wi.yaml should use placeholder client-id 33333333-3333-3333-3333-333333333333"
    fail=$((fail+1))
  fi
fi

# MIGRATION.md required sections and content.
if [ -f "$DOC" ]; then
  for section in \
      "Comparaci[óo]n" \
      "Plan.*(migraci[óo]n|fases)" \
      "Matriz.*(decisi[óo]n|escenario)" \
      "Escenario A" \
      "Escenario B" \
      "Escenario C" \
      "L[íi]mite"; do
    if grep -qEi "$section" "$DOC"; then
      echo "  OK   MIGRATION.md has section matching '$section'"
    else
      echo "  FAIL MIGRATION.md missing section matching '$section'"
      fail=$((fail+1))
    fi
  done

  # Comparison table: at least 9 pipe-lines (header + separator + >=7 rows).
  rows=$(grep -cE '^\|' "$DOC" || true)
  if [ "$rows" -ge 9 ]; then
    echo "  OK   MIGRATION.md comparison table has at least 7 rows ($rows pipe-lines found)"
  else
    echo "  FAIL MIGRATION.md table has only $rows pipe-lines (expected >=9)"
    fail=$((fail+1))
  fi

  # Phase keywords.
  for word in "dual" "cutover|cambio|migr" "rollback|reversi" "cleanup|limpieza"; do
    if grep -qiE "$word" "$DOC"; then
      echo "  OK   MIGRATION.md mentions phase keyword: $word"
    else
      echo "  FAIL MIGRATION.md missing phase keyword: $word"
      fail=$((fail+1))
    fi
  done

  # Must mention both technologies explicitly.
  for word in "Pod Identity|aadpodidentity|AAD Pod" \
              "Workload Identity|workload-identity|workload_identity_enabled"; do
    if grep -qiE "$word" "$DOC"; then
      echo "  OK   MIGRATION.md mentions '$word'"
    else
      echo "  FAIL MIGRATION.md missing '$word'"
      fail=$((fail+1))
    fi
  done

  # Must discuss the cross-platform limit (Container Apps / Functions / VM).
  if grep -qiE 'container *apps|functions?|\bvm\b|fuera de aks|cross[- ]?platform'  "$DOC"; then
    echo "  OK   MIGRATION.md discusses the cross-platform limit"
  else
    echo "  FAIL MIGRATION.md does not discuss cross-platform limit"
    fail=$((fail+1))
  fi

  # Deprecation of Pod Identity v1 must be acknowledged.
  if grep -qiE 'deprec' "$DOC"; then
    echo "  OK   MIGRATION.md mentions deprecation"
  else
    echo "  FAIL MIGRATION.md does not mention deprecation of Pod Identity v1"
    fail=$((fail+1))
  fi

  # 7 numbered questions at the end.
  qs=0
  for n in 1 2 3 4 5 6 7; do
    if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
      qs=$((qs+1))
    fi
  done
  if [ "$qs" -ge 7 ]; then
    echo "  OK   MIGRATION.md has at least 7 numbered items ($qs found)"
  else
    echo "  FAIL MIGRATION.md has $qs numbered items (expected >=7)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara MIGRATION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
