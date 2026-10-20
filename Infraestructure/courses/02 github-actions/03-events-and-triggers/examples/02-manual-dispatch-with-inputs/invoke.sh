#!/usr/bin/env bash
# How to invoke the manual deploy workflow via gh CLI.
# Requires: gh auth status OK, and workflow.yml committed as .github/workflows/deploy.yml

set -euo pipefail

cat <<'EOF'
# Dispatch with explicit inputs:
gh workflow run deploy.yml \
  -f environment=staging \
  -f tag=v1.2.3 \
  -f dry_run=false

# From a specific ref:
gh workflow run deploy.yml --ref main \
  -f environment=prod \
  -f tag=v1.2.3 \
  -f dry_run=true

# Watch the resulting run:
gh run list --workflow=deploy.yml --limit 1
gh run watch
EOF
