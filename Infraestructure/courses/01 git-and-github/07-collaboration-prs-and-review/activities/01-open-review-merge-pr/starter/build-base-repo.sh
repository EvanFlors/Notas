#!/usr/bin/env bash
# Build the base repo for gh-07-01-open-review-merge-pr.
# Creates:
#   $BASE/remote.git       — bare "remote" (local stand-in for GitHub)
#   $BASE/work             — contributor's clone
#   $BASE/reviewer         — reviewer's clone
#
# Idempotent: wipes $BASE if it exists.

set -euo pipefail

BASE="${1:-/tmp/pr-review}"

rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

GIT_AUTHOR_NAME="Starter"
GIT_AUTHOR_EMAIL="starter@example.com"
GIT_COMMITTER_NAME="Starter"
GIT_COMMITTER_EMAIL="starter@example.com"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

echo "== Creating bare remote at $BASE/remote.git"
git init --bare -q remote.git

echo "== Seeding contributor clone at $BASE/work"
git clone -q remote.git work
cd work
git checkout -q -b main 2>/dev/null || git switch -q -c main

cat > README.md <<'EOF'
# greet

Micro-librería de saludos para la actividad gh-07-01.
EOF

cat > greet.py <<'EOF'
"""Micro-librería de saludos."""


def greet(name: str) -> str:
    """Return a friendly greeting."""
    return f"hello, {name}"
EOF

mkdir -p tests
cat > tests/test_greet.py <<'EOF'
from greet import greet


def test_greet_basic():
    assert greet("world") == "hello, world"
EOF

mkdir -p .github
cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## Summary

<!-- 2–4 líneas. -->

## Changes

- ...

## Linked issues

Fixes #

## Test plan

- [ ] ...

## Merge strategy

<!-- squash | rebase | merge-commit — justifica en 1–2 frases. -->

## Risk / rollback

- Riesgo:
- Rollback:
EOF

# Simulate the issue tracker as files under .pr/issues/
mkdir -p .pr/issues
cat > .pr/issues/1.md <<'EOF'
# Issue #1 — add shout() helper

Añadir una función `shout(name)` en `greet.py` que devuelva `f"HELLO, {name.upper()}!"`.
Incluir test en `tests/test_greet.py`.
EOF

git add README.md greet.py tests/test_greet.py .github/PULL_REQUEST_TEMPLATE.md .pr/issues/1.md
git commit -q -m "chore: initial project"

cat > CONTRIBUTING.md <<'EOF'
# Contributing

Flujo de PR:
1. Crea rama `feat/<slug>`.
2. Commits atómicos siguiendo Conventional Commits.
3. Abre PR usando `.github/PULL_REQUEST_TEMPLATE.md`.
4. Describe `Merge strategy` elegida.
5. Espera aprobación. Mergea.
EOF
git add CONTRIBUTING.md
git commit -q -m "docs: add CONTRIBUTING"

git push -q -u origin main

# Make bare's HEAD point to main so subsequent clones don't warn.
git -C "$BASE/remote.git" symbolic-ref HEAD refs/heads/main

echo "== Seeding reviewer clone at $BASE/reviewer"
cd "$BASE"
git clone -q remote.git reviewer

echo
echo "Base repo ready at $BASE"
echo "  remote: $BASE/remote.git"
echo "  work:   $BASE/work"
echo "  review: $BASE/reviewer"
echo
echo "Next: cd $BASE/work  && follow README.md section 5.3"
