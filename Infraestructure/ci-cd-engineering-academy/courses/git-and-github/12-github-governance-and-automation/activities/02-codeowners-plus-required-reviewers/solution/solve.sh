#!/usr/bin/env bash
# Reference solution for gh-12-02.
set -eu
DEST="${1:-/tmp/codeowners-lab}"
if [ ! -d "$DEST" ]; then
  echo "Run starter/build-repo.sh first ($DEST missing)" >&2; exit 1
fi

cat > "$DEST/.github/CODEOWNERS" <<'EOF'
# CODEOWNERS — last matching rule wins.
# Default fallback: platform team owns anything not matched below.
*                       @example-org/platform

# Infra as code
infra/                  @example-org/sre
*.tf                    @example-org/sre

# Backend
services/api/           @example-org/backend @alice

# Frontend
apps/web/               @example-org/frontend

# Docs
docs/                   @example-org/docs

# Governance surface — the file itself is sensitive
.github/CODEOWNERS      @example-org/platform-admins
EOF

cat > "$DEST/.github/pull_request_template.md" <<'EOF'
## Context

<!-- Why is this change needed? Link to issues/incidents. -->

## Change

<!-- What does this PR do, in one paragraph? Keep it focused. -->

## Testing

<!-- How was it verified? Commands, screenshots, test IDs. -->

## Risk & rollback

<!-- Blast radius if it goes wrong. How to roll back (revert, feature flag, manual steps). -->
EOF

cat > "$DEST/.github/ruleset-codeowners.json" <<'EOF'
{
  "name": "require-code-owner-review",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    }
  ],
  "bypass_actors": []
}
EOF

echo "OK: solved at $DEST"
