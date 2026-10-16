#!/usr/bin/env bash
# Structural validation for plat-05-02-pre-commit-validate-catalog-info.
# Checks that the student's hook exists, is executable, has a shebang,
# accepts the good fixture, and rejects every bad-* fixture. Also checks
# that install.md documents at least one of the two installation paths.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-05-precommit}"
HOOK="$BASE/validate-catalog-info.sh"
INSTALL="$BASE/install.md"
FIX="$BASE/fixtures"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and populate the hook + fixtures."
  exit 1
fi

# Soft dependency: python3 + pyyaml. SKIP gracefully if missing — the hook
# itself relies on them.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 is not available on PATH."
  echo "      Install python3 >= 3.9 and re-run."
  exit 0
fi
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "SKIP: python3 is available but PyYAML is not installed."
  echo "      Install it with:  pip3 install pyyaml"
  exit 0
fi

# 1. Hook exists.
if [ -f "$HOOK" ]; then
  echo "  OK   validate-catalog-info.sh exists"
else
  echo "  FAIL $HOOK is missing"
  fail=$((fail+1))
fi

# 2. Hook is executable.
if [ -x "$HOOK" ]; then
  echo "  OK   validate-catalog-info.sh is executable"
else
  echo "  FAIL $HOOK is not executable (chmod +x)"
  fail=$((fail+1))
fi

# 3. Hook has a shebang.
if [ -f "$HOOK" ] && head -n1 "$HOOK" | grep -qE '^#!'; then
  echo "  OK   validate-catalog-info.sh has a shebang"
else
  echo "  FAIL $HOOK is missing a shebang on line 1"
  fail=$((fail+1))
fi

# 4. install.md exists and mentions at least one install path.
if [ ! -f "$INSTALL" ]; then
  echo "  FAIL $INSTALL is missing"
  fail=$((fail+1))
elif grep -qE 'pre-commit|\.git/hooks/pre-commit' "$INSTALL"; then
  echo "  OK   install.md mentions pre-commit or .git/hooks/pre-commit"
else
  echo "  FAIL install.md does not mention 'pre-commit' nor '.git/hooks/pre-commit'"
  fail=$((fail+1))
fi

# 5. Fixtures directory and files.
if [ ! -d "$FIX" ]; then
  echo "  FAIL $FIX directory is missing"
  fail=$((fail+1))
fi

for f in good-component.yaml bad-missing-owner.yaml bad-too-few-annotations.yaml \
         bad-broken-yaml.yaml bad-missing-name.yaml; do
  if [ -f "$FIX/$f" ]; then
    echo "  OK   fixture present: $f"
  else
    echo "  FAIL fixture missing: $f"
    fail=$((fail+1))
  fi
done

# If the hook is not usable, stop here — we cannot invoke it.
if [ ! -x "$HOOK" ] || [ ! -d "$FIX" ]; then
  echo
  echo "RESULT: $fail structural check(s) failed. Fix setup before behavior tests."
  exit 1
fi

echo
echo "== Behavior tests =="

# 6. Hook accepts good fixture (exit 0).
if "$HOOK" "$FIX/good-component.yaml" >/dev/null 2>&1; then
  echo "  OK   hook accepts good-component.yaml (exit 0)"
else
  echo "  FAIL hook rejected good-component.yaml (should accept)"
  fail=$((fail+1))
fi

# 7. Hook rejects every bad-* fixture individually (exit != 0).
for f in bad-missing-owner.yaml bad-too-few-annotations.yaml \
         bad-broken-yaml.yaml bad-missing-name.yaml; do
  if [ -f "$FIX/$f" ]; then
    if "$HOOK" "$FIX/$f" >/dev/null 2>&1; then
      echo "  FAIL hook accepted $f (should reject)"
      fail=$((fail+1))
    else
      echo "  OK   hook rejects $f"
    fi
  fi
done

# 8. Hook rejects the mixed batch (good + bads together).
mixed=("$FIX/good-component.yaml" "$FIX/bad-missing-owner.yaml")
if "$HOOK" "${mixed[@]}" >/dev/null 2>&1; then
  echo "  FAIL hook accepted a mixed batch containing a bad fixture (should reject)"
  fail=$((fail+1))
else
  echo "  OK   hook rejects a mixed batch (good + bad)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara tu hook con solution/REFERENCE.md para autoevaluarte."
exit 0
