#!/usr/bin/env bash
# Structural validation for aws-11-01-provision-eks-and-run-app.
#
# Checks that the 5 deliverables exist and contain the required markers.
# Optionally runs `terraform validate` if terraform is on PATH.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-11-01}"
TF="$BASE/terraform/main.tf"
EK="$BASE/eksctl/cluster.yaml"
APP="$BASE/k8s/app.yaml"
PLAN="$BASE/docs/EKS_PLAN.md"
ADR="$BASE/docs/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$TF" "$EK" "$APP" "$PLAN" "$ADR"; do
  if [ -f "$f" ]; then
    echo "  OK   exists: ${f#$BASE/}"
  else
    echo "  FAIL missing: ${f#$BASE/}"
    fail=$((fail+1))
  fi
done

# Terraform content markers
if [ -f "$TF" ]; then
  for marker in \
      "terraform-aws-modules/eks/aws" \
      "enable_irsa" \
      "cluster_addons" \
      "authentication_mode" \
      "eks_managed_node_groups" \
      "access_entries"; do
    if grep -q "$marker" "$TF"; then
      echo "  OK   main.tf mentions '$marker'"
    else
      echo "  FAIL main.tf missing '$marker'"
      fail=$((fail+1))
    fi
  done

  # Guard against real-looking account ids: must contain 123456789012
  # (the canonical AWS example account) and NOT look like a leaked real one.
  if grep -q "123456789012" "$TF"; then
    echo "  OK   main.tf uses canonical example account 123456789012"
  else
    echo "  FAIL main.tf should use account 123456789012 (example), not a real one"
    fail=$((fail+1))
  fi
fi

# eksctl content markers
if [ -f "$EK" ]; then
  for marker in \
      "kind: ClusterConfig" \
      "managedNodeGroups" \
      "withOIDC" \
      "addons" \
      "authenticationMode"; do
    if grep -q "$marker" "$EK"; then
      echo "  OK   cluster.yaml mentions '$marker'"
    else
      echo "  FAIL cluster.yaml missing '$marker'"
      fail=$((fail+1))
    fi
  done
fi

# K8s manifests
if [ -f "$APP" ]; then
  for kind in "Deployment" "Service" "Ingress"; do
    if grep -qE "^kind: *$kind\b" "$APP"; then
      echo "  OK   app.yaml has kind: $kind"
    else
      echo "  FAIL app.yaml missing kind: $kind"
      fail=$((fail+1))
    fi
  done
fi

# EKS_PLAN.md must mention add-ons and the kind-vs-eks gap.
if [ -f "$PLAN" ]; then
  if grep -qiE 'add[- ]?on' "$PLAN"; then
    echo "  OK   EKS_PLAN.md mentions add-ons"
  else
    echo "  FAIL EKS_PLAN.md missing add-ons section"
    fail=$((fail+1))
  fi
  if grep -qiE 'kind|no prueba|no cubre|limitaci' "$PLAN"; then
    echo "  OK   EKS_PLAN.md mentions kind limitations"
  else
    echo "  FAIL EKS_PLAN.md missing 'what kind does NOT prove' discussion"
    fail=$((fail+1))
  fi
fi

# ADR: at least 3 Decision headings + 3 Rationale sections.
if [ -f "$ADR" ]; then
  dec=$(grep -cEi '^##? *Decision' "$ADR" || true)
  rat=$(grep -cEi 'Rationale' "$ADR" || true)
  if [ "$dec" -ge 3 ]; then
    echo "  OK   ADR.md has at least 3 Decision headings ($dec found)"
  else
    echo "  FAIL ADR.md has $dec Decision headings (expected >=3)"
    fail=$((fail+1))
  fi
  if [ "$rat" -ge 3 ]; then
    echo "  OK   ADR.md has at least 3 Rationale sections ($rat found)"
  else
    echo "  FAIL ADR.md has $rat Rationale sections (expected >=3)"
    fail=$((fail+1))
  fi
  # Decisions must name the keywords of the three required choices.
  for kw in "node" "autoscaler|karpenter|cluster.autoscaler|cas" \
            "access.entries|aws-auth|authentication"; do
    if grep -qiE "$kw" "$ADR"; then
      echo "  OK   ADR.md touches topic: $kw"
    else
      echo "  FAIL ADR.md missing topic: $kw"
      fail=$((fail+1))
    fi
  done
fi

# Optional: run terraform validate if available.
if command -v terraform >/dev/null 2>&1 && [ -f "$TF" ]; then
  echo "  .. terraform detected; running 'terraform init -backend=false && validate'"
  (
    cd "$BASE/terraform"
    terraform init -backend=false -input=false >/tmp/aws-11-01-tf-init.log 2>&1 || true
    if terraform validate >/tmp/aws-11-01-tf-validate.log 2>&1; then
      echo "  OK   terraform validate succeeded"
    else
      echo "  WARN terraform validate failed; see /tmp/aws-11-01-tf-validate.log"
      # warning only — module download may fail in offline sandboxes.
    fi
  )
else
  echo "  .. terraform not in PATH or no main.tf; skipping terraform validate"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara los entregables con solution/REFERENCE.md para autoevaluarte."
exit 0
