#!/usr/bin/env bash
# Reference solution for gh-04-02-collab-simulation-two-clones.
# Produces the exact target end state. Students should NOT run this before trying.
#
# Flow:
#   1) Alice pushes alice.md.
#   2) Bob fetches, fast-forwards, then adds bob.md and pushes.
#   3) Alice (without fetching!) adds a second alice feature and pushes
#      -> gets non-fast-forward.
#   4) Alice fetches, rebases, and pushes successfully.
#   5) Bob fetches at the end so its origin/main matches.
#
# Result: lineal history on main with 3 feats + init. No merge commits.
set -euo pipefail

BASE="${1:-/tmp/gh-04-collab}"
ALICE="$BASE/alice"
BOB="$BASE/bob"

if [ ! -d "$BASE/origin.git" ] || [ ! -d "$ALICE/.git" ] || [ ! -d "$BOB/.git" ]; then
  echo "FAIL: expected starter output in $BASE. Run starter/build-base.sh first."
  exit 1
fi

# Prefer rebase on pulls in the clones (defensive)
git -C "$ALICE" config pull.rebase true
git -C "$BOB"   config pull.rebase true

# 1) Alice pushes alice.md
cd "$ALICE"
echo "Alice was here." > alice.md
git add alice.md
git commit -q -m "feat(alice): add alice.md"
git push -q

# 2) Bob fetches, FFs, then pushes bob.md
cd "$BOB"
git fetch -q origin
git merge --ff-only -q origin/main
echo "Bob was here." > bob.md
git add bob.md
git commit -q -m "feat(bob): add bob.md"
git push -q

# 3) Alice (without fetching!) tries second feat, gets rejected
cd "$ALICE"
echo "Alice second feature." >> alice.md
git commit -qam "feat(alice): add second alice feature"
set +e
git push -q 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "Unexpected: Alice's second push succeeded without fetching. Aborting."
  exit 1
fi
echo "Alice got rejected (non-fast-forward) as expected."

# 4) Alice fetches + rebases + pushes
git fetch -q origin
git rebase -q origin/main
git push -q

# 5) Bob fetches to update its origin/main cache
cd "$BOB"
git fetch -q origin
# Bob doesn't need to update main itself (nothing changed in his working tree beyond origin cache),
# but to make 'main' consistent with origin/main (bob did push, then Alice pushed above him),
# bob fast-forwards too:
git merge --ff-only -q origin/main 2>/dev/null || true

# 6) Alice similarly fast-forwards (she just pushed; her main should already match origin/main)
cd "$ALICE"
git fetch -q origin

echo
echo "Solved. Final state:"
echo "  origin.git log:"
git -C "$BASE/origin.git" log --oneline main
echo
echo "  alice log:"
git -C "$ALICE" log --oneline main
echo
echo "  bob log:"
git -C "$BOB" log --oneline main
