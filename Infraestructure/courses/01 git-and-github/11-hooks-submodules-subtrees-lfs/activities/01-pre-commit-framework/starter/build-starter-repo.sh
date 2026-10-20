#!/usr/bin/env bash
# Build a starter Python repo with a near-empty .pre-commit-config.yaml.
# The student will add >=3 hooks and make `pre-commit run --all-files` pass.
set -euo pipefail

REPO="${1:-/tmp/pre-commit-lab}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# Clean Python code (no trailing whitespace, LF endings, final newline).
mkdir -p app tests
printf 'def add(a: int, b: int) -> int:\n    return a + b\n' > app/calc.py
printf 'from app.calc import add\n\n\ndef test_add():\n    assert add(2, 3) == 5\n' > tests/test_calc.py
printf '# pre-commit-lab\n\nStarter repo for configuring the pre-commit framework.\n' > README.md

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
.venv/
.pytest_cache/
EOF

# Starter pre-commit config: empty with a TODO. Student must fill it.
cat > .pre-commit-config.yaml <<'EOF'
# Starter config. Replace the TODO with at least 3 real hooks.
# Required hooks for the validator:
#   - trailing-whitespace
#   - end-of-file-fixer
#   - check-added-large-files (args: ['--maxkb=500'])
# All from https://github.com/pre-commit/pre-commit-hooks at rev v4.6.0 (or newer).
# Do NOT use rev: HEAD or rev: main.
repos: []
EOF

git add .
git commit -q -m "init: starter repo for pre-commit framework activity"

echo "Starter built at: $REPO"
echo
echo "Next steps:"
echo "  1. cd $REPO"
echo "  2. edit .pre-commit-config.yaml (add >=3 hooks)"
echo "  3. pre-commit install        (or: python3 -m pre_commit install)"
echo "  4. pre-commit run --all-files"
echo "  5. git add .pre-commit-config.yaml && git commit -m 'chore: enable pre-commit'"
echo "  6. bash tests/validate.sh $REPO"
