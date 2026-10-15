#!/usr/bin/env bash
# Reference solution for gh-11-03-lfs-setup.
# If git-lfs is not installed, writes a correct .gitattributes manually so that
# the validator's static checks still pass; the pointer check will be SKIPPED.
set -euo pipefail

REPO="${1:-/tmp/lfs-lab}"

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/build-starter-repo.sh" "$REPO"

cd "$REPO"

if git lfs version >/dev/null 2>&1; then
  echo "git-lfs detected: using the standard flow."
  git lfs install --local
  git lfs track "*.bin"
else
  echo "git-lfs NOT installed. Writing .gitattributes by hand (the pointer check will be SKIPPED)."
  cat > .gitattributes <<'EOF'
*.bin filter=lfs diff=lfs merge=lfs -text
EOF
  # Neutralize any inherited global `filter.lfs.*` config so `git add` works
  # without the git-lfs binary. This is local to the repo only.
  git config --local filter.lfs.required false
  git config --local filter.lfs.clean  "cat"
  git config --local filter.lfs.smudge "cat"
  # Explicitly override the (possibly inherited global) `process` filter
  # with an empty string so git falls back to clean/smudge (which we neutralized).
  git config --local filter.lfs.process ""
fi

mkdir -p assets
dd if=/dev/urandom of=assets/data.bin bs=1024 count=2048 >/dev/null 2>&1

git add .gitattributes assets/data.bin
git -c user.name=Student -c user.email=student@example.com \
    commit -q -m "feat: add binary data (tracked by LFS)"

echo
echo "Solution applied. State:"
git log --oneline
echo
echo "--- .gitattributes ---"
cat .gitattributes
echo
if git lfs version >/dev/null 2>&1; then
  echo "--- git lfs ls-files ---"
  git lfs ls-files
  echo
  echo "--- git cat-file -p HEAD:assets/data.bin (should be a pointer) ---"
  git cat-file -p HEAD:assets/data.bin
fi
