#!/usr/bin/env bash
# Prepare /tmp/apply-rulesets with an empty ruleset-main.json
# and a brief guide. The student must fill it in.
set -eu

DEST="${1:-/tmp/apply-rulesets}"
rm -rf "$DEST"
mkdir -p "$DEST"

cat > "$DEST/ruleset-main.json" <<'EOF'
{
  "__TODO__": "Fill this file following the shape documented in README.md section 5.2",
  "name": "",
  "target": "",
  "enforcement": "",
  "conditions": {},
  "rules": [],
  "bypass_actors": []
}
EOF

cat > "$DEST/README.md" <<'EOF'
# Scratch dir for gh-12-01-apply-rulesets

Edit `ruleset-main.json` to protect `refs/heads/main` with:
- PR required, >=1 approval, dismiss stale, require last push approval.
- Required status checks: ci/build and ci/test, strict.
- No deletion, no non-fast-forward.
- bypass_actors: []

Then write DECISION.md with your rationale (>=5 lines).

Validate with:
  bash <repo>/activities/01-apply-rulesets/tests/validate.sh /tmp/apply-rulesets
EOF

echo "OK: scratch dir ready at $DEST"
