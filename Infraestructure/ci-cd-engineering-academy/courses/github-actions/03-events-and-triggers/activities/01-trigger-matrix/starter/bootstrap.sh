#!/usr/bin/env bash
# Bootstrap scratch dir for gha-03-01-trigger-matrix.
# Creates /tmp/trigger-matrix/workflows/ with 5 skeleton files and a README.

set -euo pipefail

BASE="${1:-/tmp/trigger-matrix}"
WF="$BASE/workflows"

rm -rf "$BASE"
mkdir -p "$WF"

cat > "$WF/01-ci.yml" <<'YAML'
name: TODO: give me a name

# TODO: Scenario 1 — CI on push to main + PR to main.
# Must IGNORE changes that touch only docs/**.
on: {}

permissions:
  contents: read

jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "TODO"
YAML

cat > "$WF/02-release.yml" <<'YAML'
name: TODO: give me a name

# TODO: Scenario 2 — Publish artifact when a GitHub Release is published.
on: {}

permissions:
  contents: read

jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "TODO"
YAML

cat > "$WF/03-nightly-cleanup.yml" <<'YAML'
name: TODO: give me a name

# TODO: Scenario 3 — Nightly cleanup at 03:00 UTC + manual re-run.
on: {}

permissions:
  contents: read

jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "TODO"
YAML

cat > "$WF/04-manual-deploy.yml" <<'YAML'
name: TODO: give me a name

# TODO: Scenario 4 — Manual deploy with typed inputs:
#   environment (choice: dev/staging/prod) and tag (string).
on: {}

permissions:
  contents: read

jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "TODO"
YAML

cat > "$WF/05-pr-labeler.yml" <<'YAML'
name: TODO: give me a name

# TODO: Scenario 5 — Label PRs when opened (including from forks).
# MUST write labels on PRs. MUST NOT checkout the PR code.
on: {}

permissions:
  contents: read

jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "TODO"
YAML

cat > "$WF/README.md" <<'MD'
# Trigger matrix — mini-catalogue

| # | File | Scenario | Trigger justification (fill in) |
|---|------|----------|---------------------------------|
| 1 | 01-ci.yml             | CI on push to main + PR to main, ignore docs | TODO |
| 2 | 02-release.yml        | Publish artifact on GitHub Release published  | TODO |
| 3 | 03-nightly-cleanup.yml| Nightly cleanup 03:00 UTC + manual trigger    | TODO |
| 4 | 04-manual-deploy.yml  | Manual deploy with env + tag                  | TODO |
| 5 | 05-pr-labeler.yml     | Label PRs including from forks (no checkout)  | TODO |

Write 2–3 lines per file explaining:
- Why this trigger (not another).
- Which filters you used and why.
- Which permissions and why.
MD

echo "Bootstrapped $BASE"
echo "Edit the 5 files under $WF/ and then run: bash tests/validate.sh"
