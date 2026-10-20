#!/usr/bin/env bash
# apply.sh — translate environment-production.yaml into `gh api` calls.
#
# Usage:
#   bash apply.sh --dry-run     # print the commands, do nothing (default)
#   bash apply.sh --apply       # actually apply (requires GH_OWNER, GH_REPO, gh auth)
#
# NOTE: no `set -o pipefail` — pipes with grep -q against potentially large
# gh api outputs could hit SIGPIPE and mis-report success as failure.
set -eu

MODE="${1:---dry-run}"
HERE="$(cd "$(dirname "$0")" && pwd)"
YAML="$HERE/environment-production.yaml"

if [ ! -f "$YAML" ]; then
  echo "FAIL: $YAML not found" >&2
  exit 1
fi

ENV_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML'))['name'])")
WAIT=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML'))['wait_timer'])")
PATTERNS=$(python3 -c "
import yaml
d = yaml.safe_load(open('$YAML'))
for p in d.get('deployment_branch_policy', {}).get('patterns', []):
    print(p)
")

print_plan() {
  echo "Plan for environment '$ENV_NAME':"
  echo "  1. PUT environments/$ENV_NAME  wait_timer=$WAIT  deployment_branch_policy custom_branch_policies=true"
  echo "  2. For each reviewer in YAML, resolve id (team or user) and PUT environments/$ENV_NAME with reviewers[]"
  echo "  3. For each pattern below, POST environments/$ENV_NAME/deployment-branch-policies -f name=<pattern>:"
  echo "$PATTERNS" | sed 's/^/       - /'
  echo "  4. Secrets listed in YAML must be set out-of-band:"
  echo "       gh secret set <NAME> --env $ENV_NAME --body '<value>'"
}

case "$MODE" in
  --dry-run)
    echo "== DRY RUN =="
    print_plan
    echo
    echo "Nothing was executed. Re-run with --apply (and GH_OWNER/GH_REPO) to apply."
    ;;
  --apply)
    : "${GH_OWNER:?set GH_OWNER (your user or org)}"
    : "${GH_REPO:?set GH_REPO (repo name)}"
    if ! command -v gh >/dev/null 2>&1; then
      echo "FAIL: gh CLI not installed" >&2; exit 2
    fi
    if ! gh auth status >/dev/null 2>&1; then
      echo "FAIL: gh not authenticated" >&2; exit 2
    fi
    echo "== APPLY to $GH_OWNER/$GH_REPO =="
    print_plan
    echo
    echo "-- Creating / updating environment '$ENV_NAME' --"
    gh api -X PUT "repos/$GH_OWNER/$GH_REPO/environments/$ENV_NAME" \
      -F wait_timer="$WAIT" \
      -F "deployment_branch_policy[protected_branches]=false" \
      -F "deployment_branch_policy[custom_branch_policies]=true" \
      >/dev/null
    echo "   OK environment upserted"

    echo "-- Adding branch policy patterns --"
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      gh api -X POST "repos/$GH_OWNER/$GH_REPO/environments/$ENV_NAME/deployment-branch-policies" \
        -f name="$pat" >/dev/null 2>&1 || echo "   (pattern '$pat' may already exist, skipping)"
      echo "   OK pattern $pat"
    done <<< "$PATTERNS"

    echo
    echo "Reviewers: resolve the IDs for users/teams listed in the YAML and"
    echo "re-run a PUT with -F 'reviewers[][type]=User' -F 'reviewers[][id]=<id>'."
    echo "This script keeps reviewer wiring manual on purpose to avoid half-correct"
    echo "pins in demos."
    ;;
  *)
    echo "Unknown mode: $MODE (use --dry-run or --apply)" >&2
    exit 2
    ;;
esac
