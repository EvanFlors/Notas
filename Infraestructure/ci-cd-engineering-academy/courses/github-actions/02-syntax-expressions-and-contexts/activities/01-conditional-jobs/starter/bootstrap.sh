#!/usr/bin/env bash
# Bootstrap for gha-02-01-conditional-jobs.
# Creates /tmp/gha-02-01/local/.github/workflows/conditional.yml with a scaffold
# containing TODO markers. The student completes the file.
set -euo pipefail

BASE="${1:-/tmp/gha-02-01}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"

cat > "$BASE/local/.github/workflows/conditional.yml" <<'EOF'
name: conditional

on:
  push:
    branches: ['**']
  pull_request:
    branches: [main]

# TODO: define a workflow-level env with LOG_LEVEL=info

jobs:
  lint:
    runs-on: ubuntu-latest
    # TODO: define a job-level env that overrides LOG_LEVEL to "debug"
    steps:
      - uses: actions/checkout@v4
      - name: Lint step
        id: check
        # TODO: step-level env override LOG_LEVEL=trace, then echo the level
        run: |
          echo "TODO: echo \"linting at $LOG_LEVEL\""
          exit 0

  test:
    # TODO: declare needs on lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Flaky step
        id: flaky
        # TODO: continue-on-error so the job keeps going
        run: |
          echo "simulating a flaky failure"
          exit 1
      - name: React to flaky outcome
        # TODO: if condition that triggers when steps.flaky.outcome == 'failure'
        run: echo "flaky step failed but we continue"
      - name: On any failure
        # TODO: if condition using failure()
        run: echo "at least one earlier step failed"
      - name: Always cleanup
        # TODO: if condition using always()
        run: echo "cleanup runs regardless"

  deploy:
    # TODO: declare needs on test
    # TODO: if that requires push + ref==main + needs.test.result=='success'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: echo "deploying ${{ github.sha }}"
EOF

if [ "$MODE" = "local" ]; then
  echo "== MODE=local =="
  echo "Workflow scaffold written to: $BASE/local/.github/workflows/conditional.yml"
  echo "Edit it to remove every TODO and satisfy the acceptance criteria."
  echo "Then run: MODE=local bash tests/validate.sh $BASE"
elif [ "$MODE" = "live" ]; then
  echo "== MODE=live =="
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "WARN: gh CLI not installed or not authenticated; live checks will fail." >&2
  fi
  echo "Workflow scaffold written. After editing, copy it into a real repo under"
  echo ".github/workflows/, commit, push, and run with REPO=<owner/repo>:"
  echo "  MODE=live REPO=<owner/repo> bash tests/validate.sh $BASE"
else
  echo "ERROR: unknown MODE='$MODE' (use 'local' or 'live')" >&2
  exit 2
fi
