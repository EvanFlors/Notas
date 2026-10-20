#!/usr/bin/env bash
# Reference solution for gha-03-01-trigger-matrix.
# Writes the 5 workflows + README under /tmp/trigger-matrix/workflows/.

set -euo pipefail

BASE="${1:-/tmp/trigger-matrix}"
WF="$BASE/workflows"

# Run bootstrap first if not done, so the directory exists cleanly.
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$WF/01-ci.yml" <<'YAML'
name: CI

on:
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
  pull_request:
    branches: [main]
    paths-ignore:
      - 'docs/**'

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "lint + test"
YAML

cat > "$WF/02-release.yml" <<'YAML'
name: Publish release artifact

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build and upload asset
        env:
          TAG: ${{ github.event.release.tag_name }}
        run: |
          echo "building asset for $TAG"
          echo "artifact for $TAG" > artifact.txt
YAML

cat > "$WF/03-nightly-cleanup.yml" <<'YAML'
name: Nightly cleanup

on:
  schedule:
    - cron: '0 3 * * *'   # 03:00 UTC daily
  workflow_dispatch:

permissions:
  contents: read

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - run: echo "cleaning stale resources"
YAML

cat > "$WF/04-manual-deploy.yml" <<'YAML'
name: Manual deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        type: choice
        required: true
        default: 'dev'
        options: [dev, staging, prod]
      tag:
        description: 'Image tag to deploy'
        type: string
        required: true

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "deploy ${{ inputs.tag }} to ${{ inputs.environment }}"
YAML

cat > "$WF/05-pr-labeler.yml" <<'YAML'
name: PR labeler

on:
  pull_request_target:
    types: [opened]

permissions:
  contents: read
  pull-requests: write

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - name: Add from-fork label if applicable
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          IS_FORK: ${{ github.event.pull_request.head.repo.fork }}
          REPO: ${{ github.repository }}
        run: |
          if [ "$IS_FORK" = "true" ]; then
            gh pr edit "$PR_NUMBER" --repo "$REPO" --add-label "from-fork"
          fi
YAML

cat > "$WF/README.md" <<'MD'
# Trigger matrix — mini-catalogue

| # | File | Scenario | Trigger justification |
|---|------|----------|-----------------------|
| 1 | 01-ci.yml              | CI on push to main + PR to main, ignore docs  | `push` + `pull_request` cubren ambos ingresos de código al default branch; `paths-ignore: docs/**` evita correr tests cuando solo cambia documentación. `permissions: contents: read` basta — CI no escribe. |
| 2 | 02-release.yml         | Publish artifact on GitHub Release published  | `release` con `types: [published]` dispara solo cuando el release pasa de draft a publicado (no en `created` ni `edited`). `contents: write` para subir assets. |
| 3 | 03-nightly-cleanup.yml | Nightly cleanup 03:00 UTC + manual trigger    | `schedule` para la ejecución diaria (UTC); `workflow_dispatch` como escape hatch cuando el schedule se retrasa o hay que re-ejecutar. |
| 4 | 04-manual-deploy.yml   | Manual deploy with env + tag                  | `workflow_dispatch` con `inputs` tipados — `choice` para environment (validación en el borde), `string` para tag. `environment: ${{ inputs.environment }}` aplica el gate (approvals/secrets) del env. |
| 5 | 05-pr-labeler.yml      | Label PRs including from forks (no checkout)  | `pull_request_target` para tener `pull-requests: write` sobre PRs de forks (que con `pull_request` sería read-only). **No** se hace `actions/checkout` — solo opera sobre metadata, por lo que el código del PR nunca se ejecuta. |
MD

echo "Solution written to $WF"
