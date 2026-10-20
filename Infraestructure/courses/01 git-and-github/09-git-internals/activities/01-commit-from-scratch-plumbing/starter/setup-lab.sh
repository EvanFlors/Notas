#!/usr/bin/env bash
# Prepare an empty repo for gh-09-01-commit-from-scratch-plumbing.
# No commits, no objects. Only `git init` + identity.
set -euo pipefail

BASE="${1:-/tmp/plumbing-lab}"
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

git init -q -b main
git config user.name  "Lab Student"
git config user.email "student@example.com"
git config commit.gpgsign false

cat > HOWTO.md <<'EOF'
# Plumbing lab

Build two chained commits using ONLY plumbing commands:

  hash-object  →  mktree  →  commit-tree  →  update-ref

Rules:
  - NO `git add`.
  - NO `git commit`.

Objectives:
  - Commit 1: "init: hello", tree with hello.txt (content: "hello\n", mode 100644).
  - Commit 2: "feat: add greeter", parent=Commit1, tree with hello.txt (unchanged)
    + greeter.sh (content: "#!/bin/sh\necho hello\n", mode 100755).

When done:
  bash tests/validate.sh "$PWD"
EOF

echo "Lab ready at: $BASE"
echo
echo "Repo is empty on purpose. Nothing to add, nothing to commit — the point is"
echo "to build commits with plumbing. Read HOWTO.md and the activity README."
echo
echo "Cleanup when done:"
echo "  rm -rf $BASE"
