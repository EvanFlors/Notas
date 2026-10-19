#!/usr/bin/env bash
# Structural + behavioural validation for ans-06-01-encrypt-sensitive-vars.
# Checks the vault files exist, the headers are correct, encrypt_string
# produced a !vault block in all.yml, the right password decrypts prod.yml,
# the wrong one does NOT, and README-INTENT.md documents the layout.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic quality of README-INTENT.md — compare with
# solution/REFERENCE.md manually.

set -eu

BASE="${1:-/tmp/ans-06-vault}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v ansible-vault >/dev/null 2>&1; then
  # Try the common macOS pip --user path.
  if [ -x "$HOME/Library/Python/3.10/bin/ansible-vault" ]; then
    export PATH="$HOME/Library/Python/3.10/bin:$PATH"
  else
    echo "FAIL: 'ansible-vault' is required but not installed."
    exit 2
  fi
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

# --- password files ------------------------------------------------------
DEVP="$BASE/.vault/dev_pass"
PRODP="$BASE/.vault/prod_pass"
check_file_exists "$DEVP" || true
check_file_exists "$PRODP" || true

# --- group_vars/prod.yml encrypted with vault id 'prod' ------------------
PROD="$BASE/group_vars/prod.yml"
if check_file_exists "$PROD"; then
  if head -1 "$PROD" | grep -q '^\$ANSIBLE_VAULT'; then
    echo "  OK   $PROD has \$ANSIBLE_VAULT header"
  else
    echo "  FAIL $PROD missing \$ANSIBLE_VAULT header"
    fail=$((fail+1))
  fi
  if head -1 "$PROD" | grep -q ';prod$'; then
    echo "  OK   $PROD header carries vault label 'prod'"
  else
    echo "  FAIL $PROD header does not carry vault label 'prod' (encrypt with --vault-id prod@...)"
    fail=$((fail+1))
  fi

  if [ -f "$PRODP" ]; then
    if ansible-vault view --vault-id "prod@$PRODP" "$PROD" >/dev/null 2>&1; then
      echo "  OK   prod password decrypts $PROD"
    else
      echo "  FAIL prod password does NOT decrypt $PROD"
      fail=$((fail+1))
    fi
  fi

  if [ -f "$DEVP" ]; then
    if ansible-vault view --vault-id "dev@$DEVP" "$PROD" >/dev/null 2>&1; then
      echo "  FAIL dev password unexpectedly decrypts $PROD (prod must be isolated)"
      fail=$((fail+1))
    else
      echo "  OK   dev password correctly fails to decrypt $PROD"
    fi
  fi
fi

# --- group_vars/all.yml with !vault block from encrypt_string ------------
ALL="$BASE/group_vars/all.yml"
if check_file_exists "$ALL"; then
  if grep -q '!vault' "$ALL"; then
    echo "  OK   $ALL contains at least one '!vault' block (encrypt_string)"
  else
    echo "  FAIL $ALL has no '!vault' block (missing encrypt_string output)"
    fail=$((fail+1))
  fi
  if grep -q '^app_name:' "$ALL"; then
    echo "  OK   $ALL keeps plaintext keys (app_name present)"
  else
    echo "  FAIL $ALL missing plaintext key app_name"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "Vault layout" "dev vault" "prod vault" "Rotation plan"; do
    if grep -qE "^#+ +${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  for token in "group_vars/prod.yml" "group_vars/all.yml" "fake"; do
    if grep -qi "$token" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${token}'"
    else
      echo "  FAIL README-INTENT.md does not mention '${token}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'rekey|rotation|rotar' "$DOC"; then
    echo "  OK   README-INTENT.md mentions rekey/rotation"
  else
    echo "  FAIL README-INTENT.md does not mention rekey/rotation"
    fail=$((fail+1))
  fi
fi

# --- no obvious real secret leakage --------------------------------------
# This is a lab: every secret value must contain the string 'fake'.
# Scan plaintext files only; encrypted ones are opaque to grep.
leaks=0
if [ -f "$ALL" ]; then
  # Look for suspicious lines like `password: realvalue` where realvalue
  # does not look like a fake placeholder and is not an encrypted block.
  while IFS= read -r line; do
    # skip !vault blocks and indented hex lines
    case "$line" in
      *"!vault"*) continue ;;
      "          "*) continue ;;
    esac
    if printf '%s\n' "$line" | grep -qiE '^(.*(password|token|secret|apikey)[^:]*):[[:space:]]*[A-Za-z0-9]'; then
      if ! printf '%s\n' "$line" | grep -qi 'fake'; then
        echo "  FAIL possible real secret in $ALL: ${line}"
        leaks=$((leaks+1))
      fi
    fi
  done < "$ALL"
fi
if [ "$leaks" -eq 0 ]; then
  echo "  OK   no plaintext real-secret pattern detected in all.yml"
else
  fail=$((fail+leaks))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic quality is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
