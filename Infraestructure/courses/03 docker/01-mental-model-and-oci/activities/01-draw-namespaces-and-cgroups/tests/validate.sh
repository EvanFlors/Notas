#!/usr/bin/env bash
# Structural validation for dkr-01-01-draw-namespaces-and-cgroups.
# Checks that MAP.md exists and contains the required sections, keywords,
# stack components, and 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/MAP-reference.md.

BASE="${1:-/tmp/dkr-01-mental-model}"
MAP="$BASE/MAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$MAP" ]; then
  echo "FAIL: $MAP does not exist. Student must produce it."
  exit 1
fi

# Four required sections (A/B/C/D) — accept headings in several styles.
required_sections=(
  "Namespaces"
  "cgroups"
  "Docker"
  "OCI"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$MAP"; then
    echo "  OK   MAP.md mentions section topic: '$s'"
  else
    echo "  FAIL MAP.md missing topic: '$s'"
    fail=$((fail+1))
  fi
done

# All 7 namespaces by name.
for ns in pid mnt net user uts ipc cgroup; do
  if grep -qiw "$ns" "$MAP"; then
    echo "  OK   mentions namespace '$ns'"
  else
    echo "  FAIL does not mention namespace '$ns'"
    fail=$((fail+1))
  fi
done

# At least 4 cgroup controllers (we require these 4 specifically for calibration).
for cg in cpu memory pids io; do
  if grep -qiw "$cg" "$MAP"; then
    echo "  OK   mentions cgroup controller '$cg'"
  else
    echo "  FAIL does not mention cgroup controller '$cg'"
    fail=$((fail+1))
  fi
done

# Docker -> runc stack components.
for comp in dockerd containerd runc kernel; do
  if grep -qi "$comp" "$MAP"; then
    echo "  OK   mentions stack component '$comp'"
  else
    echo "  FAIL does not mention stack component '$comp'"
    fail=$((fail+1))
  fi
done

# Three OCI specs by name.
for spec in image-spec runtime-spec distribution-spec; do
  if grep -qi "$spec" "$MAP"; then
    echo "  OK   mentions OCI spec '$spec'"
  else
    echo "  FAIL does not mention OCI spec '$spec'"
    fail=$((fail+1))
  fi
done

# Must mention at least one syscall family that runc performs.
if grep -qiE 'clone|unshare|setns|pivot_root' "$MAP"; then
  echo "  OK   mentions a container-creation syscall (clone/unshare/setns/pivot_root)"
else
  echo "  FAIL does not mention clone/unshare/setns/pivot_root"
  fail=$((fail+1))
fi

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
