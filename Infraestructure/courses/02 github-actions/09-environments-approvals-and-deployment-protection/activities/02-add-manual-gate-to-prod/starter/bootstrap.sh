#!/usr/bin/env bash
# Bootstrap for gha-09-02-add-manual-gate-to-prod.
#
# Creates:
#   .github/workflows/release.yaml   — existing workflow (DO NOT MODIFY)
#   environment-prod.yaml            — PLACEHOLDER (student replaces)
#   .starter-hash                    — hash of release.yaml for drift check
set -euo pipefail

BASE="${1:-/tmp/gha09-manual-gate}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows"

cat > "$BASE/.github/workflows/release.yaml" <<'EOF'
# Existing workflow — DO NOT MODIFY in this activity.
# The point of the exercise is that the gate goes on the environment resource,
# NOT in this file. If you edit this file the validator will fail.
name: release
on:
  push:
    branches: [main]
    tags: ['v*']

permissions:
  contents: read
  deployments: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "build"

  deploy-prod:
    needs: [build]
    runs-on: ubuntu-latest
    environment:
      name: prod
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploying to prod from ${{ github.sha }}"
EOF

cat > "$BASE/environment-prod.yaml" <<'EOF'
# PLACEHOLDER — replace me.
# Required: name=prod, wait_timer >= 5, prevent_self_review: true,
# reviewers (>=2 entries, at least one of type Team),
# deployment_branch_policy.custom_branch_policies: true with patterns containing refs/heads/main.
name: PLACEHOLDER
wait_timer: 0
prevent_self_review: false
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

# Hash the pristine workflow for drift detection.
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$BASE/.github/workflows/release.yaml" | awk '{print $1}' > "$BASE/.starter-hash"
else
  # macOS
  shasum -a 256 "$BASE/.github/workflows/release.yaml" | awk '{print $1}' > "$BASE/.starter-hash"
fi

echo "Scratch created at: $BASE"
echo
echo "Files:"
echo "  $BASE/.github/workflows/release.yaml   (DO NOT MODIFY)"
echo "  $BASE/environment-prod.yaml            (edit this)"
echo "  $BASE/.starter-hash                    (used by validator to detect drift)"
echo
echo "Also create: $BASE/DECISION.md with your approvals policy justification (>=10 non-empty lines)."

if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "WARN: MODE=live but 'gh' not installed" >&2
  elif ! gh auth status >/dev/null 2>&1; then
    echo "WARN: MODE=live but 'gh' not authenticated" >&2
  else
    echo "gh auth OK; export GH_OWNER and GH_REPO before running validator in live."
  fi
fi
