#!/usr/bin/env bash
# Validate gh-03-02-resolve-nontrivial-conflict.
# Note: no `set -o pipefail` on purpose — `git log | grep -q` can SIGPIPE with
# exit 141 which pipefail would promote to a false failure.

REPO="${1:-${REPO_DIR:-/tmp/nontrivial}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$REPO"

# 1. HEAD on main, clean worktree
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
  echo "  FAIL working tree not clean. git status:"
  git status --short
  fail=$((fail+1))
fi

# 2. Two merge commits reachable from main (one per feature)
merge_count="$(git log main --merges --format='%H' | wc -l | tr -d ' ')"
if [ "$merge_count" -ge 2 ]; then
  echo "  OK   main contains $merge_count merge commit(s) (>=2)"
else
  echo "  FAIL main contains $merge_count merge commit(s), expected >= 2"
  fail=$((fail+1))
fi

# 3. config.yaml must have retries: 3 and cache: true (both features active)
if grep -qx 'retries: 3' config.yaml 2>/dev/null && grep -qx 'cache: true' config.yaml 2>/dev/null; then
  echo "  OK   config.yaml has retries: 3 and cache: true"
else
  echo "  FAIL config.yaml missing one of 'retries: 3' / 'cache: true'. Current content:"
  sed 's/^/     /' config.yaml 2>/dev/null || echo "     (file missing)"
  fail=$((fail+1))
fi

# 4. config.yaml must still have timeout: 30 and log_level: info (not clobbered)
if grep -qx 'timeout: 30' config.yaml 2>/dev/null && grep -qx 'log_level: info' config.yaml 2>/dev/null; then
  echo "  OK   config.yaml preserved timeout and log_level"
else
  echo "  FAIL config.yaml lost 'timeout: 30' or 'log_level: info'"
  fail=$((fail+1))
fi

# 5. app.py must apply BOTH wrappers
has_cache_wrap=0; has_retry_wrap=0
if grep -q 'CachingClient(client)' app.py 2>/dev/null; then has_cache_wrap=1; fi
if grep -q 'RetryingClient(client' app.py 2>/dev/null; then has_retry_wrap=1; fi
if [ "$has_cache_wrap" -eq 1 ] && [ "$has_retry_wrap" -eq 1 ]; then
  echo "  OK   app.py applies both CachingClient and RetryingClient wrappers"
else
  [ "$has_cache_wrap" -eq 0 ] && { echo "  FAIL app.py missing CachingClient wrapper"; fail=$((fail+1)); }
  [ "$has_retry_wrap" -eq 0 ] && { echo "  FAIL app.py missing RetryingClient wrapper"; fail=$((fail+1)); }
fi

# 6. README.md lists both features
has_cache_doc=0; has_retry_doc=0
if grep -q '^- Caching:' README.md 2>/dev/null; then has_cache_doc=1; fi
if grep -q '^- Retries:' README.md 2>/dev/null; then has_retry_doc=1; fi
if [ "$has_cache_doc" -eq 1 ] && [ "$has_retry_doc" -eq 1 ]; then
  echo "  OK   README.md lists both features"
else
  [ "$has_cache_doc" -eq 0 ] && { echo "  FAIL README.md missing '- Caching:' bullet"; fail=$((fail+1)); }
  [ "$has_retry_doc" -eq 0 ] && { echo "  FAIL README.md missing '- Retries:' bullet"; fail=$((fail+1)); }
fi

# 7. No conflict markers anywhere
if git grep -lE '^(<<<<<<<|=======|>>>>>>>)' -- . >/dev/null 2>&1; then
  echo "  FAIL leftover conflict markers found:"
  git grep -lE '^(<<<<<<<|=======|>>>>>>>)' -- . | sed 's/^/     /'
  fail=$((fail+1))
else
  echo "  OK   no conflict markers in tracked files"
fi

# 8. Branches feature/caching and feature/retries still exist
for b in feature/caching feature/retries; do
  if git show-ref --verify --quiet "refs/heads/$b"; then
    echo "  OK   branch '$b' exists"
  else
    echo "  FAIL branch '$b' does not exist"
    fail=$((fail+1))
  fi
done

# 9. docs/graph.txt deliverable
if [ -s docs/graph.txt ]; then
  echo "  OK   docs/graph.txt present (non-empty)"
else
  echo "  FAIL docs/graph.txt missing or empty (run: git log --graph --oneline --all --decorate | tee docs/graph.txt)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
