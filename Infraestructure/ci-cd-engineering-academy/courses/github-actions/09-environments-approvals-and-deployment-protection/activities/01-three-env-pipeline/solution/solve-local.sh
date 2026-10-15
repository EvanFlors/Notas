#!/usr/bin/env bash
# Reference solution for gha-09-01-three-env-pipeline in MODE=local.
# Runs the full happy path: bootstrap -> write workflow + sidecars -> validate.
set -euo pipefail

BASE="${1:-/tmp/gha09-three-env}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$BASE/.github/workflows/cd.yaml" <<'EOF'
name: cd
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  deployments: write

jobs:
  dev:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to dev"

  staging:
    needs: [dev]
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to staging"

  prod:
    needs: [staging]
    runs-on: ubuntu-latest
    environment:
      name: prod
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to prod"
EOF

cat > "$BASE/environment-dev.yaml" <<'EOF'
name: dev
wait_timer: 0
prevent_self_review: false
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

cat > "$BASE/environment-staging.yaml" <<'EOF'
name: staging
wait_timer: 2
prevent_self_review: false
reviewers: []
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: false
EOF

cat > "$BASE/environment-prod.yaml" <<'EOF'
name: prod
wait_timer: 5
prevent_self_review: true
reviewers:
  - type: Team
    slug: release-managers
  - type: User
    login: on-call-lead
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: true
  patterns:
    - refs/heads/main
EOF

echo
echo "== Solution written to $BASE =="
echo "Running validator (MODE=local):"
echo
bash "$HERE/../tests/validate.sh" "$BASE"
