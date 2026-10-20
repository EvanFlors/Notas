#!/usr/bin/env bash
# Simulate a CI runner using ONLY the JWT (no interactive login, no admin creds).
#
# Usage: bash simulate-ci-sync.sh <app-name>
set -eu

APP="${1:-}"
TOKEN_FILE="${TOKEN_FILE:-/tmp/argocd-ci-token}"
SERVER="${ARGOCD_SERVER:-}"

if [ -z "$APP" ]; then
  echo "Usage: $0 <app-name>"
  exit 2
fi

if ! command -v argocd >/dev/null 2>&1; then
  echo "SKIP: argocd CLI not installed."
  exit 0
fi

if [ ! -f "$TOKEN_FILE" ]; then
  echo "SKIP: no token at $TOKEN_FILE. Run issue-token.sh first."
  exit 0
fi

if [ -z "$SERVER" ]; then
  # Derive from current config to make the demo easier.
  SERVER=$(argocd context 2>/dev/null | awk 'NR>1 && $1=="*"{print $2}')
fi
if [ -z "$SERVER" ]; then
  echo "SKIP: ARGOCD_SERVER not set and no current context."
  exit 0
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "== Who am I with this token? =="
# argocd uses --auth-token to bypass local config and act as the JWT.
argocd --server "$SERVER" --auth-token "$TOKEN" --insecure account whoami || true

echo
echo "== Attempting sync of $APP =="
argocd --server "$SERVER" --auth-token "$TOKEN" --insecure \
  app sync "$APP" --timeout 120 || {
    echo
    echo "If this failed with 'permission denied', the role's policies do not grant sync on '$APP'."
    echo "If it failed with 'not permitted in project', the Application does not belong to the project this role covers."
    exit 1
  }

echo
echo "== Attempting a FORBIDDEN action (delete) to prove least privilege =="
# Expected: permission denied — role has only get+sync.
if argocd --server "$SERVER" --auth-token "$TOKEN" --insecure app delete "$APP" --yes 2>&1 \
     | grep -q "permission denied"; then
  echo "  OK   delete was correctly denied — least privilege working."
else
  echo "  WARN delete did NOT return the expected 'permission denied'. Review role policies."
fi
