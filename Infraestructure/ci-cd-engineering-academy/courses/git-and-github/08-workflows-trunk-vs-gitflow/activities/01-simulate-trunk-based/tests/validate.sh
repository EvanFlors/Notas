#!/usr/bin/env bash
# Validate gh-08-01-simulate-trunk-based.
# Note: NO 'set -o pipefail' — some checks use `git log | grep -q` which
# can trigger SIGPIPE (exit 141) spuriously under pipefail.

REPO="${1:-${REPO_DIR:-/tmp/tbd-sim}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Build it first with starter/build-starter.sh"
  exit 1
fi
cd "$REPO"

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ]; then
  echo "  OK   HEAD on main"
else
  echo "  FAIL HEAD on '$branch' (expected main)"
  fail=$((fail+1))
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean"
  git status --short
  fail=$((fail+1))
fi

# No stray feat/* branches
stray=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep '^feat/' || true)
if [ -z "$stray" ]; then
  echo "  OK   no leftover feat/* branches"
else
  echo "  FAIL leftover feat/* branches: $stray"
  fail=$((fail+1))
fi

# Required merge commits present (by subject)
for subj in "merge: feat/new-checkout" "merge: feat/dark-mode"; do
  if git log --format='%s' main | grep -Fxq "$subj"; then
    echo "  OK   merge commit present: '$subj'"
  else
    echo "  FAIL merge commit missing: '$subj'"
    fail=$((fail+1))
  fi
done

# Each merge commit must have 2 parents (true --no-ff merge)
for subj in "merge: feat/new-checkout" "merge: feat/dark-mode"; do
  hash=$(git log main --format='%H %s' | awk -v s="$subj" '$0 ~ s"$"{print $1; exit}')
  if [ -n "$hash" ]; then
    parent_count=$(git rev-list --parents -n 1 "$hash" | awk '{print NF-1}')
    if [ "$parent_count" -ge 2 ]; then
      echo "  OK   '$subj' is a real merge commit (2+ parents)"
    else
      echo "  FAIL '$subj' is NOT a merge commit (parents=$parent_count); use --no-ff"
      fail=$((fail+1))
    fi
  fi
done

# Required feature commits present (reachable from main)
for subj in "feat(checkout): new flow behind flag (off)" "feat(ui): dark mode behind flag (off)"; do
  if git log --format='%s' main | grep -Fxq "$subj"; then
    echo "  OK   feature commit present: '$subj'"
  else
    echo "  FAIL feature commit missing: '$subj'"
    fail=$((fail+1))
  fi
done

# flags.py contains both flags set to False
if [ -f flags.py ]; then
  if grep -Eq '"new_checkout"[[:space:]]*:[[:space:]]*False' flags.py; then
    echo "  OK   flags.py has new_checkout=False"
  else
    echo "  FAIL flags.py missing new_checkout=False"
    fail=$((fail+1))
  fi
  if grep -Eq '"dark_mode"[[:space:]]*:[[:space:]]*False' flags.py; then
    echo "  OK   flags.py has dark_mode=False"
  else
    echo "  FAIL flags.py missing dark_mode=False"
    fail=$((fail+1))
  fi
else
  echo "  FAIL flags.py missing"
  fail=$((fail+1))
fi

# No flag set to True (deploy != release)
if grep -Eq ':[[:space:]]*True' flags.py 2>/dev/null; then
  echo "  FAIL flags.py has a flag set to True (should default to False in main)"
  fail=$((fail+1))
fi

# app.py has gated branches
if [ -f app.py ]; then
  if grep -Fq 'FLAGS.get("new_checkout")' app.py || grep -Fq "FLAGS\['new_checkout'\]" app.py; then
    echo "  OK   app.py gates checkout() on new_checkout flag"
  else
    echo "  FAIL app.py does not gate checkout() on new_checkout flag"
    fail=$((fail+1))
  fi
  if grep -Fq 'FLAGS.get("dark_mode")' app.py || grep -Fq "FLAGS\['dark_mode'\]" app.py; then
    echo "  OK   app.py gates render() on dark_mode flag"
  else
    echo "  FAIL app.py does not gate render() on dark_mode flag"
    fail=$((fail+1))
  fi
else
  echo "  FAIL app.py missing"
  fail=$((fail+1))
fi

# Smoke test still passes
if bash tests/smoke.sh >/dev/null 2>&1; then
  echo "  OK   smoke test passes (main deployable)"
else
  echo "  FAIL smoke test fails — main is NOT deployable"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
