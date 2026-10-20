#!/usr/bin/env bash
# Build the starter repo for gh-07-02-codeowners-and-required-reviews.
# Creates a multi-team layout WITHOUT .github/CODEOWNERS, WITHOUT PR template,
# WITHOUT review-policy — those are the student's deliverables.
#
# Idempotent: wipes $BASE if it exists.

set -euo pipefail

BASE="${1:-/tmp/codeowners-lab}"

rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

export GIT_AUTHOR_NAME="Starter"
export GIT_AUTHOR_EMAIL="starter@example.com"
export GIT_COMMITTER_NAME="Starter"
export GIT_COMMITTER_EMAIL="starter@example.com"

git init -q
git checkout -q -b main 2>/dev/null || git switch -q -c main

mkdir -p src/api src/web docs infra tests .github/workflows .pr/issues

cat > README.md <<'EOF'
# acme-platform

Repo multi-equipo. Subsistemas: api (python), web (typescript), docs, infra (terraform).
EOF

cat > src/api/__init__.py <<'EOF'
"""acme.api package."""
EOF

cat > src/api/handlers.py <<'EOF'
def hello() -> dict:
    return {"msg": "hello"}
EOF

cat > src/web/app.ts <<'EOF'
export function hello(): string {
  return "hello";
}
EOF

cat > src/web/index.html <<'EOF'
<!doctype html><title>acme</title>
EOF

cat > docs/architecture.md <<'EOF'
# Architecture
...
EOF

cat > docs/runbook.md <<'EOF'
# Runbook
...
EOF

cat > infra/main.tf <<'EOF'
terraform {}
EOF

cat > tests/test_handlers.py <<'EOF'
from src.api.handlers import hello


def test_hello():
    assert hello() == {"msg": "hello"}
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF

cat > .pr/issues/1.md <<'EOF'
# Issue #1 — governance

Add .github/CODEOWNERS, .github/PULL_REQUEST_TEMPLATE.md and .github/review-policy.yaml
documenting ownership and review requirements for all subsystems.
EOF

cat > SECURITY.md <<'EOF'
# Security

Report vulns to security@acme.example.
EOF

git add -A
git commit -q -m "chore: initial multi-team skeleton"

echo "Starter repo ready at $BASE"
echo "Deliverables:"
echo "  .github/CODEOWNERS"
echo "  .github/PULL_REQUEST_TEMPLATE.md"
echo "  .github/review-policy.yaml"
