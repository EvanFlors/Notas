#!/usr/bin/env bash
# Bootstrap for gha-08-02-publish-reusable-workflow.
# Creates two sibling git repos (shared, client) simulating a two-repo scenario.
set -euo pipefail

BASE="${1:-/tmp/publish-reusable}"
OWNER_SLUG="${OWNER_SLUG:-my-org/shared-workflows}"

echo "== Bootstrapping at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/shared" "$BASE/client"

# ---- shared repo ----
cd "$BASE/shared"
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
cat > README.md <<EOF
# shared-workflows (simulated as $OWNER_SLUG)

Reusable workflows for the org. Students will add build-and-publish.yml and tag v1.
EOF
git add README.md
git commit -q -m "chore: scaffold shared repo"

# ---- client repo ----
cd "$BASE/client"
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
cat > README.md <<'EOF'
# client-app

Consumes a reusable workflow from the shared repo (simulated locally).
EOF
git add README.md
git commit -q -m "chore: scaffold client repo"

echo
echo "Done. State:"
find "$BASE" -not -path '*/.git/*' | sort | sed "s|$BASE|.|"
echo
echo "OWNER_SLUG = $OWNER_SLUG"
echo
echo "Your tasks:"
echo "  1) In $BASE/shared/ create .github/workflows/build-and-publish.yml"
echo "     with: on.workflow_call, 2+ typed inputs (string + boolean),"
echo "           secret REGISTRY_TOKEN required, output 'digest' propagated."
echo "     Then: git add .github && git commit -m '...' && git tag -a v1.0.0 -m '...' && git tag -a v1 -m '...'"
echo
echo "  2) In $BASE/client/ create .github/workflows/ci.yml"
echo "     with a job that uses: $OWNER_SLUG/.github/workflows/build-and-publish.yml@v1"
echo "     passing REGISTRY_TOKEN explicitly, and a 'needs:' job that reads outputs.digest"
echo
echo "  3) bash tests/validate.sh $BASE"
