#!/usr/bin/env bash
# Revoke ALL tokens of the role ci-syncer in project team-payments, and remove
# the local scratch copy.
set -eu

PROJECT="${PROJECT:-team-payments}"
ROLE="${ROLE:-ci-syncer}"
TOKEN_FILE="${TOKEN_FILE:-/tmp/argocd-ci-token}"

if ! command -v argocd >/dev/null 2>&1 || ! argocd account whoami >/dev/null 2>&1; then
  echo "SKIP: argocd CLI not available or not logged in."
  rm -f "$TOKEN_FILE"
  exit 0
fi

# List token IDs (ISO-8601 issuedAt is the ID surrogate shown by `list-tokens`).
ids=$(argocd proj role list-tokens "$PROJECT" "$ROLE" -o json 2>/dev/null \
      | awk -F'"' '/"iat"/{print $4; next} /"id"/{print $4}' || true)

if [ -z "$ids" ]; then
  # Fallback: parse table output
  ids=$(argocd proj role list-tokens "$PROJECT" "$ROLE" 2>/dev/null \
        | awk 'NR>1 {print $1}')
fi

count=0
for id in $ids; do
  [ -z "$id" ] && continue
  argocd proj role delete-token "$PROJECT" "$ROLE" "$id" && count=$((count+1)) || true
done

rm -f "$TOKEN_FILE"
echo "Revoked $count token(s) and removed $TOKEN_FILE."
