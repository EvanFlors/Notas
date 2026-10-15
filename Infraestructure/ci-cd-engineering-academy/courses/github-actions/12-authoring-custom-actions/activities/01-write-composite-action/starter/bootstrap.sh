#!/usr/bin/env bash
# Bootstraps the scratch directory for gha-12-01.
# Writes a skeleton action.yml with PLACEHOLDERs that the student must fill in.
set -euo pipefail

BASE="${1:-/tmp/composite-action-lab}"
rm -rf "$BASE"
mkdir -p "$BASE/semver-check"
cd "$BASE/semver-check"

cat > action.yml <<'EOF'
# PLACEHOLDER composite action — complete per README.md.
#
# You must set:
#   - name, description, author, branding
#   - inputs: version (required), fail-on-invalid (optional, default "false")
#   - outputs: is-valid, major, minor, patch, normalized
#   - runs.using: composite + one bash step with id "check"
#
# IMPORTANT: pass inputs to the shell via `env:` on the step, do NOT interpolate
# ${{ inputs.* }} inside `run:`. That is a security best practice (gha-13).

name: "TODO: name"
description: "TODO: description"
author: "TODO"
branding:
  icon: "check-circle"
  color: "green"

inputs:
  version:
    description: "TODO"
    required: false
  # TODO: declare fail-on-invalid

outputs:
  is-valid:
    description: "TODO"
    # value: ${{ steps.check.outputs.is-valid }}
  # TODO: declare major, minor, patch, normalized

runs:
  using: composite
  steps:
    - id: check
      shell: bash
      # env:
      #   VERSION: ${{ inputs.version }}
      #   FAIL:    ${{ inputs.fail-on-invalid }}
      run: |
        echo "TODO: implement the check and emit all outputs to \$GITHUB_OUTPUT"
EOF

echo "Starter ready at: $BASE/semver-check"
echo "Edit action.yml to complete the TODOs. Then run:"
echo "  bash tests/validate.sh $BASE"
