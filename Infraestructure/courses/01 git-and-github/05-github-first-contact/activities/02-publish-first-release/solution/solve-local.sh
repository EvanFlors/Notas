#!/usr/bin/env bash
# Reference solution for gh-05-02-publish-first-release in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/publish-first-release}"
TAG="${TAG:-v0.1.0}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cd "$BASE/local"

# Annotated tag
git tag -a "$TAG" -m "Release $TAG

First release:
- hello.sh script
- README
"

# Push the tag to the bare origin
git push -q origin "$TAG"

# Build asset outside the repo (parent dir)
tar -czf "$BASE/$TAG.tar.gz" --exclude='.git' --exclude='releases' -C "$BASE" local

# Simulate the GitHub Release: notes + asset under releases/<tag>/
mkdir -p "$BASE/releases/$TAG"
cat > "$BASE/releases/$TAG/NOTES.md" <<EOF
# $TAG — First release

First public release. See README.

## Highlights
- hello.sh script
- MIT License
EOF
cp "$BASE/$TAG.tar.gz" "$BASE/releases/$TAG/"

echo
echo "== Done. State: =="
git tag -n
echo
echo "Simulated release dir:"
ls -R "$BASE/releases"
echo
echo "Asset:"
ls -lh "$BASE/$TAG.tar.gz"
