#!/usr/bin/env bash
# Reference solution for gh-10-01-rescue-after-reset-hard.
# Operates on $BASE created by starter/build-broken-repos.sh.
set -eu
# NOTE: no `pipefail`. We use `git ... | awk '... exit}'` and `git ... | head`,
# both of which cause git to receive SIGPIPE (exit 141) when the consumer exits
# early. With pipefail, that spuriously aborts the solver.

BASE="${1:-/tmp/recover-adv}"

############################################################
# Scenario 1 — reflog + reset
############################################################
cd "$BASE/scenario-1"
# The commit `feat: step 3` is still in HEAD's reflog as the pre-reset tip.
# Find it by subject.
LOST="$(git reflog --format='%H %gs' | awk '/commit: feat: step 3$/{print $1; exit}')"
if [ -z "$LOST" ]; then
  # Fallback: scan all objects for a commit whose subject matches.
  LOST="$(git rev-list --all --reflog --format='%H %s' | awk '/feat: step 3$/{print $2; exit}')"
fi
git switch main >/dev/null 2>&1 || true
git reset --hard "$LOST" >/dev/null
echo "Scenario 1 solved: main → $(git log -1 --format='%s')"

############################################################
# Scenario 2 — reflog of HEAD + branch
############################################################
cd "$BASE/scenario-2"
TIP="$(git reflog --format='%H %gs' | awk '/commit: fix: payments edge case$/{print $1; exit}')"
if [ -z "$TIP" ]; then
  TIP="$(git fsck --no-reflogs --lost-found 2>/dev/null | awk '/^dangling commit/{print $3}' \
    | while read -r sha; do
        if [ "$(git show -s --format='%s' "$sha" 2>/dev/null)" = "fix: payments edge case" ]; then
          echo "$sha"; break
        fi
      done)"
fi
git branch feature/payments "$TIP"
echo "Scenario 2 solved: feature/payments → $(git log -1 --format='%s' feature/payments)"

############################################################
# Scenario 3 — fsck --lost-found + stash apply + commit
############################################################
cd "$BASE/scenario-3"

# Find the dangling stash commit whose subject contains 'wip: critical fix'
# (stash commits have an auto-generated message mentioning the push message).
STASH_SHA=""
while read -r sha; do
  subj="$(git show -s --format='%B' "$sha" 2>/dev/null | head -1 || true)"
  if printf '%s' "$subj" | grep -q 'wip: critical fix'; then
    STASH_SHA="$sha"
    break
  fi
done < <(git fsck --lost-found 2>/dev/null | awk '/^dangling commit/{print $3}')

if [ -z "$STASH_SHA" ]; then
  echo "ERROR: no dangling stash commit found" >&2
  exit 1
fi

git switch main >/dev/null 2>&1
# Apply the stash contents directly from the sha.
git stash apply "$STASH_SHA" >/dev/null
git add app.py
git commit -q -m "rescue: apply recovered CRITICAL_FIX_MARKER"
echo "Scenario 3 solved: main → $(git log -1 --format='%s')"

echo
echo "All 3 scenarios solved."
