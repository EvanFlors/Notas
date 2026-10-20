#!/usr/bin/env bash
# Materializes TWO repos (shared + client) for the reusable workflow example.
# Simulates the two-repo scenario locally; no GHA execution.
set -euo pipefail

BASE="${1:-/tmp/reuse-demo}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== Preparing demo at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/shared/.github/workflows"
mkdir -p "$BASE/client/.github/workflows"

cp "$HERE/deploy.yml"    "$BASE/shared/.github/workflows/deploy.yml"
cp "$HERE/caller-ci.yml" "$BASE/client/.github/workflows/ci.yml"

cat > "$BASE/shared/README.md" <<'EOF'
# shared-workflows (demo)

Published reusable workflows for the org.

## Reusables

- `.github/workflows/deploy.yml` — generic deploy, inputs: environment, image-tag, dry-run.

## Versioning

- `vX.Y.Z` immutable per release
- `vX` mobile pointing to the latest SHA of the major
EOF

cat > "$BASE/client/README.md" <<'EOF'
# client-app (demo)

Consumes `my-org/shared-workflows/.github/workflows/deploy.yml@v1`.

In this local demo it uses the relative path form `uses: ./...`.
EOF

echo
echo "Layout:"
find "$BASE" -not -path '*/.git*' | sort | sed "s|$BASE|.|"

echo
echo "To promote this to a real two-repo scenario:"
echo "  1. git init in $BASE/shared/, push to my-org/shared-workflows, tag v1."
echo "  2. In $BASE/client/.github/workflows/ci.yml, replace:"
echo "       uses: ./.github/workflows/deploy.yml"
echo "     with:"
echo "       uses: my-org/shared-workflows/.github/workflows/deploy.yml@v1"
echo "  3. Set a repo secret STAGING_DEPLOY_TOKEN in the client repo."
