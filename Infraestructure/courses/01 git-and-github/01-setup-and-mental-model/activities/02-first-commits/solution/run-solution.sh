#!/usr/bin/env bash
# Reference solution for gh-01-02-first-commits.
# Builds a /tmp/first-commits repo matching the expected state.

set -euo pipefail

REPO="${1:-/tmp/first-commits}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main

cat > README.md <<'EOF'
# Mi proyecto

Primer commit — solo este archivo.
EOF
git add README.md
git commit -q -m "init: README mínimo"

echo "Línea extra." >> README.md
git add README.md
git commit -q -m "docs: amplía README"

mkdir -p src tests
cat > src/hello.py <<'EOF'
def hello(name: str) -> str:
    return f"Hola, {name}!"
EOF
cat > tests/test_hello.py <<'EOF'
from src.hello import hello

def test_greets():
    assert hello("Git") == "Hola, Git!"
EOF
git add .
git commit -q -m "feat: hello function + test"

echo "" >> README.md
git add README.md
git commit -q -m "update"

cat >> src/hello.py <<'EOF'

def goodbye(name: str) -> str:
    return f"Adiós, {name}!"
EOF
git add src/hello.py
git commit -q -m "feat: añade goodbye()"

echo "Repo built at: $REPO"
git log --oneline
