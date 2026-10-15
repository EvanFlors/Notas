#!/usr/bin/env bash
# Reference solution for gha-13-02-detect-script-injection.
set -euo pipefail

BASE="${1:-/tmp/sec-scanning}"
PROJECT="$BASE/project"
if [ ! -d "$PROJECT" ]; then
  echo "FAIL: $PROJECT not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

cat > "$PROJECT/.github/workflows/triage.yml" <<'YAML'
# triage.yml — HARDENED. All attacker-controlled values flow via env vars
# and are referenced with "$VAR" (double-quoted). No ${{ github.* }} inside run:.
name: triage

on:
  issues:
    types: [opened]
  pull_request_target:
    types: [opened]

# Minimum top-level perms; each job escalates what it needs.
permissions: {}

jobs:
  triage-issue:
    if: github.event_name == 'issues'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Log issue
        env:
          ISSUE_TITLE: ${{ github.event.issue.title }}
          ACTOR: ${{ github.actor }}
        run: |
          echo "New issue: $ISSUE_TITLE"
          echo "By: $ACTOR"

      - name: Mirror to webhook
        env:
          ISSUE_BODY: ${{ github.event.issue.body }}
        run: |
          # The value of $ISSUE_BODY is NEVER parsed by the shell as code,
          # only as a string argument to tr.
          printf '%s' "$ISSUE_BODY" | tr -d '\n'

  triage-pr:
    if: github.event_name == 'pull_request_target'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Comment on PR
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          HEAD_REF: ${{ github.head_ref }}
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          gh pr comment "$PR_NUMBER" \
            --body "Thanks for PR from branch \"$HEAD_REF\": \"$PR_TITLE\""
YAML

echo "Solution written to $PROJECT/.github/workflows/triage.yml"
