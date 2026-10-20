#!/usr/bin/env bash
# Reference solution for gh-06-02-rebase-onto-wrong-base.
set -euo pipefail

REPO="${1:-/tmp/rebase-onto-wrong-base}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$SELF_DIR/../starter/build-wrong-base.sh" "$REPO"
cd "$REPO"

git switch -q feature/dashboard

# The fix in one line: move commits that are in feature/dashboard but not in
# release/1.0, and reapply them on top of main.
git rebase --onto main release/1.0

echo
echo "===== Resultado ====="
git log --all --graph --oneline --decorate
