#!/usr/bin/env bash
# Bootstraps gha-12-03-publish-and-pin.
#
# MODE=local (default): two bare "remotes" + two working repos in /tmp/.
# MODE=live: creates two real repos in your GitHub account via gh.
set -euo pipefail

BASE="${1:-/tmp/publish-and-pin}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE"

PUB_DIR="$BASE/publisher"
CON_DIR="$BASE/consumer"

# ---------- Publisher working repo: a composite greet-action ----------
mkdir -p "$PUB_DIR"
cd "$PUB_DIR"

git init -q -b main
git config user.name  "Publisher"
git config user.email "publisher@example.com"

cat > action.yml <<'EOF'
name: "Greet (demo)"
description: "Prints a greeting; emits it as output"
author: "demo"
branding:
  icon: "sun"
  color: "yellow"
inputs:
  who:
    description: "Target name"
    required: false
    default: "world"
outputs:
  greeting:
    description: "Emitted greeting"
    value: ${{ steps.emit.outputs.greeting }}
runs:
  using: composite
  steps:
    - id: emit
      shell: bash
      env:
        WHO: ${{ inputs.who }}
      run: |
        g="Hello, ${WHO}!"
        echo "$g"
        echo "greeting=$g" >> "$GITHUB_OUTPUT"
EOF

cat > README.md <<'EOF'
# greet-action (demo)

Minimal composite action for the gha-12-03 lab.
Pin to SHA from consumers: `uses: demo-owner/greet-action@<SHA>  # v1.0.0`.
EOF

git add action.yml README.md
git commit -q -m "feat: greet-action v1.0.0"

# ---------- Consumer working repo with a workflow that must be pinned ----------
mkdir -p "$CON_DIR/.github/workflows"
cd "$CON_DIR"

git init -q -b main
git config user.name  "Consumer"
git config user.email "consumer@example.com"

cat > README.md <<'EOF'
# consumer

Workflow that consumes greet-action — must pin to SHA.
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: ci
on: [push]
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      # Example of a correctly-pinned external action (do NOT change this one):
      - uses: actions/checkout@a81bbbf8298c0fa03ea29cdc473d45769f953675  # v4.2.2
      # TODO: pin the greet-action below.
      #  - Replace PLACEHOLDER_GREET_SHA with the full 40-char SHA of v1.0.0
      #    taken from the publisher repo: `git rev-parse v1.0.0` run in /tmp/publish-and-pin/publisher
      #  - Add a comment with the equivalent version (e.g. '  # v1.0.0')
      - id: greet
        uses: demo-owner/greet-action@PLACEHOLDER_GREET_SHA
        with:
          who: ci
      - run: echo "got ${{ steps.greet.outputs.greeting }}"
EOF

git add README.md .github/workflows/ci.yml
git commit -q -m "chore: scaffold consumer with PLACEHOLDER pin"

# ---------- Mode-specific wiring ----------
if [ "$MODE" = "local" ]; then
  echo "== MODE=local: creating two bare remotes =="
  git init -q --bare "$BASE/publisher.git"
  git init -q --bare "$BASE/consumer.git"

  (cd "$PUB_DIR" && git remote add origin "$BASE/publisher.git")
  (cd "$CON_DIR" && git remote add origin "$BASE/consumer.git")

  echo
  echo "Publisher repo:   $PUB_DIR  → bare: $BASE/publisher.git"
  echo "Consumer repo:    $CON_DIR  → bare: $BASE/consumer.git"
  echo
  echo "Next:"
  echo "  cd $PUB_DIR"
  echo "  git tag -a v1.0.0 -m 'v1.0.0'"
  echo "  git tag -f v1 v1.0.0"
  echo "  git push origin main v1.0.0"
  echo "  git push origin v1 --force"
  echo
  echo "  SHA=\$(git rev-parse v1.0.0)   # paste it as PLACEHOLDER_GREET_SHA"
  echo
  echo "  cd $CON_DIR && edit .github/workflows/ci.yml,  then commit + push"

elif [ "$MODE" = "live" ]; then
  echo "== MODE=live: verifying gh auth =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI not installed." >&2; exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh not authenticated. Run: gh auth login" >&2; exit 2
  fi
  TS="$(date +%s)"
  echo
  echo "Working repos ready. Create the GitHub repos manually and push:"
  echo "  cd $PUB_DIR && gh repo create greet-action-demo-$TS --public --source=. --remote=origin --push"
  echo "  cd $CON_DIR && gh repo create greet-consumer-$TS   --public --source=. --remote=origin --push"
  echo "Then tag + push as in MODE=local, and update the consumer workflow."

else
  echo "ERROR: unknown MODE='$MODE' (use 'local' or 'live')" >&2
  exit 2
fi
