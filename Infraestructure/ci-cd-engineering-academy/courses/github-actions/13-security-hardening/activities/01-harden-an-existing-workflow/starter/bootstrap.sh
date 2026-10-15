#!/usr/bin/env bash
# Scaffolding for gha-13-01-harden-an-existing-workflow.
set -euo pipefail

BASE="${1:-/tmp/harden-workflow}"
rm -rf "$BASE"
mkdir -p "$BASE/project/.github/workflows" "$BASE/project/docs/adr" "$BASE/project/src"

cat > "$BASE/project/README.md" <<'MD'
# acme-release-pipeline

Legacy repo. The release workflow has been "working" for months but has
never been audited for security. Your job is to harden it + document.

See `activities/01-harden-an-existing-workflow/README.md` of the module.
MD

# Deliberately insecure workflow. Minimum 5 issues:
#   1) permissions: write-all
#   2) actions pinned to tags, not SHAs
#   3) pull_request_target + checkout of head.sha + script execution
#   4) ${{ github.event.* }} interpolated into run:
#   5) long-lived AWS secrets instead of OIDC
#   (bonus) action from "shady-vendor" of dubious origin
cat > "$BASE/project/.github/workflows/release.yml" <<'YAML'
# release.yml — LEGACY. Audit, harden, document.
name: release

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request_target:
    types: [opened, synchronize]

permissions: write-all

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      # Third-party vendor action, unknown provenance.
      - uses: shady-vendor/scan-everything@master
        with:
          api-key: ${{ secrets.SHADY_API_KEY }}

      - name: Build
        run: |
          pip install -e .
          python -m build
          echo "Built by: ${{ github.actor }} for PR: ${{ github.event.pull_request.title }}"

      - name: Deploy to prod
        run: |
          aws s3 sync ./dist s3://acme-prod-releases/
          aws cloudfront create-invalidation --distribution-id E123 --paths "/*"
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: eu-west-1

      - name: Publish release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*
YAML

cat > "$BASE/project/docs/adr/README.md" <<'MD'
# Architecture Decision Records

Create `0001-ci-security-hardening.md` here (see activity README for format).
MD

echo "Scaffolding ready at $BASE/project/"
echo
echo "Audit:    $BASE/project/.github/workflows/release.yml"
echo "Harden:   same file"
echo "Document: $BASE/project/docs/adr/0001-ci-security-hardening.md"
echo "Validate: bash tests/validate.sh $BASE"
