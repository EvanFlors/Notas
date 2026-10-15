#!/usr/bin/env bash
# Reference solution for gha-05-01-env-vs-repo-secret in MODE=local.
# Produces the two expected workflows that the validator will accept.
set -euo pipefail

BASE="${1:-/tmp/gha-05-env-vs-repo-secret}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

WF="$BASE/local/.github/workflows"
rm -f "$WF/placeholder.yml"

cat > "$WF/deploy.yml" <<'EOF'
# deploy.yml — two environments, same keys, GitHub resolves per-env values.
name: deploy

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    env:
      API_URL:        ${{ vars.API_URL }}
      API_TOKEN:      ${{ secrets.API_TOKEN }}
      FEATURE_FLAGS:  ${{ vars.FEATURE_FLAGS }}
      TELEMETRY_URL:  ${{ vars.TELEMETRY_URL }}
    steps:
      - name: print-config
        run: |
          echo "env=staging"
          echo "API_URL=$API_URL"
          echo "FEATURE_FLAGS=$FEATURE_FLAGS"
          echo "TELEMETRY_URL=$TELEMETRY_URL"
          echo "API_TOKEN=$API_TOKEN"

  deploy-prod:
    runs-on: ubuntu-latest
    environment: production
    env:
      API_URL:        ${{ vars.API_URL }}
      API_TOKEN:      ${{ secrets.API_TOKEN }}
      FEATURE_FLAGS:  ${{ vars.FEATURE_FLAGS }}
      TELEMETRY_URL:  ${{ vars.TELEMETRY_URL }}
    steps:
      - name: print-config
        run: |
          echo "env=production"
          echo "API_URL=$API_URL"
          echo "FEATURE_FLAGS=$FEATURE_FLAGS"
          echo "TELEMETRY_URL=$TELEMETRY_URL"
          echo "API_TOKEN=$API_TOKEN"
EOF

cat > "$WF/smoke.yml" <<'EOF'
# smoke.yml — no environment, reads only an org/repo-wide variable.
name: smoke

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  ping-telemetry:
    runs-on: ubuntu-latest
    env:
      TELEMETRY_URL: ${{ vars.TELEMETRY_URL }}
    steps:
      - name: show-telemetry
        run: |
          echo "TELEMETRY_URL=$TELEMETRY_URL"
EOF

echo "== solution written =="
ls -la "$WF"
