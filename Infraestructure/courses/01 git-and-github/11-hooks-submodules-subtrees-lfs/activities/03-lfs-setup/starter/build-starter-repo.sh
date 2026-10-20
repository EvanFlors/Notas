#!/usr/bin/env bash
# Starter repo for gh-11-03-lfs-setup: empty-ish repo with just a README.
set -euo pipefail

REPO="${1:-/tmp/lfs-lab}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > README.md <<'EOF'
# lfs-lab
Starter repo to configure Git LFS for *.bin files.

See the activity README for instructions.
EOF
cat > .gitignore <<'EOF'
__pycache__/
.venv/
EOF

git add .
git commit -q -m "init: lfs-lab starter"

echo "Starter built at: $REPO"
echo
echo "Next steps:"
echo "  cd $REPO"
echo "  git lfs install"
echo "  git lfs track \"*.bin\""
echo "  dd if=/dev/urandom of=assets/data.bin bs=1024 count=2048"
echo "  git add .gitattributes assets/data.bin && git commit -m \"feat: add binary\""
echo "  bash tests/validate.sh $REPO"
