#!/usr/bin/env bash
# Builds a scratch repo with a dirty working tree ready for `git add -p` practice.
# Run interactively — the point is that YOU execute `git add -p calc.py` manually.
set -euo pipefail

DEMO="${1:-/tmp/stage-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

cat > calc.py <<'EOF'
def add(a, b):
    return a + b


def multyply(a, b):
    return a * b
EOF
git add calc.py
git commit -q -m "init: calc module"

cat > calc.py <<'EOF'
def add(a: int, b: int) -> int:
    """Return the sum of two ints."""
    return a + b


def multiply(a: int, b: int) -> int:
    """Return the product of two ints."""
    return a * b


def subtract(a: int, b: int) -> int:
    """Return a - b."""
    return a - b
EOF

echo "Scratch repo ready at: $DEMO"
echo
echo "Try now:"
echo "  cd $DEMO"
echo "  git diff calc.py"
echo "  git add -p calc.py"
echo
echo "Expected: one 'big' hunk; respond 's' to split, then stage selectively."
