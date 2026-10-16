#!/usr/bin/env bash
# Exercises the argocd-rbac-cm policy by asking `argocd account can-i` for
# a matrix of (action, resource, object) and reporting pass/fail.
#
# Run this logged in as a user whose OIDC `groups` claim includes
# 'acme-org:team-a' (or edit TEAM_* below for your actual groups).
#
# NOTE: deliberately NO `set -o pipefail`. We use `argocd ... | grep -q`
# where SIGPIPE on grep's first match could otherwise be reported as failure.

set -eu

assert_can() {
  local expect="$1"; shift
  local desc="$1"; shift
  local out
  out="$(argocd account can-i "$@" 2>/dev/null || echo "no")"
  if printf '%s' "$out" | grep -q "^$expect$"; then
    echo "OK   -- $desc -> $out"
  else
    echo "FAIL -- $desc -> got '$out', expected '$expect'"
  fi
}

echo "== team-a user (expected: can touch team-a/*, denied on team-b/*, denied on delete) =="
assert_can "yes" "sync team-a/web"       sync       applications team-a/web
assert_can "yes" "get  team-a/web"       get        applications team-a/web
assert_can "no"  "delete team-a/web"     delete     applications team-a/web
assert_can "no"  "sync team-b/web"       sync       applications team-b/web
assert_can "no"  "get  team-b/web"       get        applications team-b/web
assert_can "no"  "update clusters"       update     clusters     '*'

echo
echo "If you expected different results, verify your group membership with:"
echo "  argocd account get-user-info"
