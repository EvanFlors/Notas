#!/usr/bin/env bash
# Build the upstream repo and a scratch directory for the student to work in.
set -euo pipefail

BASE="${1:-/tmp/adr-sub-vs-tree}"
rm -rf "$BASE"
mkdir -p "$BASE/scratch"

cd "$BASE"
mkdir upstream && cd upstream
git init -q -b main
git config user.name  "Upstream"
git config user.email "upstream@example.com"

cat > greet.py <<'EOF'
def greet(name: str) -> str:
    return f"Hello, {name}!"
EOF
cat > README.md <<'EOF'
# libgreet
A tiny greeting library.
EOF
git add .
git commit -q -m "init: libgreet"

cat >> greet.py <<'EOF'


def shout(text: str) -> str:
    return text.upper()
EOF
git add greet.py
git commit -q -m "feat: add shout"

echo 'VERSION = "0.2.0"' > version.py
git add version.py
git commit -q -m "chore: tag 0.2.0"

echo "Scenario ready at: $BASE"
echo "  upstream repo:   $BASE/upstream"
echo "  scratch dir:     $BASE/scratch     (build super-sub/ and super-tree/ here)"
echo "  write your ADR:  $BASE/ADR.md"
