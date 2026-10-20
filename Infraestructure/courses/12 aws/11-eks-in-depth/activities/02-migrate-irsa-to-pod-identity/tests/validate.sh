#!/usr/bin/env bash
# Structural validation for aws-11-02-migrate-irsa-to-pod-identity.
#
# Checks that MIGRATION.md + both manifests exist and contain the required
# markers (IRSA vs Pod Identity, trust policies, association, scenarios).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-11-02}"
IRSA="$BASE/manifests/sa-irsa.yaml"
PID="$BASE/manifests/sa-pod-identity.yaml"
DOC="$BASE/docs/MIGRATION.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$IRSA" "$PID" "$DOC"; do
  if [ -f "$f" ]; then
    echo "  OK   exists: ${f#$BASE/}"
  else
    echo "  FAIL missing: ${f#$BASE/}"
    fail=$((fail+1))
  fi
done

# IRSA manifest markers.
if [ -f "$IRSA" ]; then
  for marker in \
      "eks.amazonaws.com/role-arn" \
      "AssumeRoleWithWebIdentity" \
      "oidc" \
      "ServiceAccount" \
      "Deployment"; do
    if grep -qi "$marker" "$IRSA"; then
      echo "  OK   sa-irsa.yaml mentions '$marker'"
    else
      echo "  FAIL sa-irsa.yaml missing '$marker'"
      fail=$((fail+1))
    fi
  done
  if grep -q "123456789012" "$IRSA"; then
    echo "  OK   sa-irsa.yaml uses example account 123456789012"
  else
    echo "  FAIL sa-irsa.yaml should use example account 123456789012"
    fail=$((fail+1))
  fi
fi

# Pod Identity manifest markers.
if [ -f "$PID" ]; then
  for marker in \
      "pods.eks.amazonaws.com" \
      "create-pod-identity-association|aws_eks_pod_identity_association" \
      "ServiceAccount" \
      "Deployment"; do
    if grep -qiE "$marker" "$PID"; then
      echo "  OK   sa-pod-identity.yaml mentions '$marker'"
    else
      echo "  FAIL sa-pod-identity.yaml missing '$marker'"
      fail=$((fail+1))
    fi
  done
  # It should NOT carry an active IRSA annotation (would be contradictory).
  if grep -qE '^[[:space:]]*eks\.amazonaws\.com/role-arn' "$PID"; then
    echo "  FAIL sa-pod-identity.yaml still has an ACTIVE IRSA annotation line"
    fail=$((fail+1))
  else
    echo "  OK   sa-pod-identity.yaml has no active IRSA annotation"
  fi
  if grep -q "123456789012" "$PID"; then
    echo "  OK   sa-pod-identity.yaml uses example account 123456789012"
  else
    echo "  FAIL sa-pod-identity.yaml should use example account 123456789012"
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
      "Escenario C"; do
    if grep -qEi "$section" "$DOC"; then
      echo "  OK   MIGRATION.md has section matching '$section'"
    else
      echo "  FAIL MIGRATION.md missing section matching '$section'"
      fail=$((fail+1))
    fi
  done

  # Comparison table: at least 7 pipe-lines (header + separator + 5 rows minimum,
  # but we asked for >=6 real rows, so look for >=8).
  rows=$(grep -cE '^\|' "$DOC" || true)
  if [ "$rows" -ge 8 ]; then
    echo "  OK   MIGRATION.md comparison table has at least 6 rows ($rows pipe-lines found)"
  else
    echo "  FAIL MIGRATION.md table has only $rows pipe-lines (expected >=8)"
    fail=$((fail+1))
  fi

  # Must mention dual-run, cutover, rollback (plan phases).
  for word in "dual" "cutover|cambio|migr" "rollback|reversi"; do
    if grep -qiE "$word" "$DOC"; then
      echo "  OK   MIGRATION.md mentions phase keyword: $word"
    else
      echo "  FAIL MIGRATION.md missing phase keyword: $word"
      fail=$((fail+1))
    fi
  done

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

  # Must mention ECS or EC2 or cross-platform (the limit discussion).
  if grep -qiE 'ecs|ec2|cross[- ]?platform|fuera de eks'  "$DOC"; then
    echo "  OK   MIGRATION.md discusses the ECS/EC2/cross-platform limit"
  else
    echo "  FAIL MIGRATION.md does not discuss cross-platform limit"
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
