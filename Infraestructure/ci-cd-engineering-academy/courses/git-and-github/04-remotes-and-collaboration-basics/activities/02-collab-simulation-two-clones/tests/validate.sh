#!/usr/bin/env bash
# Validate gh-04-02-collab-simulation-two-clones end state.
#
# NOTE: no `set -o pipefail` deliberately (grep -q piped from git log can
# SIGPIPE git and spuriously fail with pipefail).

BASE="${1:-${BASE_DIR:-/tmp/gh-04-collab}}"
BARE="$BASE/origin.git"
ALICE="$BASE/alice"
BOB="$BASE/bob"

passed=0
failed=0
report=""

ok()   { report+="  OK  — $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL— $1\n"; failed=$((failed+1)); }

if [ ! -d "$BARE" ] || [ ! -d "$ALICE/.git" ] || [ ! -d "$BOB/.git" ]; then
  echo "FAIL: expected $BARE, $ALICE/.git and $BOB/.git."
  echo "Run starter/build-base.sh first, then do the activity."
  exit 1
fi

# 1. All three expected feature commits exist in bare main
has_a1=$(git -C "$BARE" log main --format='%s' | grep -x 'feat(alice): add alice.md' || true)
has_a2=$(git -C "$BARE" log main --format='%s' | grep -x 'feat(alice): add second alice feature' || true)
has_b1=$(git -C "$BARE" log main --format='%s' | grep -x 'feat(bob): add bob.md' || true)

if [ -n "$has_a1" ] && [ -n "$has_a2" ] && [ -n "$has_b1" ]; then
  ok "bare main contains the 3 expected feature commits"
else
  missing=""
  [ -z "$has_a1" ] && missing+=" 'feat(alice): add alice.md'"
  [ -z "$has_a2" ] && missing+=" 'feat(alice): add second alice feature'"
  [ -z "$has_b1" ] && missing+=" 'feat(bob): add bob.md'"
  fail "bare main is missing:$missing"
fi

# 2. bare main has exactly 4 commits (init + 3 features) with lineal history
n_commits=$(git -C "$BARE" rev-list --count main 2>/dev/null || echo 0)
if [ "$n_commits" -eq 4 ]; then
  ok "bare main has exactly 4 commits (init + 3 features)"
else
  fail "bare main has $n_commits commits; expected 4 (init + 3 features). Extra merge commit?"
fi

# 3. No merge commits in bare main (lineal history)
merge_commits=$(git -C "$BARE" log main --pretty='%P' | awk 'NF>1' | wc -l | tr -d ' ')
if [ "$merge_commits" -eq 0 ]; then
  ok "bare main history is linear (no merge commits)"
else
  fail "bare main contains $merge_commits merge commit(s); use rebase, not merge"
fi

# 4. bare has exactly ONE branch (main), no extras pushed by the clones
heads=$(git -C "$BARE" for-each-ref --format='%(refname:short)' refs/heads/)
heads_count=$(printf "%s\n" "$heads" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$heads_count" -eq 1 ] && [ "$heads" = "main" ]; then
  ok "bare has exactly one branch: main"
else
  fail "bare branches are: $(echo $heads); expected only 'main'. Delete extras with 'git push --delete origin <branch>'"
fi

# 5. alice/main == bare/main
alice_tip=$(git -C "$ALICE" rev-parse main 2>/dev/null || echo "A")
bare_tip=$(git -C "$BARE" rev-parse main 2>/dev/null || echo "B")
if [ "$alice_tip" = "$bare_tip" ]; then
  ok "alice/main matches bare/main"
else
  fail "alice/main ($alice_tip) != bare/main ($bare_tip); fetch + ff on alice"
fi

# 6. bob/main == bare/main
bob_tip=$(git -C "$BOB" rev-parse main 2>/dev/null || echo "C")
if [ "$bob_tip" = "$bare_tip" ]; then
  ok "bob/main matches bare/main"
else
  fail "bob/main ($bob_tip) != bare/main ($bare_tip); fetch + ff on bob"
fi

# 7. Both clones' origin/main cache up to date with bare/main
alice_cache=$(git -C "$ALICE" rev-parse origin/main 2>/dev/null || echo "AC")
bob_cache=$(git -C "$BOB" rev-parse origin/main 2>/dev/null || echo "BC")
if [ "$alice_cache" = "$bare_tip" ] && [ "$bob_cache" = "$bare_tip" ]; then
  ok "both clones have origin/main cache in sync with bare"
else
  why=""
  [ "$alice_cache" != "$bare_tip" ] && why+=" alice origin/main=$alice_cache;"
  [ "$bob_cache"   != "$bare_tip" ] && why+=" bob origin/main=$bob_cache;"
  fail "origin/main cache stale in a clone — run 'git fetch origin'. ($why bare=$bare_tip)"
fi

echo "== Validating gh-04-02-collab-simulation-two-clones under $BASE =="
echo
printf "%b" "$report"
echo
echo "RESULT: $passed/7 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
