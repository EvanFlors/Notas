#!/usr/bin/env bash
# Scaffolding for gha-13-02-detect-script-injection.
set -euo pipefail

BASE="${1:-/tmp/sec-scanning}"
rm -rf "$BASE"
mkdir -p "$BASE/project/.github/workflows"

# Intentionally vulnerable workflow: three distinct script-injection sinks.
cat > "$BASE/project/.github/workflows/triage.yml" <<'YAML'
# triage.yml — VULNERABLE starter. Fix the three script-injection sinks.
name: triage

on:
  issues:
    types: [opened]
  pull_request_target:
    types: [opened]

permissions: write-all   # also a problem, but focus here is script injection

jobs:
  triage-issue:
    if: github.event_name == 'issues'
    runs-on: ubuntu-latest
    steps:
      # Sink #1: issue title interpolated into echo
      - name: Log issue
        run: |
          echo "New issue: ${{ github.event.issue.title }}"
          echo "By: ${{ github.actor }}"

      # Sink #2: issue body interpolated into a jq / curl pipeline
      - name: Mirror to webhook
        run: |
          BODY='${{ github.event.issue.body }}'
          echo "$BODY" | tr -d '\n'

  triage-pr:
    if: github.event_name == 'pull_request_target'
    runs-on: ubuntu-latest
    steps:
      # Sink #3: PR head ref + title interpolated into gh pr comment
      - name: Comment on PR
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh pr comment ${{ github.event.pull_request.number }} \
            --body "Thanks for PR from branch ${{ github.head_ref }}: ${{ github.event.pull_request.title }}"
YAML

echo "Scaffolding ready at $BASE/project/"
echo "Edit: $BASE/project/.github/workflows/triage.yml"
echo "Validate: bash tests/validate.sh $BASE"
