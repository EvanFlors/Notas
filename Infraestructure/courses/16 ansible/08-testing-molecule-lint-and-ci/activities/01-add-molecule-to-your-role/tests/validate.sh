#!/usr/bin/env bash
# Structural validation for ans-08-01-add-molecule-to-your-role.
# Checks that the student added the Molecule scenario, ansible-lint,
# yamllint and requirements with the minimum keys expected.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run `molecule test` against a real Docker daemon; only reports
# if molecule / docker binaries are available (smoke).

set -eu

BASE="${1:-/tmp/ans-08-01}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Copy starter/ into it first."
  exit 1
fi

# --- Required files ------------------------------------------------------
for f in ".ansible-lint" ".yamllint" "requirements.txt" \
         "molecule/default/molecule.yml" \
         "molecule/default/converge.yml" \
         "molecule/default/verify.yml"; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f is missing"
    fail=$((fail+1))
  fi
done

# --- requirements.txt mentions the three key tools -----------------------
REQ="$BASE/requirements.txt"
if [ -f "$REQ" ]; then
  for pkg in "ansible-core" "ansible-lint" "yamllint" "molecule"; do
    if grep -qi "^${pkg}" "$REQ"; then
      echo "  OK   requirements.txt pins ${pkg}"
    else
      echo "  FAIL requirements.txt does not pin ${pkg}"
      fail=$((fail+1))
    fi
  done
fi

# --- .ansible-lint carries a profile -------------------------------------
LINT="$BASE/.ansible-lint"
if [ -f "$LINT" ]; then
  if grep -qE '^profile:[[:space:]]*(min|basic|moderate|safety|shared|production)' "$LINT"; then
    echo "  OK   .ansible-lint declares a profile"
  else
    echo "  FAIL .ansible-lint does not declare a profile (min|basic|moderate|safety|shared|production)"
    fail=$((fail+1))
  fi
fi

# --- .yamllint extends default -------------------------------------------
YL="$BASE/.yamllint"
if [ -f "$YL" ]; then
  if grep -qE '^extends:[[:space:]]*default' "$YL"; then
    echo "  OK   .yamllint extends default"
  else
    echo "  FAIL .yamllint does not 'extends: default'"
    fail=$((fail+1))
  fi
fi

# --- molecule.yml essentials ---------------------------------------------
MOL="$BASE/molecule/default/molecule.yml"
if [ -f "$MOL" ]; then
  if grep -qE '^driver:' "$MOL" && grep -qE '^[[:space:]]+name:[[:space:]]*docker' "$MOL"; then
    echo "  OK   molecule.yml declares driver.name: docker"
  else
    echo "  FAIL molecule.yml does not declare driver.name: docker"
    fail=$((fail+1))
  fi
  if grep -qE '^platforms:' "$MOL"; then
    echo "  OK   molecule.yml declares platforms:"
  else
    echo "  FAIL molecule.yml missing 'platforms:' block"
    fail=$((fail+1))
  fi
  if grep -qE 'image:' "$MOL"; then
    echo "  OK   molecule.yml defines a platform image"
  else
    echo "  FAIL molecule.yml has no 'image:' entry in platforms"
    fail=$((fail+1))
  fi
  if grep -qE '^provisioner:' "$MOL" && grep -qE 'name:[[:space:]]*ansible' "$MOL"; then
    echo "  OK   molecule.yml declares provisioner.name: ansible"
  else
    echo "  FAIL molecule.yml does not declare provisioner.name: ansible"
    fail=$((fail+1))
  fi
  if grep -qE '^verifier:' "$MOL"; then
    echo "  OK   molecule.yml declares a verifier"
  else
    echo "  FAIL molecule.yml does not declare a verifier"
    fail=$((fail+1))
  fi
fi

# --- converge.yml includes the role --------------------------------------
CONV="$BASE/molecule/default/converge.yml"
if [ -f "$CONV" ]; then
  if grep -qE 'include_role|import_role|^[[:space:]]+roles:' "$CONV"; then
    echo "  OK   converge.yml includes a role"
  else
    echo "  FAIL converge.yml does not include/import a role"
    fail=$((fail+1))
  fi
  if grep -qE 'become:[[:space:]]*true' "$CONV"; then
    echo "  OK   converge.yml escalates with become: true"
  else
    echo "  FAIL converge.yml does not escalate (become: true)"
    fail=$((fail+1))
  fi
fi

# --- verify.yml has at least one assert ----------------------------------
VER="$BASE/molecule/default/verify.yml"
if [ -f "$VER" ]; then
  if grep -qE 'ansible\.builtin\.assert|^[[:space:]]+assert:' "$VER"; then
    echo "  OK   verify.yml contains at least one assert task"
  else
    echo "  FAIL verify.yml has no 'assert:' task"
    fail=$((fail+1))
  fi
fi

# --- YAML smoke via python if available ----------------------------------
if command -v python3 >/dev/null 2>&1; then
  for yf in "$MOL" "$CONV" "$VER" "$LINT" "$YL"; do
    [ -f "$yf" ] || continue
    if python3 -c "import sys,yaml; yaml.safe_load_all(open(sys.argv[1]))" "$yf" >/dev/null 2>&1; then
      echo "  OK   YAML parse: $(basename "$yf")"
    else
      # pyyaml may not be installed; try a looser check (just that it's not binary).
      if file "$yf" 2>/dev/null | grep -qi 'text'; then
        echo "  WARN  YAML not parsed (pyyaml missing?) but file is text: $(basename "$yf")"
      else
        echo "  FAIL YAML parse failed: $(basename "$yf")"
        fail=$((fail+1))
      fi
    fi
  done
fi

# --- Smoke: molecule / docker availability (non-fatal) -------------------
echo
echo "== Smoke (optional) =="
if command -v molecule >/dev/null 2>&1; then
  echo "  INFO molecule found: $(molecule --version 2>&1 | head -1)"
else
  echo "  SKIP molecule binary not installed (install with: pip install -r requirements.txt)"
fi
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "  INFO docker daemon reachable; you can run: molecule test"
else
  echo "  SKIP docker daemon not reachable; 'molecule test' will not run end-to-end"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Structural validation passed."
echo "        (If Docker is available, run 'molecule test' from $BASE for end-to-end proof.)"
exit 0
