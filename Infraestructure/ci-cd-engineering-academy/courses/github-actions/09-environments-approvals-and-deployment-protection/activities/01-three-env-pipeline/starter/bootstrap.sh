#!/usr/bin/env bash
# Bootstrap for gha-09-01-three-env-pipeline.
#
# Creates a scratch dir with:
#   .github/workflows/cd.yaml      — PLACEHOLDER (student must replace)
#   environment-dev.yaml           — PLACEHOLDER
#   environment-staging.yaml       — PLACEHOLDER
#   environment-prod.yaml          — PLACEHOLDER
#
# MODE=live only verifies gh auth; it does not create any resources.
set -euo pipefail

BASE="${1:-/tmp/gha09-three-env}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows"

cat > "$BASE/.github/workflows/cd.yaml" <<'EOF'
# PLACEHOLDER — replace this file.
# Required shape:
#   - on: push to main
#   - permissions: contents: read, deployments: write
#   - 3 jobs named dev, staging, prod
#   - staging needs dev; prod needs staging
#   - each job declares environment: with the matching name
name: cd-PLACEHOLDER
on:
  workflow_dispatch:
jobs:
  placeholder:
    runs-on: ubuntu-latest
    steps:
      - run: echo "replace me"
EOF

cat > "$BASE/environment-dev.yaml" <<'EOF'
# PLACEHOLDER environment sidecar.
# Required fields: name, wait_timer, reviewers (list), deployment_branch_policy.
name: PLACEHOLDER
wait_timer: 0
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

cat > "$BASE/environment-staging.yaml" <<'EOF'
# PLACEHOLDER environment sidecar.
name: PLACEHOLDER
wait_timer: 0
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

cat > "$BASE/environment-prod.yaml" <<'EOF'
# PLACEHOLDER environment sidecar.
# Required for prod: wait_timer >= 5, at least 1 reviewer, prevent_self_review: true,
# deployment_branch_policy.custom_branch_policies: true with patterns: [refs/heads/main].
name: PLACEHOLDER
wait_timer: 0
prevent_self_review: false
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

echo "Scratch created at: $BASE"
echo
echo "Files to edit:"
echo "  $BASE/.github/workflows/cd.yaml"
echo "  $BASE/environment-dev.yaml"
echo "  $BASE/environment-staging.yaml"
echo "  $BASE/environment-prod.yaml"
echo

if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "WARN: MODE=live but 'gh' CLI not installed. Install from https://cli.github.com/" >&2
  elif ! gh auth status >/dev/null 2>&1; then
    echo "WARN: MODE=live but 'gh' not authenticated. Run: gh auth login" >&2
  else
    echo "gh auth OK."
    echo "Export GH_OWNER and GH_REPO before running the validator in MODE=live."
  fi
fi
