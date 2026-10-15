#!/usr/bin/env bash
# Materializes a demo repo layout for the composite action example.
# Does NOT run GitHub Actions locally — it only prepares the files so you can:
#   - inspect the layout
#   - (optionally) push to GitHub and let a real runner execute it
set -euo pipefail

BASE="${1:-/tmp/comp-demo}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== Preparing demo repo at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/.github/actions/setup-python-plus-poetry"
mkdir -p "$BASE/.github/workflows"

cp "$HERE/action.yml"    "$BASE/.github/actions/setup-python-plus-poetry/action.yml"
cp "$HERE/caller-ci.yml" "$BASE/.github/workflows/ci.yml"

cat > "$BASE/pyproject.toml" <<'EOF'
[tool.poetry]
name = "comp-demo"
version = "0.1.0"
description = "Demo project for composite action example"
authors = ["Student <student@example.com>"]
readme = "README.md"
package-mode = false

[tool.poetry.dependencies]
python = ">=3.11,<3.14"

[tool.poetry.group.dev.dependencies]
ruff = "^0.6"
pytest = "^8"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

cat > "$BASE/README.md" <<'EOF'
# comp-demo

Demo repo for the gha-08 composite action example.
EOF

echo
echo "Layout:"
find "$BASE" -not -path '*/.git*' | sort | sed "s|$BASE|.|"

echo
echo "Next:"
echo "  cat $BASE/.github/actions/setup-python-plus-poetry/action.yml"
echo "  cat $BASE/.github/workflows/ci.yml"
echo
echo "To run on real GitHub Actions:"
echo "  cd $BASE && git init -q -b main && git add . && \\"
echo "    git -c user.name=Demo -c user.email=demo@x.y commit -q -m demo && \\"
echo "    gh repo create comp-demo --private --source=. --remote=origin --push"
