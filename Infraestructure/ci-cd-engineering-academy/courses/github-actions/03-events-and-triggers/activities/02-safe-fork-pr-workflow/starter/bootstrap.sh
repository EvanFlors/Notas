#!/usr/bin/env bash
# Bootstrap scratch dir for gha-03-02-safe-fork-pr-workflow.

set -euo pipefail

BASE="${1:-/tmp/safe-fork-pr}"
WF="$BASE/workflows"

rm -rf "$BASE"
mkdir -p "$WF"

cat > "$WF/README.md" <<'MD'
# Safe fork PR workflow — your design

Scenario:

- A fork opens a PR. You need to run tests on the PR code AND post a comment
  on the PR with the results. Posting the comment needs secrets.

Design the two-workflow pattern:

- Workflow A: runs the PR code with NO secrets.
- Workflow B: posts the comment WITH secrets, WITHOUT running PR code.

Transfer the result between workflows via an artifact, not via execution.

Then fill this README with:
- Which workflow uses secrets and which does not.
- What the pattern protects against.
- What would go wrong if you merged both into a single `pull_request_target`
  workflow with `actions/checkout: head.sha`.
MD

echo "Bootstrapped $BASE"
echo "Design your workflows in $WF/ (create >=2 .yml files), then run: bash tests/validate.sh"
