#!/usr/bin/env bash
# Reference solution for gh-11-01-pre-commit-framework.
# Rebuilds the starter, writes the reference .pre-commit-config.yaml,
# installs the framework shim, runs the hooks, commits.
set -euo pipefail

REPO="${1:-/tmp/pre-commit-lab}"

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/build-starter-repo.sh" "$REPO"

cp "$HERE/pre-commit-config.yaml" "$REPO/.pre-commit-config.yaml"

cd "$REPO"

# Prefer `pre-commit` on PATH; fall back to `python3 -m pre_commit`.
if command -v pre-commit >/dev/null 2>&1; then
  PC="pre-commit"
else
  PC="python3 -m pre_commit"
fi
echo "Using: $PC"

$PC install

# Run against all files; must exit 0 on the clean starter.
$PC run --all-files

git add .pre-commit-config.yaml
git -c user.name=Student -c user.email=student@example.com \
    commit -q -m "chore: enable pre-commit framework with 3 hooks"

echo
echo "Solution applied. History:"
git log --oneline
