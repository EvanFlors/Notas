#!/usr/bin/env bash
# Validate gh-11-01-pre-commit-framework.
#
# Note: we deliberately do NOT set `-o pipefail` globally because some checks
# use pipes to `grep -q` on long-producing commands; SIGPIPE on the producer
# would spuriously mark them as failures. We rely on explicit exit-code checks.

REPO="${1:-${REPO_DIR:-/tmp/pre-commit-lab}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Build it with starter/build-starter-repo.sh"
  exit 1
fi

cd "$REPO"

# -----------------------------------------------------------
# 1) .pre-commit-config.yaml exists and parses as YAML
# -----------------------------------------------------------
if [ ! -f .pre-commit-config.yaml ]; then
  echo "  FAIL .pre-commit-config.yaml is missing"
  exit 1
fi

if ! python3 -c "import yaml, sys; yaml.safe_load(open('.pre-commit-config.yaml'))" 2>/dev/null; then
  echo "  FAIL .pre-commit-config.yaml is not valid YAML (or PyYAML missing)"
  fail=$((fail+1))
fi
echo "  OK   .pre-commit-config.yaml exists and parses"

# -----------------------------------------------------------
# 2) Static structural checks on the YAML
# -----------------------------------------------------------
python3 - <<'PY'
import sys, yaml
cfg = yaml.safe_load(open('.pre-commit-config.yaml')) or {}
repos = cfg.get('repos') or []
if not isinstance(repos, list) or not repos:
    print("  FAIL repos: must be a non-empty list"); sys.exit(2)

all_ids = []
required = {"trailing-whitespace", "end-of-file-fixer", "check-added-large-files"}
bad_revs = []
for r in repos:
    rev = str(r.get('rev', ''))
    if rev in ('HEAD', 'main', 'master', ''):
        bad_revs.append((r.get('repo'), rev))
    for h in r.get('hooks') or []:
        hid = h.get('id')
        if hid:
            all_ids.append(hid)

if len(all_ids) < 3:
    print(f"  FAIL need >=3 hooks (found {len(all_ids)}: {all_ids})"); sys.exit(3)
print(f"  OK   found {len(all_ids)} hooks: {all_ids}")

missing = required - set(all_ids)
if missing:
    print(f"  FAIL missing required hooks: {sorted(missing)}"); sys.exit(4)
print(f"  OK   required hooks present: {sorted(required)}")

if bad_revs:
    for repo, rev in bad_revs:
        print(f"  FAIL repo '{repo}' has rev '{rev}' (pin to a tag/SHA, not HEAD/main/master)")
    sys.exit(5)
print("  OK   all revs are pinned (not HEAD/main/master)")
PY
rc=$?
if [ "$rc" -ne 0 ]; then
  fail=$((fail+1))
fi

# -----------------------------------------------------------
# 3) Shim at .git/hooks/pre-commit (installed by `pre-commit install`)
# -----------------------------------------------------------
if [ ! -x .git/hooks/pre-commit ]; then
  echo "  FAIL .git/hooks/pre-commit missing or not executable (run 'pre-commit install')"
  fail=$((fail+1))
else
  if grep -q "pre-commit" .git/hooks/pre-commit 2>/dev/null; then
    echo "  OK   .git/hooks/pre-commit shim present"
  else
    echo "  WARN .git/hooks/pre-commit exists but does not look like the framework shim"
  fi
fi

# -----------------------------------------------------------
# 4) `pre-commit run --all-files` passes
# -----------------------------------------------------------
if command -v pre-commit >/dev/null 2>&1; then
  PC="pre-commit"
elif python3 -c "import pre_commit" >/dev/null 2>&1; then
  PC="python3 -m pre_commit"
else
  echo "  FAIL neither 'pre-commit' nor the 'pre_commit' Python module is available."
  echo "       Install with: pip install --user pre-commit  (or pipx install pre-commit)"
  exit 1
fi

echo "  ..   running: $PC run --all-files"
if $PC run --all-files >/tmp/pc-run.log 2>&1; then
  echo "  OK   '$PC run --all-files' passed"
else
  echo "  FAIL '$PC run --all-files' did not pass. Output:"
  sed 's/^/       /' /tmp/pc-run.log
  fail=$((fail+1))
fi

# -----------------------------------------------------------
# 5) Working tree clean (student committed the config)
# -----------------------------------------------------------
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean (commit the .pre-commit-config.yaml):"
  git status --short
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
