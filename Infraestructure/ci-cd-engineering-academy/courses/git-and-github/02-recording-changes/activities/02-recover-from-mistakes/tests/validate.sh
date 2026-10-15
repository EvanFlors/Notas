#!/usr/bin/env bash
# Validate the 4 recovery scenarios of gh-02-02-recover-from-mistakes.
# Each scenario is independent; final report summarizes.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `git log ... | grep -qx ...` which produces SIGPIPE (exit 141) on git when
# grep finds a match early. pipefail would spuriously mark those as failures.

BASE="${1:-${BASE_DIR:-/tmp/recover}}"
passed=0
failed=0
report=""

check_scenario_1() {
  local repo="$BASE/scenario-1"
  local name="Scenario 1 (reflog recovery)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"
  if git log --format='%s' main 2>/dev/null | grep -qx "WIP: experimentos"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — 'WIP: experimentos' no está en main (git log main)\n"
    failed=$((failed+1))
  fi
}

check_scenario_2() {
  local repo="$BASE/scenario-2"
  local name="Scenario 2 (move commit to feature branch)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"
  local main_tip feature_tip
  main_tip="$(git log -n1 --format='%s' main 2>/dev/null || echo '')"
  feature_tip=""
  if git show-ref --verify --quiet refs/heads/feature/dark-mode; then
    feature_tip="$(git log --format='%s' feature/dark-mode | grep -x 'feat: add dark mode' || true)"
  fi

  # Expect: main's latest meaningful commit is NOT 'feat: add dark mode'.
  # The repo also includes 'docs: scenario brief' commits produced by the starter
  # (noise); we must tolerate those. We accept: main does not contain the feat on its log,
  # OR main HAS been reset so that feat is not reachable.
  local main_has_feat
  main_has_feat="$(git log --format='%s' main | grep -x 'feat: add dark mode' || true)"

  if [ -z "$main_has_feat" ] && [ -n "$feature_tip" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ -n "$main_has_feat" ] && why+=" 'feat: add dark mode' sigue en main;"
    [ -z "$feature_tip" ]   && why+=" rama feature/dark-mode no existe o no contiene el feat;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_3() {
  local repo="$BASE/scenario-3"
  local name="Scenario 3 (remove secret from last commit)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"

  # 1) secrets.env must NOT appear in any reachable tree
  local in_tree
  in_tree="$(git log --all --name-only --pretty=format: | sort -u | grep -x 'secrets.env' || true)"

  # 2) .gitignore must exist and ignore secrets.env
  local ignored=0
  if [ -f .gitignore ] && grep -q "^secrets.env$" .gitignore; then
    ignored=1
  fi

  # 3) deploy.sh must still exist in the final tree
  local has_deploy=0
  if git ls-tree -r HEAD --name-only | grep -qx 'deploy.sh'; then
    has_deploy=1
  fi

  # 4) Working tree clean
  local clean=0
  if [ -z "$(git status --porcelain)" ]; then
    clean=1
  fi

  if [ -z "$in_tree" ] && [ "$ignored" -eq 1 ] && [ "$has_deploy" -eq 1 ] && [ "$clean" -eq 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ -n "$in_tree" ] && why+=" 'secrets.env' sigue en la historia alcanzable;"
    [ "$ignored" -ne 1 ] && why+=" .gitignore no contiene 'secrets.env';"
    [ "$has_deploy" -ne 1 ] && why+=" deploy.sh falta en HEAD;"
    [ "$clean" -ne 1 ] && why+=" working tree no está limpio;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_4() {
  local repo="$BASE/scenario-4"
  local name="Scenario 4 (split last commit into two atomic)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"

  # 'chore: cleanup' must NOT exist anymore on main
  local bad
  bad="$(git log main --format='%s' | grep -x 'chore: cleanup' || true)"

  # Must have both target commits
  local has_todo has_bump
  has_todo="$(git log main --format='%s' | grep -x 'chore: remove done TODO' || true)"
  has_bump="$(git log main --format='%s' | grep -x 'chore: bump version to 0.2.0' || true)"

  # Each target commit should touch exactly one of the two files
  local todo_hash bump_hash
  todo_hash="$(git log main --format='%H %s' | awk '/chore: remove done TODO$/{print $1; exit}')"
  bump_hash="$(git log main --format='%H %s' | awk '/chore: bump version to 0.2.0$/{print $1; exit}')"

  local todo_files bump_files
  if [ -n "$todo_hash" ]; then
    todo_files="$(git show --name-only --pretty=format: "$todo_hash" | sed '/^$/d' | sort -u)"
  fi
  if [ -n "$bump_hash" ]; then
    bump_files="$(git show --name-only --pretty=format: "$bump_hash" | sed '/^$/d' | sort -u)"
  fi

  local todo_scope_ok=0 bump_scope_ok=0
  if [ "$todo_files" = "app.py" ]; then todo_scope_ok=1; fi
  if [ "$bump_files" = "VERSION" ]; then bump_scope_ok=1; fi

  # Working tree clean
  local clean=0
  if [ -z "$(git status --porcelain)" ]; then clean=1; fi

  if [ -z "$bad" ] && [ -n "$has_todo" ] && [ -n "$has_bump" ] \
     && [ "$todo_scope_ok" -eq 1 ] && [ "$bump_scope_ok" -eq 1 ] && [ "$clean" -eq 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ -n "$bad" ] && why+=" 'chore: cleanup' sigue en main;"
    [ -z "$has_todo" ] && why+=" falta 'chore: remove done TODO';"
    [ -z "$has_bump" ] && why+=" falta 'chore: bump version to 0.2.0';"
    [ "$todo_scope_ok" -ne 1 ] && why+=" 'remove done TODO' toca archivos != app.py ($todo_files);"
    [ "$bump_scope_ok" -ne 1 ] && why+=" 'bump version' toca archivos != VERSION ($bump_files);"
    [ "$clean" -ne 1 ] && why+=" working tree no está limpio;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

echo "== Validating 4 scenarios under $BASE =="

if [ ! -d "$BASE/scenario-1/.git" ] && [ ! -d "$BASE/scenario-2/.git" ] \
   && [ ! -d "$BASE/scenario-3/.git" ] && [ ! -d "$BASE/scenario-4/.git" ]; then
  echo "FAIL: no scenarios found under $BASE. Run starter/build-broken-repos.sh first."
  exit 1
fi

check_scenario_1
check_scenario_2
check_scenario_3
check_scenario_4

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/4 scenarios OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
