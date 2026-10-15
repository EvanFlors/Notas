#!/usr/bin/env bash
# Reference solution for gha-03-02-safe-fork-pr-workflow.

set -euo pipefail

BASE="${1:-/tmp/safe-fork-pr}"
WF="$BASE/workflows"

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$WF/pr-tests.yml" <<'YAML'
name: PR tests

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests and prepare report
        run: |
          mkdir -p out
          echo "all green" > out/report.txt
          echo "${{ github.event.pull_request.number }}" > out/pr_number.txt
      - uses: actions/upload-artifact@v4
        with:
          name: pr-report
          path: out/
YAML

cat > "$WF/pr-report.yml" <<'YAML'
name: PR report

on:
  workflow_run:
    workflows: ['PR tests']
    types: [completed]

permissions:
  contents: read
  pull-requests: write

jobs:
  comment:
    if: github.event.workflow_run.event == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact from source run
        uses: actions/download-artifact@v4
        with:
          name: pr-report
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      - name: Comment on PR
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          CONCLUSION: ${{ github.event.workflow_run.conclusion }}
        run: |
          PR_NUMBER="$(cat pr_number.txt)"
          REPORT="$(cat report.txt)"
          BODY=$(printf 'CI finished with conclusion: **%s**\n\n```\n%s\n```\n' "$CONCLUSION" "$REPORT")
          gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$BODY"
YAML

cat > "$WF/README.md" <<'MD'
# Safe fork PR workflow — reference solution

Two workflows, one responsibility each.

| Workflow | Trigger | Permissions | Secrets available | Runs PR code |
|----------|---------|-------------|-------------------|--------------|
| pr-tests.yml  | `pull_request`   | `contents: read` (default read-only on fork) | NO  | YES (checkout of PR) |
| pr-report.yml | `workflow_run`   | `pull-requests: write` + `contents: read`    | YES | NO (no checkout at all) |

The transfer between workflows happens via an **artifact** (`pr-report`): A
uploads it, B downloads it with `run-id: ${{ github.event.workflow_run.id }}`.
B uses `secrets.GITHUB_TOKEN` only to post a comment; it never executes the
PR's package manager, build system or scripts.

What would go wrong if we merged both into one `pull_request_target` workflow
with `actions/checkout` of `github.event.pull_request.head.sha`:

Anyone who opens a PR could add a `postinstall` script in `package.json`, a
`Makefile`, or any hook invoked during the build — and that script would run
with `secrets.GITHUB_TOKEN` plus any other repo/org/env secrets available to
`pull_request_target`. The secrets would be exfiltrable to any URL in a
single HTTP POST. This is the pattern that caused real incidents in widely
used projects.
MD

echo "Solution written to $WF"
