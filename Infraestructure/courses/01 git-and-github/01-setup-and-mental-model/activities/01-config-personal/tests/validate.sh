#!/usr/bin/env bash
# Validate: minimal sane global Git configuration for gh-01-01-config-personal.
# Exits 0 if OK, 1 otherwise. Prints a precise checklist.

# Deliberately no 'set -u' because we check for empty vars.
set -o pipefail

fail=0
warn=0

check() {
  local label="$1"
  local got="$2"
  local predicate="$3"   # "nonempty" | regex pattern
  local required="$4"    # "req" or "opt"

  if [ "$predicate" = "nonempty" ]; then
    if [ -n "$got" ]; then
      echo "  OK   $label = $got"
    else
      if [ "$required" = "req" ]; then
        echo "  FAIL $label (missing). Set it: git config --global $label \"...\""
        fail=$((fail+1))
      else
        echo "  WARN $label (missing, optional)."
        warn=$((warn+1))
      fi
    fi
  else
    if [[ "$got" =~ $predicate ]]; then
      echo "  OK   $label = $got"
    else
      if [ "$required" = "req" ]; then
        echo "  FAIL $label = '$got' (expected matching: $predicate)"
        fail=$((fail+1))
      else
        echo "  WARN $label = '$got' (expected matching: $predicate, optional)"
        warn=$((warn+1))
      fi
    fi
  fi
}

echo "== Validating ~/.gitconfig =="

if ! command -v git >/dev/null 2>&1; then
  echo "FAIL: git is not installed or not in PATH."
  exit 1
fi

echo "Git version: $(git --version)"
echo

check "user.name"            "$(git config --global --get user.name)"            "nonempty"            req
check "user.email"           "$(git config --global --get user.email)"           ".+@.+\\..+"          req
check "init.defaultBranch"   "$(git config --global --get init.defaultBranch)"   "^(main|trunk)$"      req
check "pull.rebase"          "$(git config --global --get pull.rebase)"          "^(true|false)$"      req
check "push.default"         "$(git config --global --get push.default)"         "^(simple|current)$"  opt
check "push.autoSetupRemote" "$(git config --global --get push.autoSetupRemote)" "^true$"              opt
check "core.autocrlf"        "$(git config --global --get core.autocrlf)"        "^(input|true|false)$" req
check "core.editor"          "$(git config --global --get core.editor)"          "nonempty"            req
check "color.ui"             "$(git config --global --get color.ui)"             "^(auto|true)$"       opt
check "rebase.autoStash"     "$(git config --global --get rebase.autoStash)"     "^true$"              opt
check "credential.helper"    "$(git config --global --get credential.helper)"    "nonempty"            req

# Red flag: credential.helper == 'store' (plain text on disk)
helper="$(git config --global --get credential.helper || true)"
if [ "$helper" = "store" ]; then
  echo
  echo "WARN: credential.helper = 'store' saves tokens in plain text at ~/.git-credentials."
  echo "      Prefer: osxkeychain (macOS), libsecret (Linux w/ GNOME), manager (Windows),"
  echo "      or 'cache --timeout=3600' as a fallback."
  warn=$((warn+1))
fi

# Email red flag: literal 'you@example.com' or empty
if [ "$(git config --global --get user.email || true)" = "you@example.com" ]; then
  echo "FAIL: user.email is a placeholder. Replace with your real email."
  fail=$((fail+1))
fi

# Verify init.defaultBranch actually works
tmp=$(mktemp -d)
git init -q "$tmp"
head=$(cat "$tmp/.git/HEAD")
rm -rf "$tmp"
if [[ "$head" =~ refs/heads/(main|trunk) ]]; then
  echo "  OK   effective default branch on new repos: $head"
else
  echo "  FAIL effective default branch on new repos: $head (expected main)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail required check(s) failed, $warn warning(s)."
  exit 1
fi
echo "OK: configuración mínima correcta ($warn warning(s), no required failures)."
exit 0
