#!/usr/bin/env bash
# Issue a JWT for the role 'ci-syncer' in project 'team-payments'.
# Writes the token to /tmp/argocd-ci-token (chmod 600).
#
# You must be logged in as admin (or a user with 'projects, update' permission).
set -eu

PROJECT="${PROJECT:-team-payments}"
ROLE="${ROLE:-ci-syncer}"
TTL="${TTL:-24h}"
OUT="${OUT:-/tmp/argocd-ci-token}"

if ! command -v argocd >/dev/null 2>&1; then
  echo "SKIP: argocd CLI not installed."
  exit 0
fi

# Check login
if ! argocd account whoami >/dev/null 2>&1; then
  echo "SKIP: not logged in. Run 'argocd login <server>' first."
  exit 0
fi

echo "== Issuing JWT for proj:${PROJECT}:${ROLE} (expires in ${TTL}) =="
argocd proj role create-token "$PROJECT" "$ROLE" \
  --expires-in "$TTL" \
  --token-only > "$OUT"
chmod 600 "$OUT"

echo "  OK   token written to $OUT (chmod 600)"
echo "  Preview (first 20 chars): $(head -c 20 "$OUT")..."
echo
echo "List issued tokens:"
argocd proj role list-tokens "$PROJECT" "$ROLE" || true
