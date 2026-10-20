#!/usr/bin/env bash
# Validate gha-12-03-publish-and-pin.
#
# Checks (both MODE=local and MODE=live):
#   1. Publisher has tags v1.0.0 and v1 pointing to the same commit.
#   2. Publisher bare remote (or GitHub) has those tags.
#   3. Consumer workflow pins greet-action to a 40-char SHA.
#   4. SHA matches publisher's v1.0.0.
#   5. Pin has a '# v<something>' comment next to it.
#
# NOTE: no `set -o pipefail`; several checks pipe git-log/show-ref/etc into
# grep -q which can trigger SIGPIPE (exit 141) and be mis-reported as failure.

BASE="${1:-${BASE_DIR:-/tmp/publish-and-pin}}"
MODE="${MODE:-local}"
PUB_DIR="$BASE/publisher"
CON_DIR="$BASE/consumer"

passed=0; failed=0; report=""
note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE =="

if [ ! -d "$PUB_DIR/.git" ] || [ ! -d "$CON_DIR/.git" ]; then
  echo "FAIL: publisher/ or consumer/ not initialized. Run starter/bootstrap.sh." >&2
  exit 1
fi

# ---------- Check 1: publisher has v1.0.0 and v1, same commit ----------
cd "$PUB_DIR"
v100_sha="$(git rev-parse --verify -q 'refs/tags/v1.0.0' || true)"
v1_sha="$(git rev-parse --verify -q 'refs/tags/v1' || true)"
if [ -n "$v100_sha" ]; then
  note_ok "publisher has tag v1.0.0 ($v100_sha)"
else
  note_fail "publisher missing tag v1.0.0 (run: git tag -a v1.0.0 -m ...)"
fi
if [ -n "$v1_sha" ]; then
  note_ok "publisher has tag v1 ($v1_sha)"
else
  note_fail "publisher missing tag v1 (run: git tag -f v1 v1.0.0)"
fi
if [ -n "$v100_sha" ] && [ -n "$v1_sha" ] && [ "$v100_sha" = "$v1_sha" ]; then
  note_ok "v1 points to the same commit as v1.0.0"
elif [ -n "$v100_sha" ] && [ -n "$v1_sha" ]; then
  note_fail "v1 ($v1_sha) does not point to v1.0.0 ($v100_sha)"
fi

# ---------- Check 2: remote has the tags ----------
if [ "$MODE" = "local" ]; then
  BARE="$BASE/publisher.git"
  if [ ! -d "$BARE" ]; then
    note_fail "no bare remote at $BARE"
  else
    remote_v100="$(git --git-dir="$BARE" rev-parse refs/tags/v1.0.0 2>/dev/null || true)"
    remote_v1="$(git --git-dir="$BARE" rev-parse refs/tags/v1 2>/dev/null || true)"
    if [ -n "$remote_v100" ] && [ "$remote_v100" = "$v100_sha" ]; then
      note_ok "bare publisher.git has v1.0.0 pushed"
    else
      note_fail "bare publisher.git missing v1.0.0 (git push origin v1.0.0)"
    fi
    if [ -n "$remote_v1" ] && [ "$remote_v1" = "$v100_sha" ]; then
      note_ok "bare publisher.git has v1 pushed to same commit"
    else
      note_fail "bare publisher.git missing v1 or points elsewhere (git push origin v1 --force)"
    fi
  fi
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "gh CLI required for MODE=live"
  else
    origin_url="$(cd "$PUB_DIR" && git remote get-url origin 2>/dev/null || true)"
    slug=""
    case "$origin_url" in
      git@github.com:*)       slug="${origin_url#git@github.com:}";;
      https://github.com/*)   slug="${origin_url#https://github.com/}";;
    esac
    slug="${slug%.git}"
    if [ -z "$slug" ]; then
      note_fail "could not parse publisher origin URL"
    else
      remote_v100="$(gh api "repos/$slug/git/refs/tags/v1.0.0" --jq '.object.sha' 2>/dev/null || true)"
      remote_v1="$(gh api "repos/$slug/git/refs/tags/v1" --jq '.object.sha' 2>/dev/null || true)"
      [ -n "$remote_v100" ] && note_ok "GitHub $slug has v1.0.0" || note_fail "GitHub $slug missing v1.0.0"
      [ -n "$remote_v1" ]   && note_ok "GitHub $slug has v1"     || note_fail "GitHub $slug missing v1"
    fi
  fi
else
  note_fail "unknown MODE='$MODE'"
fi

# ---------- Check 3+4+5: consumer workflow is pinned to SHA ----------
WF="$CON_DIR/.github/workflows/ci.yml"
if [ ! -f "$WF" ]; then
  note_fail "consumer workflow not found: $WF"
else
  # Only flag if a non-comment line still has the placeholder (comments explaining it are fine).
  if grep -E '^[[:space:]]*(uses|-[[:space:]]*uses):' "$WF" | grep -q 'PLACEHOLDER_GREET_SHA'; then
    note_fail "consumer workflow still has 'uses: ...@PLACEHOLDER_GREET_SHA' (not pinned yet)"
  fi

  # Extract the pinned ref on the greet-action line
  pinned_line="$(grep -E '^\s*uses:\s*demo-owner/greet-action@' "$WF" | head -1 || true)"
  if [ -z "$pinned_line" ]; then
    note_fail "no 'uses: demo-owner/greet-action@...' line found in consumer workflow"
  else
    # Parse: everything after '@' up to space or # or end
    pinned_ref="$(printf '%s' "$pinned_line" | sed -E 's|.*greet-action@([^ #]+).*|\1|')"
    comment_part="$(printf '%s' "$pinned_line" | sed -nE 's|.*#\s*(.*)$|\1|p')"

    if printf '%s' "$pinned_ref" | grep -Eq '^[0-9a-f]{40}$'; then
      note_ok "consumer pins greet-action to a full 40-char SHA ($pinned_ref)"
      if [ -n "$v100_sha" ] && [ "$pinned_ref" = "$v100_sha" ]; then
        note_ok "pinned SHA matches publisher's v1.0.0"
      elif [ -n "$v100_sha" ]; then
        note_fail "pinned SHA ($pinned_ref) != publisher v1.0.0 ($v100_sha)"
      fi
    else
      note_fail "consumer pins to '$pinned_ref' which is NOT a 40-char SHA (tags are mutable; use SHA)"
    fi

    if [ -n "$comment_part" ]; then
      note_ok "pin has a version comment next to it: '# $comment_part'"
    else
      note_fail "pin has no '# vX.Y.Z' comment (helps Dependabot and reviewers)"
    fi
  fi
fi

# ---------- Check 6: consumer committed and pushed (local mode) ----------
if [ "$MODE" = "local" ]; then
  CON_BARE="$BASE/consumer.git"
  if [ -d "$CON_BARE" ]; then
    cm_local="$(cd "$CON_DIR" && git rev-parse main 2>/dev/null || true)"
    cm_remote="$(git --git-dir="$CON_BARE" rev-parse refs/heads/main 2>/dev/null || true)"
    if [ -n "$cm_local" ] && [ "$cm_local" = "$cm_remote" ]; then
      note_ok "consumer pushed main to its bare remote"
    else
      note_fail "consumer did not push main to $CON_BARE (local=$cm_local remote=$cm_remote)"
    fi
  else
    note_fail "no consumer.git bare at $CON_BARE"
  fi
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT ($MODE): $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
