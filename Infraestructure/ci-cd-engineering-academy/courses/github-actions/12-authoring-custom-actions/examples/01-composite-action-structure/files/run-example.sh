#!/usr/bin/env bash
# Builds a scratch directory with a minimal composite action and simulates
# the runner expanding its single step. Shows the shape of a valid action.yml
# and how outputs reach the caller via $GITHUB_OUTPUT.
set -euo pipefail

DEMO="${1:-/tmp/composite-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO/greet-action"
cd "$DEMO/greet-action"

cat > action.yml <<'EOF'
name: "Greet (composite)"
description: "Prints a greeting; emits it as an output"
inputs:
  who:
    description: "Target name"
    required: false
    default: "world"
  shout:
    description: "If true, uppercase the greeting"
    required: false
    default: "false"
outputs:
  greeting:
    description: "The emitted greeting"
    value: ${{ steps.emit.outputs.greeting }}
runs:
  using: composite
  steps:
    - id: emit
      shell: bash
      env:
        WHO: ${{ inputs.who }}
        SHOUT: ${{ inputs.shout }}
      run: |
        g="Hello, ${WHO}!"
        if [ "$SHOUT" = "true" ]; then
          g="$(echo "$g" | tr '[:lower:]' '[:upper:]')"
        fi
        echo "$g"
        echo "greeting=$g" >> "$GITHUB_OUTPUT"
EOF

echo "== action.yml written =="
cat action.yml
echo

# Validate structure with python/yaml
python3 - <<'PY'
import sys, yaml, pathlib
data = yaml.safe_load(pathlib.Path("action.yml").read_text())
assert data["runs"]["using"] == "composite", "runs.using must be composite"
assert "steps" in data["runs"], "composite must have runs.steps"
assert "greeting" in data.get("outputs", {}), "missing outputs.greeting"
print("action.yml structure OK")
PY

# Simulate the runner expanding the step
echo
echo "== Simulating runner expansion =="
export GITHUB_OUTPUT="$DEMO/github_output"
: > "$GITHUB_OUTPUT"

WHO="mundo" SHOUT="true" bash -c '
  g="Hello, ${WHO}!"
  if [ "$SHOUT" = "true" ]; then
    g="$(echo "$g" | tr "[:lower:]" "[:upper:]")"
  fi
  echo "$g"
  echo "greeting=$g" >> "$GITHUB_OUTPUT"
'

echo
echo "Contents of \$GITHUB_OUTPUT (what the caller consumes):"
cat "$GITHUB_OUTPUT"
echo
echo "Done. Action at: $DEMO/greet-action"
