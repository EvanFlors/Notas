#!/usr/bin/env bash
# Reference solution for gh-07-01-open-review-merge-pr (MODE=local).
# Full happy-path flow: builds base repo, creates feat/shout, commits code+tests,
# writes PR document, approves from reviewer clone, squash-merges into main.
#
# Usage: bash solution/run-solution.sh [BASE_DIR]

set -euo pipefail

BASE="${1:-/tmp/pr-review}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter/build-base-repo.sh"

bash "$STARTER" "$BASE"

export GIT_AUTHOR_NAME="Dev"
export GIT_AUTHOR_EMAIL="dev@example.com"
export GIT_COMMITTER_NAME="Dev"
export GIT_COMMITTER_EMAIL="dev@example.com"

cd "$BASE/work"

echo "== Creating feat/shout branch and 2 atomic commits"
git switch -q -c feat/shout

cat > greet.py <<'EOF'
"""Micro-librería de saludos."""


def greet(name: str) -> str:
    """Return a friendly greeting."""
    return f"hello, {name}"


def shout(name: str) -> str:
    """Return an all-caps shouted greeting."""
    return f"HELLO, {name.upper()}!"
EOF
git add greet.py
git commit -q -m "feat: add shout helper"

cat > tests/test_greet.py <<'EOF'
from greet import greet, shout


def test_greet_basic():
    assert greet("world") == "hello, world"


def test_shout_basic():
    assert shout("world") == "HELLO, WORLD!"
EOF
git add tests/test_greet.py
git commit -q -m "test: cover shout helper"

echo "== Writing .pr/PR-1.md on feat/shout"
mkdir -p .pr
cat > .pr/PR-1.md <<'EOF'
## Summary

Añade `shout(name)` a `greet.py` para cerrar #1. Función pura y determinista,
con test que verifica el formato esperado.

## Changes

- `greet.py`: nueva función `shout()` que devuelve el saludo en mayúsculas.
- `tests/test_greet.py`: nuevo test `test_shout_basic`.

## Linked issues

Fixes #1

## Test plan

- [x] `pytest tests/test_greet.py` pasa en local.
- [x] Verificado manualmente: `python -c "from greet import shout; print(shout('ada'))"`.

## Merge strategy

squash — el PR cierra un issue único con 2 commits atómicos; una línea en `main`
es más legible y permite revertir con `git revert <sha>` si rompe.

## Risk / rollback

- Riesgo: bajo. Función nueva, no toca APIs existentes.
- Rollback: `git revert <merge-sha>` es seguro; sin migraciones.
EOF
git add .pr/PR-1.md
git commit -q -m "docs(pr): describe PR-1"

git push -q -u origin feat/shout

echo "== Reviewer approves"
cd "$BASE/reviewer"
export GIT_AUTHOR_NAME="Rev"
export GIT_AUTHOR_EMAIL="rev@example.com"
export GIT_COMMITTER_NAME="Rev"
export GIT_COMMITTER_EMAIL="rev@example.com"

git fetch -q origin feat/shout:feat/shout
git switch -q feat/shout
mkdir -p .pr
printf "approved-by: @reviewer\nreview: Looks good; nit: docstring OK.\n" > .pr/PR-1.approvals
git add .pr/PR-1.approvals
git commit -q -m "chore(pr): approve PR-1"
git push -q -u origin feat/shout

echo "== Squash-merging feat/shout into main"
cd "$BASE/work"
export GIT_AUTHOR_NAME="Dev"
export GIT_AUTHOR_EMAIL="dev@example.com"
export GIT_COMMITTER_NAME="Dev"
export GIT_COMMITTER_EMAIL="dev@example.com"

git fetch -q
git switch -q main
git merge --squash feat/shout
git commit -q -m "feat: add shout helper (#1)

Fixes #1

Squashed from feat/shout (2 commits)."
git push -q

echo
echo "Solution applied. Validate with:"
echo "  bash $HERE/../tests/validate.sh $BASE"
