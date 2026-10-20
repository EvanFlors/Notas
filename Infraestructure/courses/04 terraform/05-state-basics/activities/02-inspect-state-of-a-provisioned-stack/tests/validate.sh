#!/usr/bin/env bash
# Structural validation for tf-05-02-inspect-state-of-a-provisioned-stack.
# Verifies that the stack was provisioned AND that NOTES.md has the required
# sections/evidence. Semantic correctness is YOUR responsibility — compare
# against solution/NOTES-reference.md.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks pipe
# into `grep -q`, which can trigger SIGPIPE (exit 141) upstream when the match
# is found early. pipefail would spuriously mark those as failures.

WORK="${1:-${WORK_DIR:-/tmp/tf-05-02-inspect}}"
NOTES="$WORK/NOTES.md"
fail=0

echo "== Validating tf-05-02 at $WORK =="

if [ ! -d "$WORK" ]; then
  echo "FAIL: $WORK does not exist. Copy starter/ there and run through the activity first."
  exit 1
fi

cd "$WORK" || { echo "FAIL: cannot cd into $WORK"; exit 1; }

if ! command -v terraform >/dev/null 2>&1; then
  echo "FAIL: terraform is not installed or not in PATH."
  exit 1
fi

# 1) .terraform must exist (init was run).
if [ -d .terraform ]; then
  echo "  OK   .terraform/ present (init was run)"
else
  echo "  FAIL .terraform/ missing — run 'terraform init'"
  fail=$((fail+1))
fi

# 2) terraform.tfstate must exist (apply was run).
if [ -f terraform.tfstate ]; then
  echo "  OK   terraform.tfstate present (apply was run)"
else
  echo "  FAIL terraform.tfstate missing — run 'terraform apply'"
  fail=$((fail+1))
fi

# 3) Expected resources are in the state.
expected_resources=(
  "random_pet.animal"
  "random_integer.port"
  "random_password.admin"
  "local_file.config"
)
state_list="$(terraform state list 2>/dev/null || true)"
for r in "${expected_resources[@]}"; do
  if printf '%s\n' "$state_list" | grep -qx "$r"; then
    echo "  OK   state contains $r"
  else
    echo "  FAIL state does not contain $r"
    fail=$((fail+1))
  fi
done

# 4) NOTES.md must exist.
if [ ! -f "$NOTES" ]; then
  echo "FAIL: $NOTES does not exist. Fill in NOTES.template.md and save as NOTES.md."
  exit 1
fi
echo "  OK   NOTES.md present"

# 5) NOTES.md must contain the 7 required sections (numbered or titled).
required_section_markers=(
  "Inventario del state"
  "random_pet.animal"
  "random_password.admin"
  "local_file.config"
  "sensitive"
  "lineage"
  "serial"
)
for s in "${required_section_markers[@]}"; do
  if grep -qi -- "$s" "$NOTES"; then
    echo "  OK   NOTES.md mentions '$s'"
  else
    echo "  FAIL NOTES.md does not mention '$s'"
    fail=$((fail+1))
  fi
done

# 6) NOTES.md must contain at least one 64-char hex hash (SHA-256).
if grep -Eq '[0-9a-f]{64}' "$NOTES"; then
  echo "  OK   NOTES.md includes a 64-char hex hash (likely content_sha256)"
else
  echo "  FAIL NOTES.md does not include a 64-char hex hash"
  fail=$((fail+1))
fi

# 7) NOTES.md must answer at least 7 numbered sections.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\." "$NOTES"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   NOTES.md appears to answer >=7 numbered sections"
else
  echo "  FAIL NOTES.md only has $answers_found numbered sections (expected >=7)"
  fail=$((fail+1))
fi

# 8) NOTES.md should include at least one UUID (lineage).
if grep -Eq '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$NOTES"; then
  echo "  OK   NOTES.md includes a UUID (likely the state lineage)"
else
  echo "  FAIL NOTES.md does not include a UUID (expected the state 'lineage')"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/NOTES-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara NOTES.md con solution/NOTES-reference.md para autoevaluarte."
exit 0
