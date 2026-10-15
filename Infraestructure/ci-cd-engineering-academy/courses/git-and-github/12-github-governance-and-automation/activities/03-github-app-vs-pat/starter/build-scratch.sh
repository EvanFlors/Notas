#!/usr/bin/env bash
set -eu
DEST="${1:-/tmp/adr-identity}"
rm -rf "$DEST"
mkdir -p "$DEST"

cat > "$DEST/ADR.md" <<'EOF'
# ADR: Identity for the PR-labeling / deploy-status / S3-upload bot

- **Status:** <TODO: proposed | accepted>
- **Date:** <TODO: YYYY-MM-DD>
- **Deciders:** <TODO: your name / team>

## Context

<TODO: describe in your own words — do not just copy the scenario — the
problem being solved, the actors (GitHub, AWS, Vault), and the compliance
constraints (no credential > 90d, auditable rotation, cross-org audit log).>

## Decision

<TODO: state the chosen identity (or composition — e.g. GitHub App for
GitHub operations + OIDC for AWS). Be explicit about what each identity
is used for.>

## Consequences

### Positive

<TODO: at least 3 bullets covering security, operability, velocity.>

### Negative

<TODO: at least 2 bullets with concrete mitigations.>

## Alternatives considered

### PAT classic

<TODO: why rejected.>

### PAT fine-grained

<TODO: why rejected or where it would still be used.>

### Other (specify)

<TODO: at least one more rejected option with reasoning.>

## Compliance mapping

| Requirement | How this decision satisfies it |
|-------------|--------------------------------|
| No credentials > 90 days | <TODO> |
| Auditable rotation | <TODO> |
| Cross-org audit log | <TODO> |

## Follow-ups

<TODO: 2–3 action items with owners and target dates.>
EOF

cat > "$DEST/README.md" <<'EOF'
# Scratch dir for gh-12-03-github-app-vs-pat

Fill ADR.md following the template. Replace every <TODO: ...> block with
your own content. Length target: 300–600 words total.

Validate with:
  bash <repo>/activities/03-github-app-vs-pat/tests/validate.sh /tmp/adr-identity
EOF

echo "OK: scratch dir ready at $DEST"
