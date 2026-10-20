#!/usr/bin/env bash
# apply.sh — translate environment-production.yaml into gh api calls.
# Usage:
#   bash apply.sh --dry-run        # print the commands, do nothing (default)
#   bash apply.sh --apply          # actually apply (requires GH_OWNER, GH_REPO, gh auth)
set -eu

MODE="${1:---dry-run}"
HERE="$(cd "$(dirname "$0")" && pwd)"
YAML="$HERE/environment-production.yaml"

if [ ! -f "$YAML" ]; then
  echo "FAIL: $YAML not found" >&2; exit 1
fi

ENV_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML'))['name'])")
WAIT=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML'))['wait_timer'])")

cmd1="gh api -X PUT repos/\$GH_OWNER/\$GH_REPO/environments/$ENV_NAME -f wait_timer=$WAIT"
cmd2="# Then add reviewers (resolve team IDs with: gh api orgs/\$GH_OWNER/teams/<slug>)"
cmd3="# For each pattern in deployment_branch_policy.patterns:"
cmd4="#   gh api -X POST repos/\$GH_OWNER/\$GH_REPO/environments/$ENV_NAME/deployment-branch-policies -f name='refs/heads/main'"

case "$MODE" in
  --dry-run)
    echo "DRY RUN — would execute:"
    echo "  $cmd1"
    echo "  $cmd2"
    echo "  $cmd3"
    echo "  $cmd4"
    ;;
  --apply)
    : "${GH_OWNER:?set GH_OWNER}"
    : "${GH_REPO:?set GH_REPO}"
    eval "$cmd1"
    echo "Reviewers must be added manually; team IDs required (see docs)."
    ;;
  *)
    echo "Unknown mode: $MODE (use --dry-run or --apply)" >&2
    exit 2
    ;;
esac
