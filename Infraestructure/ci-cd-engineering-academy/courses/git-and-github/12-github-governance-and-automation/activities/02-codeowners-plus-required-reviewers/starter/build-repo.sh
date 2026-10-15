#!/usr/bin/env bash
# Build an empty-ish repo skeleton. The student fills CODEOWNERS, PR template,
# and ruleset JSON.
set -eu

DEST="${1:-/tmp/codeowners-lab}"
rm -rf "$DEST"
mkdir -p "$DEST"/{infra,services/api,apps/web,docs,.github}

# Placeholder files so paths exist
echo "# infra module" > "$DEST/infra/README.md"
echo "resource \"null_resource\" \"demo\" {}" > "$DEST/infra/main.tf"
echo "# api service" > "$DEST/services/api/README.md"
echo "# web app" > "$DEST/apps/web/README.md"
echo "# project docs" > "$DEST/docs/README.md"

# Empty placeholders the student must fill
: > "$DEST/.github/CODEOWNERS"
: > "$DEST/.github/pull_request_template.md"
: > "$DEST/.github/ruleset-codeowners.json"

cat > "$DEST/README.md" <<'EOF'
# Scratch dir for gh-12-02-codeowners-plus-required-reviewers

Fill the following files per instructions in the activity README:
  .github/CODEOWNERS
  .github/pull_request_template.md
  .github/ruleset-codeowners.json
EOF

echo "OK: scratch dir ready at $DEST"
