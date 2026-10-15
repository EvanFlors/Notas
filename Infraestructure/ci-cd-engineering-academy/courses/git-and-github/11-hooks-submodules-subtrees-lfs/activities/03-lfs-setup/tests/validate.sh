#!/usr/bin/env bash
# Validate gh-11-03-lfs-setup.
# Required (always):
#   - Repo exists.
#   - .gitattributes committed with: *.bin filter=lfs diff=lfs merge=lfs -text
#   - assets/data.bin committed.
# Pointer check:
#   - If git-lfs is installed: HEAD:assets/data.bin must START with
#     "version https://git-lfs.github.com/spec/v1" (= LFS pointer).
#     AND `git lfs ls-files` must list assets/data.bin.
#   - If git-lfs is NOT installed: pointer-related checks are SKIPPED with a clear note;
#     validator exits 0 if the static checks pass.
#
# No `pipefail` on the whole script to avoid SIGPIPE on `git ... | grep -q`.

REPO="${1:-${REPO_DIR:-/tmp/lfs-lab}}"
fail=0
skipped=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Build it with starter/build-starter-repo.sh"
  exit 1
fi

cd "$REPO"

# -----------------------------------------------------------
# 1) .gitattributes committed and tracks *.bin via LFS
# -----------------------------------------------------------
if git ls-tree HEAD -- .gitattributes 2>/dev/null | grep -q "blob"; then
  echo "  OK   .gitattributes is tracked (committed)"
else
  echo "  FAIL .gitattributes is not committed"
  fail=$((fail+1))
fi

attr_line=$(git show HEAD:.gitattributes 2>/dev/null | grep -E '^\*\.bin[[:space:]]+' || true)
if [ -n "$attr_line" ]; then
  if echo "$attr_line" | grep -q "filter=lfs" && \
     echo "$attr_line" | grep -q "diff=lfs" && \
     echo "$attr_line" | grep -q "merge=lfs" && \
     echo "$attr_line" | grep -q -- "-text"; then
    echo "  OK   .gitattributes has: $attr_line"
  else
    echo "  FAIL .gitattributes line for *.bin is incomplete: $attr_line"
    echo "       expected: '*.bin filter=lfs diff=lfs merge=lfs -text'"
    fail=$((fail+1))
  fi
else
  echo "  FAIL .gitattributes has no line starting with '*.bin '"
  fail=$((fail+1))
fi

# -----------------------------------------------------------
# 2) assets/data.bin committed
# -----------------------------------------------------------
if git ls-tree -r HEAD -- assets/data.bin 2>/dev/null | grep -q "blob"; then
  echo "  OK   assets/data.bin is tracked"
else
  echo "  FAIL assets/data.bin is not committed"
  fail=$((fail+1))
fi

# -----------------------------------------------------------
# 3) Pointer check (requires git-lfs)
# -----------------------------------------------------------
if git lfs version >/dev/null 2>&1; then
  blob=$(git cat-file -p HEAD:assets/data.bin 2>/dev/null | head -c 200)
  if printf "%s" "$blob" | head -n1 | grep -q "git-lfs.github.com/spec/v1"; then
    echo "  OK   HEAD:assets/data.bin is an LFS pointer"
  else
    echo "  FAIL HEAD:assets/data.bin is NOT an LFS pointer. First bytes:"
    printf "%s\n" "$blob" | head -n3 | sed 's/^/       /'
    echo "       Hint: did you run 'git lfs install' BEFORE committing the binary?"
    fail=$((fail+1))
  fi

  if git lfs ls-files 2>/dev/null | awk '{print $NF}' | grep -qx "assets/data.bin"; then
    echo "  OK   'git lfs ls-files' lists assets/data.bin"
  else
    echo "  FAIL 'git lfs ls-files' does not list assets/data.bin"
    fail=$((fail+1))
  fi
else
  echo "  SKIP git-lfs not installed on this host."
  echo "       Pointer check and 'git lfs ls-files' check are SKIPPED."
  echo "       To fully verify, install git-lfs and re-run:"
  echo "         - macOS:  brew install git-lfs"
  echo "         - Debian: sudo apt install git-lfs"
  echo "         - Then:   git lfs install  &&  git lfs migrate import --include='*.bin'"
  skipped=$((skipped+2))
fi

# -----------------------------------------------------------
# 4) At least 2 commits (init + binary)
# -----------------------------------------------------------
n_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
if [ "$n_commits" -ge 2 ]; then
  echo "  OK   $n_commits commits on HEAD (>=2)"
else
  echo "  FAIL only $n_commits commit(s) on HEAD (expected >=2)"
  fail=$((fail+1))
fi

# -----------------------------------------------------------
# Report
# -----------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed, $skipped skipped."
  exit 1
fi
if [ "$skipped" -gt 0 ]; then
  echo "OK (partial): required checks passed; $skipped check(s) skipped due to missing git-lfs."
  exit 0
fi
echo "OK: actividad completada correctamente."
exit 0
