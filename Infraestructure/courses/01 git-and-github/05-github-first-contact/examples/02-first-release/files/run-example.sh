#!/usr/bin/env bash
# Local simulation of a release workflow (no GitHub required).
# Creates /tmp/release-demo-local/ with a repo, an annotated tag,
# release notes, and a tar.gz "asset" under releases/<tag>/.
set -euo pipefail

DIR="${1:-/tmp/release-demo-local}"
rm -rf "$DIR"
mkdir -p "$DIR"
cd "$DIR"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > README.md <<'EOF'
# release-demo-local

Package used to showcase the release workflow locally.
EOF

cat > hello.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from release-demo-local"
EOF
chmod +x hello.sh

git add .
git commit -q -m "feat: initial release-demo-local package"

# Annotated tag following SemVer with leading v
git tag -a v0.1.0 -m "Release v0.1.0

First release:
- hello.sh script
- README with install hint
"

# Simulate 'release' as a directory with notes + asset
mkdir -p releases/v0.1.0
cat > releases/v0.1.0/NOTES.md <<'EOF'
# v0.1.0 — First release

- hello.sh script
- README with install hint
EOF

tar -czf releases/v0.1.0/release-demo-local-0.1.0.tar.gz \
  --exclude='.git' --exclude='releases' .

echo "== Repo state =="
git log --oneline
echo
echo "== Tags =="
git tag -n
echo
echo "== Simulated release directory =="
ls -lh releases/v0.1.0/
echo
echo "Done. Inspect at $DIR"
