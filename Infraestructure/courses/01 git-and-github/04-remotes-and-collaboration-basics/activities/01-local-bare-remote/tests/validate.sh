#!/usr/bin/env bash
# Validate gh-04-01-local-bare-remote end state.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because some checks pipe
# `git log` into `grep -q`; SIGPIPE on git side would cause spurious exit=141.

BASE="${1:-${BASE_DIR:-/tmp/gh-04-bare}}"
BARE="$BASE/origin.git"
LOCAL="$BASE/local"

passed=0
failed=0
report=""

ok()   { report+="  OK  — $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL— $1\n"; failed=$((failed+1)); }

if [ ! -d "$BARE" ] || [ ! -d "$LOCAL/.git" ]; then
  echo "FAIL: expected $BARE and $LOCAL/.git to exist."
  echo "Did you run starter/prepare.sh and follow README steps?"
  exit 1
fi

# 1. Bare repo detected
is_bare="$(git -C "$BARE" config --bool core.bare 2>/dev/null || echo "")"
if [ "$is_bare" = "true" ]; then
  ok "origin.git is a bare repository (core.bare=true)"
else
  fail "origin.git must be a bare repo (git init --bare). core.bare='$is_bare'"
fi

# 2. Local repo has 'origin' remote pointing to the bare
origin_url="$(git -C "$LOCAL" config --get remote.origin.url 2>/dev/null || echo "")"
# Accept both $BARE and realpath variants.
if [ -n "$origin_url" ]; then
  # Normalize both ends with realpath when possible
  norm_bare="$(cd "$BARE" && pwd -P 2>/dev/null || echo "$BARE")"
  norm_url="$(cd "$origin_url" 2>/dev/null && pwd -P || echo "$origin_url")"
  if [ "$origin_url" = "$BARE" ] || [ "$norm_url" = "$norm_bare" ]; then
    ok "local has remote 'origin' -> $origin_url"
  else
    fail "remote 'origin' url is '$origin_url'; expected '$BARE' (or realpath equivalent)"
  fi
else
  fail "local has no remote 'origin' configured"
fi

# 3. local/main tracks origin/main
upstream="$(git -C "$LOCAL" rev-parse --abbrev-ref --symbolic-full-name main@{upstream} 2>/dev/null || echo "")"
if [ "$upstream" = "origin/main" ]; then
  ok "local 'main' tracks 'origin/main'"
else
  fail "local 'main' upstream is '$upstream'; expected 'origin/main' (did you push with -u?)"
fi

# 4. bare's main HEAD exists
if git -C "$BARE" show-ref --verify --quiet refs/heads/main; then
  ok "bare has refs/heads/main"
else
  fail "bare has no refs/heads/main (nothing pushed yet?)"
fi

# 5. bare has at least 3 commits in main
if git -C "$BARE" show-ref --verify --quiet refs/heads/main; then
  n_commits="$(git -C "$BARE" rev-list --count main 2>/dev/null || echo 0)"
  if [ "$n_commits" -ge 3 ]; then
    ok "bare main has $n_commits commits (>= 3)"
  else
    fail "bare main has only $n_commits commits (expected >= 3; init + second line + third line)"
  fi
fi

# 6. local main == bare main (same tip)
if git -C "$BARE" show-ref --verify --quiet refs/heads/main; then
  local_tip="$(git -C "$LOCAL" rev-parse main 2>/dev/null || echo "L")"
  bare_tip="$(git -C "$BARE"  rev-parse main 2>/dev/null || echo "B")"
  if [ "$local_tip" = "$bare_tip" ]; then
    ok "local/main and bare/main point to the same commit"
  else
    fail "local/main ($local_tip) != bare/main ($bare_tip); did you fast-forward after fetch?"
  fi
fi

# 7. refs/remotes/origin/main exists locally and == bare main
if [ -s "$LOCAL/.git/refs/remotes/origin/main" ] \
   || git -C "$LOCAL" show-ref --verify --quiet refs/remotes/origin/main \
   || git -C "$LOCAL" rev-parse origin/main >/dev/null 2>&1; then
  cached="$(git -C "$LOCAL" rev-parse origin/main 2>/dev/null || echo "C")"
  bare_tip="$(git -C "$BARE" rev-parse main 2>/dev/null || echo "B")"
  if [ "$cached" = "$bare_tip" ]; then
    ok "refs/remotes/origin/main matches bare main (fetch cache up to date)"
  else
    fail "refs/remotes/origin/main ($cached) != bare main ($bare_tip); run 'git fetch origin'"
  fi
else
  fail "local lacks refs/remotes/origin/main (did you ever fetch/push?)"
fi

echo "== Validating gh-04-01-local-bare-remote under $BASE =="
echo
printf "%b" "$report"
echo
echo "RESULT: $passed/7 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
