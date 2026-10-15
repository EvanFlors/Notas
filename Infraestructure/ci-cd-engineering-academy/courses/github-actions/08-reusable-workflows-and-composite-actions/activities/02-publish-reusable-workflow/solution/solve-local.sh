#!/usr/bin/env bash
# Reference solution for gha-08-02-publish-reusable-workflow.
set -euo pipefail

BASE="${1:-/tmp/publish-reusable}"
OWNER_SLUG="${OWNER_SLUG:-my-org/shared-workflows}"
HERE="$(cd "$(dirname "$0")" && pwd)"

OWNER_SLUG="$OWNER_SLUG" bash "$HERE/../starter/bootstrap.sh" "$BASE"

# ---- shared: create reusable workflow + tags ----
cd "$BASE/shared"
mkdir -p .github/workflows
cat > .github/workflows/build-and-publish.yml <<'EOF'
name: Reusable build and publish

on:
  workflow_call:
    inputs:
      image-name:
        description: 'Image name (without tag)'
        required: true
        type: string
      push:
        description: 'Whether to actually push to the registry'
        required: false
        type: boolean
        default: false
    secrets:
      REGISTRY_TOKEN:
        description: 'Registry auth token'
        required: true
    outputs:
      digest:
        description: 'Resulting image digest (sha256:...)'
        value: ${{ jobs.build.outputs.digest }}

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.pub.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - id: pub
        env:
          TOKEN: ${{ secrets.REGISTRY_TOKEN }}
          IMG:   ${{ inputs.image-name }}
          PUSH:  ${{ inputs.push }}
        run: |
          # (demo) compute a stable fake digest for the image
          d="sha256:$(printf '%s:%s' "$IMG" "$GITHUB_SHA" | shasum -a 256 | awk '{print $1}')"
          echo "image=$IMG push=$PUSH digest=$d"
          echo "digest=$d" >> "$GITHUB_OUTPUT"
EOF

git add .github
git commit -q -m "feat: add build-and-publish reusable workflow"
git tag -a v1.0.0 -m "v1.0.0"
git tag -fa v1    -m "latest v1 (1.0.0)"

# ---- client: caller workflow ----
cd "$BASE/client"
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<EOF
name: CI
on: [push]

permissions:
  contents: read
  packages: write

jobs:
  call-publish:
    uses: $OWNER_SLUG/.github/workflows/build-and-publish.yml@v1
    with:
      image-name: ghcr.io/\${{ github.repository }}
      push:       false
    secrets:
      REGISTRY_TOKEN: \${{ secrets.REGISTRY_TOKEN }}

  announce:
    needs: call-publish
    runs-on: ubuntu-latest
    steps:
      - run: echo "Built image digest = \${{ needs.call-publish.outputs.digest }}"
EOF

git add .github
git commit -q -m "ci: adopt shared build-and-publish reusable at v1"

echo
echo "Done. State:"
find "$BASE" -not -path '*/.git/*' | sort | sed "s|$BASE|.|"
echo
echo "Shared tags:"
git --git-dir="$BASE/shared/.git" tag -l
