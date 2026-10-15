#!/usr/bin/env bash
# Bootstrap for gha-04-02-audit-a-workflow-for-unpinned-deps.
# Creates a scratch dir with two workflows full of antipatterns to audit + fix.
set -euo pipefail

BASE="${1:-/tmp/gha-04-02-audit-a-workflow-for-unpinned-deps}"
rm -rf "$BASE"
mkdir -p "$BASE/repo/.github/workflows"

# ci.yml — mezcla de antipatrones: branch pin, major tag, exact tag, SHA sin comentario.
cat > "$BASE/repo/.github/workflows/ci.yml" <<'EOF'
name: CI (audit me)

on:
  push:
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      # ANTIPATTERN: branch pin
      - uses: actions/checkout@main

      # ANTIPATTERN: major tag, no SHA, no comment
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - run: echo "lint..."

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@master

      # ANTIPATTERN: exact tag, no SHA
      - uses: actions/setup-node@v4.1.0
        with:
          node-version: '20'

      # ANTIPATTERN: SHA without the `# vX.Y.Z` comment
      - uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a
        with:
          path: ~/.cache/pip
          key: pip-${{ hashFiles('**/requirements*.txt') }}

      - run: echo "test..."
EOF

# release.yml — más corto, también sucio.
cat > "$BASE/repo/.github/workflows/release.yml" <<'EOF'
name: Release (audit me)

on:
  push:
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      # ANTIPATTERN: branch pin
      - uses: actions/checkout@main

      # ANTIPATTERN: major tag
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
EOF

echo "== bootstrap OK =="
echo "Audit targets:"
echo "  $BASE/repo/.github/workflows/ci.yml"
echo "  $BASE/repo/.github/workflows/release.yml"
echo
echo "Produce: $BASE/repo/AUDIT.md with your findings table."
echo "Then rewrite both YAMLs to pin all 'uses:' to SHA + '# vX.Y.Z'."
echo
echo "Validate: bash tests/validate.sh $BASE"
