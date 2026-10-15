#!/usr/bin/env bash
# Validate gh-07-01-open-review-merge-pr.
#
# Modes:
#   MODE=local (default): validate against local bare-remote repo at $BASE.
#   MODE=live           : validate against a real GitHub PR; needs GH_REPO + PR_NUMBER
#                          (or latest open/merged PR in GH_REPO) and gh CLI auth.
#
# Note: we deliberately do NOT set `set -o pipefail`. Several checks use
# `git log ... | grep -q ...` and a SIGPIPE from the producer would spuriously
# mark the check as failed.

BASE="${1:-${BASE_DIR:-/tmp/pr-review}}"
MODE="${MODE:-local}"
fail=0

ok()   { echo "  OK   $*"; }
nok()  { echo "  FAIL $*"; fail=$((fail+1)); }

echo "== Validating gh-07-01 in MODE=$MODE at $BASE =="

validate_local() {
  local work="$BASE/work"
  local remote="$BASE/remote.git"

  if [ ! -d "$remote" ] || [ ! -d "$work/.git" ]; then
    nok "repo not built — run: bash starter/build-base-repo.sh $BASE"
    return
  fi

  cd "$work"

  # ─── 1. feature branch exists on remote with >=2 atomic commits ─────────
  if git ls-remote --exit-code --heads "$remote" feat/shout >/dev/null 2>&1; then
    ok "feat/shout exists on remote"
  else
    nok "feat/shout branch not pushed to remote"
  fi

  # Count commits on feat/shout beyond main
  if git show-ref --verify --quiet refs/heads/feat/shout \
     || git show-ref --verify --quiet refs/remotes/origin/feat/shout; then
    git fetch -q origin feat/shout 2>/dev/null || true
    local commits_on_feat
    commits_on_feat=$(git rev-list --count origin/main..origin/feat/shout 2>/dev/null || echo 0)
    if [ "$commits_on_feat" -ge 2 ]; then
      ok "feat/shout has $commits_on_feat commits beyond main (>=2)"
    else
      nok "feat/shout has only $commits_on_feat commits beyond main (expected >=2)"
    fi
  fi

  # ─── 2. PR document exists and contains required sections ──────────────
  local pr_doc
  pr_doc=""
  if [ -f "$work/.pr/PR-1.md" ]; then
    pr_doc="$work/.pr/PR-1.md"
  else
    # may live on feat/shout branch — try reading it
    if git show "feat/shout:.pr/PR-1.md" >/dev/null 2>&1; then
      pr_doc="__from_branch__"
      git show "feat/shout:.pr/PR-1.md" > /tmp/_pr1.md 2>/dev/null
      pr_doc="/tmp/_pr1.md"
    fi
  fi

  if [ -z "$pr_doc" ]; then
    nok ".pr/PR-1.md not found (neither in work tree nor on feat/shout)"
  else
    ok ".pr/PR-1.md found"

    # Each required section with non-empty content on a line below
    local section_bad=0
    for sec in "Summary" "Changes" "Test plan" "Merge strategy"; do
      if grep -q "^##[[:space:]]\+${sec}" "$pr_doc"; then
        # Non-empty body: next non-blank, non-HTML-comment line after header
        local body
        body=$(awk -v s="$sec" '
          BEGIN{found=0}
          /^##[[:space:]]+/{
            if (found==1) { exit }
            if (index($0, s)>0) { found=1; next }
          }
          found==1 && NF>0 && !/^<!--/ && !/^-->$/ { print; exit }
        ' "$pr_doc")
        if [ -n "$body" ]; then
          ok "PR-1.md section '$sec' is non-empty"
        else
          nok "PR-1.md section '$sec' is empty"
          section_bad=$((section_bad+1))
        fi
      else
        nok "PR-1.md missing '## $sec' header"
        section_bad=$((section_bad+1))
      fi
    done

    # Fixes #1 closing keyword (case-insensitive)
    if grep -Eiq '(fixes|closes|resolves)[[:space:]]+#1\b' "$pr_doc"; then
      ok "PR-1.md contains closing keyword for #1"
    else
      nok "PR-1.md missing 'Fixes #1' (or Closes/Resolves #1)"
    fi

    # Merge strategy value
    local strat
    strat=$(awk '
      BEGIN{found=0}
      /^##[[:space:]]+Merge strategy/{found=1; next}
      found==1 && /^##[[:space:]]/{exit}
      found==1 { print }
    ' "$pr_doc" | tr "[:upper:]" "[:lower:]")
    if echo "$strat" | grep -Eq '\b(squash|rebase|merge-commit|merge commit)\b'; then
      ok "PR-1.md declares a known merge strategy"
    else
      nok "PR-1.md 'Merge strategy' section must contain squash|rebase|merge-commit"
    fi
  fi

  # ─── 3. Approval file exists ────────────────────────────────────────────
  local approval_src=""
  if [ -f "$work/.pr/PR-1.approvals" ]; then
    approval_src="$work/.pr/PR-1.approvals"
  else
    # may live on feat/shout from reviewer push
    git fetch -q origin feat/shout 2>/dev/null || true
    if git show "origin/feat/shout:.pr/PR-1.approvals" >/dev/null 2>&1; then
      git show "origin/feat/shout:.pr/PR-1.approvals" > /tmp/_pr1.approvals 2>/dev/null
      approval_src="/tmp/_pr1.approvals"
    fi
  fi

  if [ -z "$approval_src" ]; then
    nok ".pr/PR-1.approvals not found (reviewer did not approve)"
  else
    if grep -Eq '^approved-by:[[:space:]]*@?[A-Za-z0-9_-]+' "$approval_src"; then
      ok "approval registered: $(grep -E '^approved-by:' "$approval_src" | head -1)"
    else
      nok ".pr/PR-1.approvals present but no 'approved-by: @name' line found"
    fi
  fi

  # ─── 4. main has the merged change (greet.py has shout, test has one too) ─
  git fetch -q origin main 2>/dev/null || true
  git switch -q main 2>/dev/null || true
  git pull -q --ff-only 2>/dev/null || true

  if grep -q 'def shout' greet.py 2>/dev/null; then
    ok "main's greet.py contains def shout(...)"
  else
    nok "main's greet.py does NOT contain def shout — did you merge?"
  fi

  if grep -q 'shout' tests/test_greet.py 2>/dev/null; then
    ok "main's tests/test_greet.py exercises shout"
  else
    nok "main's tests/test_greet.py does not reference shout"
  fi

  # ─── 5. closing keyword or (#1) in a commit reaching main after base ────
  local base_sha
  base_sha=$(git log --format='%H %s' main | awk '/chore: initial project/{print $1; exit}')
  if [ -z "$base_sha" ]; then
    nok "could not locate base commit 'chore: initial project'"
  else
    local closers
    closers=$(git log --format='%B' "${base_sha}..HEAD" | grep -EicI '(fixes|closes|resolves)[[:space:]]+#1\b|\(#1\)')
    if [ "$closers" -ge 1 ]; then
      ok "merged history contains 'Fixes #1' or '(#1)'"
    else
      nok "no commit between base and HEAD references issue #1"
    fi
  fi

  # ─── 6. working tree clean ──────────────────────────────────────────────
  if [ -z "$(git status --porcelain)" ]; then
    ok "working tree clean"
  else
    nok "working tree has uncommitted changes"
  fi
}

validate_live() {
  if ! command -v gh >/dev/null 2>&1; then
    nok "MODE=live requires 'gh' CLI"
    return
  fi
  if ! gh auth status >/dev/null 2>&1; then
    nok "MODE=live requires 'gh auth login'"
    return
  fi
  local repo="${GH_REPO:-}"
  if [ -z "$repo" ]; then
    nok "set GH_REPO=<owner/repo>"
    return
  fi

  local pr="${PR_NUMBER:-}"
  if [ -z "$pr" ]; then
    pr=$(gh pr list --repo "$repo" --state merged --limit 1 --json number -q '.[0].number' 2>/dev/null)
  fi
  if [ -z "$pr" ]; then
    nok "no merged PR found in $repo"
    return
  fi

  local data
  data=$(gh pr view "$pr" --repo "$repo" --json state,mergeCommit,body,title,reviews 2>/dev/null)

  local state body title
  state=$(echo "$data" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("state",""))')
  body=$(echo "$data"  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("body","") or "")')
  title=$(echo "$data" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("title","") or "")')

  if [ "$state" = "MERGED" ]; then
    ok "PR #$pr is MERGED"
  else
    nok "PR #$pr state=$state (expected MERGED)"
  fi

  if echo "$body" | grep -Eiq '(fixes|closes|resolves)[[:space:]]+#[0-9]+'; then
    ok "PR body contains a closing keyword"
  else
    nok "PR body missing closing keyword (Fixes #N)"
  fi

  for sec in Summary Changes "Test plan" "Merge strategy"; do
    if echo "$body" | grep -q "^##[[:space:]]\+${sec}"; then
      ok "PR body has '## $sec'"
    else
      nok "PR body missing '## $sec'"
    fi
  done

  local approvals
  approvals=$(echo "$data" | python3 -c '
import sys,json
d=json.load(sys.stdin)
print(sum(1 for r in (d.get("reviews") or []) if r.get("state")=="APPROVED"))')
  if [ "${approvals:-0}" -ge 1 ]; then
    ok "PR has $approvals APPROVED review(s)"
  else
    nok "PR has no APPROVED review"
  fi
}

if [ "$MODE" = "live" ]; then
  validate_live
else
  validate_local
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
