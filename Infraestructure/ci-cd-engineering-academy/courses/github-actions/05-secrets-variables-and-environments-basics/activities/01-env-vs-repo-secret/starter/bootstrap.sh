#!/usr/bin/env bash
# Bootstrap for gha-05-01-env-vs-repo-secret.
#
# Creates a working directory with a placeholder workflow and a TASK.md.
# MODE=local (default): nothing GitHub-side; everything is YAML + local validation.
# MODE=live: same local scaffold; the student will manually copy YAMLs to a real repo.
set -euo pipefail

BASE="${1:-/tmp/gha-05-env-vs-repo-secret}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"

cat > "$BASE/local/.github/workflows/placeholder.yml" <<'EOF'
# PLACEHOLDER — replace this file with deploy.yml and smoke.yml per the activity.
# Delete this file when done.
name: placeholder
on: { workflow_dispatch: {} }
permissions:
  contents: read
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo "replace me"
EOF

cat > "$BASE/local/TASK.md" <<'EOF'
# Task recap

Create two files under `.github/workflows/`:

1) deploy.yml
   - permissions: contents: read   (top-level)
   - jobs:
       deploy-staging:    environment: staging
       deploy-prod:       environment: production
   - Both jobs expose, via `env:`
       API_URL        = ${{ vars.API_URL }}
       API_TOKEN      = ${{ secrets.API_TOKEN }}
       FEATURE_FLAGS  = ${{ vars.FEATURE_FLAGS }}
       TELEMETRY_URL  = ${{ vars.TELEMETRY_URL }}
   - A `print-config` step echoes each one.

2) smoke.yml
   - permissions: contents: read
   - A single job WITHOUT `environment:` that echoes ${{ vars.TELEMETRY_URL }}.
   - Must NOT reference API_TOKEN.

Then run:
  MODE=local bash tests/validate.sh /tmp/gha-05-env-vs-repo-secret
EOF

echo "== bootstrap OK ($MODE) =="
echo "Working dir: $BASE/local"
echo "Edit .github/workflows/deploy.yml and smoke.yml, delete placeholder.yml, then validate."
