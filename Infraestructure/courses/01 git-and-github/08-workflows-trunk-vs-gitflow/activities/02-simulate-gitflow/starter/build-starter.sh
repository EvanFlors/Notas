#!/usr/bin/env bash
# Starter repo for gh-08-02-simulate-gitflow.
# A single commit on main with VERSION=0.1.0 and a greet() function.
set -euo pipefail

REPO="${1:-/tmp/gitflow-sim}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > app.py <<'EOF'
VERSION = "0.1.0"


def greet():
    return "Hello from app"
EOF

cat > README.md <<'EOF'
# gitflow-sim

Starter for gh-08-02-simulate-gitflow.
Reproduce a full GitFlow cycle (features -> develop -> release -> main + hotfix).
EOF

git add .
git commit -q -m "init: scaffold app and README"
git tag v0.1.0

echo "Starter repo built at: $REPO"
echo "Open README.md in the activity for next steps."
git log --oneline --all
git branch -a
