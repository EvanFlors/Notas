#!/usr/bin/env bash
# Structural validation for k8s-01-02-architecture-diagram.
# Checks that MAP.md exists and contains the required sections, control-plane
# components, node components, spec/status/reconciliation terminology and
# 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/MAP-reference.md.

BASE="${1:-/tmp/k8s-01-arch}"
MAP="$BASE/MAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$MAP" ]; then
  echo "FAIL: $MAP does not exist. Student must produce it."
  exit 1
fi

# Four required sections (A/B/C/D) — accept several heading styles.
required_sections=(
  "control plane"
  "data plane"
  "reconcil"
  "apply"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$MAP"; then
    echo "  OK   MAP.md mentions section topic: '$s'"
  else
    echo "  FAIL MAP.md missing topic: '$s'"
    fail=$((fail+1))
  fi
done

# 5 control plane components by name.
for comp in kube-apiserver etcd kube-scheduler kube-controller-manager cloud-controller-manager; do
  if grep -qi "$comp" "$MAP"; then
    echo "  OK   mentions control-plane component '$comp'"
  else
    echo "  FAIL does not mention control-plane component '$comp'"
    fail=$((fail+1))
  fi
done

# Node components — require at least 4 of these 5.
node_found=0
for comp in kubelet kube-proxy containerd cni csi; do
  if grep -qi "$comp" "$MAP"; then
    node_found=$((node_found+1))
  fi
done
if [ "$node_found" -ge 4 ]; then
  echo "  OK   MAP.md names at least 4 node components ($node_found of 5)"
else
  echo "  FAIL MAP.md names only $node_found node components (expected >=4)"
  fail=$((fail+1))
fi

# Deployment → ReplicaSet → Pods chain.
for obj in deployment replicaset pod; do
  if grep -qi "$obj" "$MAP"; then
    echo "  OK   mentions workload object '$obj'"
  else
    echo "  FAIL does not mention workload object '$obj'"
    fail=$((fail+1))
  fi
done

# Model-mental keywords.
for kw in "spec" "status" "watch" "reconcil"; do
  if grep -qi "$kw" "$MAP"; then
    echo "  OK   mentions concept '$kw'"
  else
    echo "  FAIL does not mention concept '$kw'"
    fail=$((fail+1))
  fi
done

# Admission / RBAC must appear (for the apply pipeline section).
for kw in "admission" "rbac"; do
  if grep -qi "$kw" "$MAP"; then
    echo "  OK   mentions API-server pipeline concept '$kw'"
  else
    echo "  FAIL does not mention '$kw'"
    fail=$((fail+1))
  fi
done

# 7 numbered answers.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$MAP"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   MAP.md answers at least 7 numbered questions"
else
  echo "  FAIL MAP.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/MAP-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara MAP.md con solution/MAP-reference.md para autoevaluarte."
exit 0
