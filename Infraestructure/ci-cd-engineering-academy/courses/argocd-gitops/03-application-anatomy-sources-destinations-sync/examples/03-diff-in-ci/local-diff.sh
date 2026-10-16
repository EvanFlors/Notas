#!/usr/bin/env bash
# Local didactic simulation of the CI job in ci-diff.yml.
# Prints the exact argocd app diff command that would run, with placeholders
# resolved from environment variables (or sensible fallbacks). Does NOT connect
# to any real Argo CD server.
#
# Note: no `set -o pipefail` because `argocd app diff` returns 1 on diff found,
# and later `grep -q` on its output would wrongly fail the whole pipe.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== argo-03 example 03: local simulation of argocd-app-diff CI =="
echo

APP_NAME="${APP_NAME:-capstone-api-dev}"
ARGOCD_SERVER="${ARGOCD_SERVER:-argocd.example.com}"
ARGOCD_AUTH_TOKEN="${ARGOCD_AUTH_TOKEN:-<token-not-set>}"
PR_SHA="${PR_SHA:-a1b2c3d4e5f6}"

echo "APP_NAME         = $APP_NAME"
echo "ARGOCD_SERVER    = $ARGOCD_SERVER"
echo "ARGOCD_AUTH_TOKEN= ${ARGOCD_AUTH_TOKEN:0:6}... (truncated)"
echo "PR_SHA           = $PR_SHA"
echo

CMD="argocd app diff $APP_NAME \
  --server $ARGOCD_SERVER \
  --auth-token \$ARGOCD_AUTH_TOKEN \
  --revision $PR_SHA \
  --server-side-generate"

echo "Command that CI would run:"
echo
echo "  $CMD"
echo

echo "Expected exit codes:"
echo "  0  -> no diff; nothing would change on sync."
echo "  1  -> diff found; comment on PR with the diff."
echo "  >1 -> error (auth, missing app, server unreachable)."
echo

# Validate inputs
missing=0
if [ "$ARGOCD_AUTH_TOKEN" = "<token-not-set>" ]; then
  echo "WARN: ARGOCD_AUTH_TOKEN not set — real CI would fail at auth."
  missing=1
fi
if [ "$ARGOCD_SERVER" = "argocd.example.com" ]; then
  echo "WARN: ARGOCD_SERVER is the default placeholder — override for a real run."
  missing=1
fi

echo
if [ "$missing" -eq 0 ]; then
  echo "OK: inputs look complete; this is still a dry-run and does not call argocd."
else
  echo "OK: dry-run finished. Export ARGOCD_SERVER and ARGOCD_AUTH_TOKEN for a real check."
fi

# Also check that the companion workflow file is well-formed YAML (if yq/python available)
WF="$HERE/ci-diff.yml"
echo
echo "Checking workflow syntax: $WF"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WF'))" 2>/dev/null; then
    echo "  OK: $WF parses as YAML."
  else
    echo "  WARN: $WF does not parse as YAML."
  fi
else
  echo "  SKIP: python3 not available for YAML parse check."
fi

echo
echo "== Done. =="
