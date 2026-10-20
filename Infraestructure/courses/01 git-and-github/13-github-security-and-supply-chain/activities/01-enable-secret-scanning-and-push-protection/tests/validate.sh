#!/usr/bin/env bash
# Validator for gh-13-01-enable-secret-scanning-and-push-protection.
# MODE=local (default): checks the pre-commit hook blocks a secret.
# MODE=live: skips the hook check (assumes server-side push protection); still
# requires SECURITY.md.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

BASE="${1:-${BASE_DIR:-/tmp/sec-scanning}}"
MODE="${MODE:-local}"
REPO="$BASE/repo"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating secret scanning + push protection (MODE=$MODE) under $BASE =="

if [ ! -d "$REPO/.git" ]; then
  bad "repo missing at $REPO (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
else
  ok "repo exists at $REPO"
fi

cd "$REPO"

# ---------- SECURITY.md checks (both modes) ----------
if [ -f SECURITY.md ]; then
  ok "SECURITY.md exists"
  for section in "Reporting" "Controls" "Rotation"; do
    if grep -Eq "^##[[:space:]]+${section}([[:space:]]|$)" SECURITY.md; then
      # Must have non-trivial content (not just TODO)
      # Extract text until next ## header
      stripped="$(python3 - "$section" <<'PY'
import re, sys
section = sys.argv[1]
text = open("SECURITY.md").read()
# Extract section body until next '## ' header or EOF
pat = re.compile(r'^##\s+' + re.escape(section) + r'(?:\s|$)(.*?)(?=^##\s|\Z)',
                 re.MULTILINE | re.DOTALL)
m = pat.search(text)
body = m.group(1) if m else ""
# Strip HTML comments (multiline) and lines beginning with TODO (case-insens)
body = re.sub(r'<!--.*?-->', '', body, flags=re.DOTALL)
body = re.sub(r'(?im)^\s*TODO.*$', '', body)
print(''.join(body.split()), end='')
PY
)"
      if [ -n "$stripped" ]; then
        ok "SECURITY.md section '## $section' has non-trivial content"
      else
        bad "SECURITY.md section '## $section' is empty or only TODO"
      fi
    else
      bad "SECURITY.md missing section '## $section'"
    fi
  done
else
  bad "SECURITY.md missing"
fi

# ---------- Local mode: hook checks ----------
if [ "$MODE" = "local" ]; then
  HOOK=".git/hooks/pre-commit"
  if [ -f "$HOOK" ] && [ -x "$HOOK" ]; then
    ok "pre-commit hook present and executable"
  else
    bad "pre-commit hook missing or not executable at $REPO/$HOOK"
  fi

  # Attempt a secret commit; it must fail (exit != 0 of git commit).
  if [ -f "$HOOK" ] && [ -x "$HOOK" ]; then
    # Isolate: make a copy of index/worktree state by stashing nothing;
    # just add a tracked ephemeral file.
    EPH="__validator_fake_secret.env"
    echo 'export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE' > "$EPH"
    git add "$EPH" 2>/dev/null
    # Capture both commit exit code and the hook output.
    out="$(git commit -m "validator: should be blocked" 2>&1 || true)"
    rc=$?
    # If git commit succeeded (bad), clean up and fail.
    # The hook should make it fail: `set -e` is not on; we captured $?.
    # Check whether the ephemeral file was actually committed:
    committed_ok=1
    if git log -n1 --name-only --pretty=format: 2>/dev/null | grep -qx "$EPH"; then
      committed_ok=0
    fi
    # Reset: unstage and remove file.
    git restore --staged "$EPH" 2>/dev/null || true
    rm -f "$EPH"
    # If we accidentally committed, undo it.
    if [ "$committed_ok" -eq 0 ]; then
      git reset --hard HEAD~1 >/dev/null 2>&1 || true
      bad "pre-commit hook did NOT block a commit containing AKIA* (hook output was: $(printf '%s' "$out" | head -c 200))"
    else
      ok "pre-commit hook blocked a commit containing AKIA*"
    fi
  fi

  # Also smoke-test one more pattern (GitHub token) if hook present
  if [ -f "$HOOK" ] && [ -x "$HOOK" ]; then
    EPH2="__validator_fake_ghp.env"
    # 36 char alnum body
    echo 'GITHUB_TOKEN=ghp_abcdefghijABCDEFGHIJ1234567890ZYXWVU' > "$EPH2"
    git add "$EPH2" 2>/dev/null
    out="$(git commit -m "validator: should also block" 2>&1 || true)"
    committed_ok=1
    if git log -n1 --name-only --pretty=format: 2>/dev/null | grep -qx "$EPH2"; then
      committed_ok=0
    fi
    git restore --staged "$EPH2" 2>/dev/null || true
    rm -f "$EPH2"
    if [ "$committed_ok" -eq 0 ]; then
      git reset --hard HEAD~1 >/dev/null 2>&1 || true
      bad "pre-commit hook did NOT block a commit containing ghp_* GitHub token"
    else
      ok "pre-commit hook blocked a commit containing ghp_* GitHub token"
    fi
  fi
fi

# ---------- Live mode: documentation-only ----------
if [ "$MODE" = "live" ]; then
  if grep -Eqi 'secret[_ ]scanning|push[_ ]protection' SECURITY.md 2>/dev/null; then
    ok "SECURITY.md references server-side controls (secret scanning / push protection)"
  else
    bad "SECURITY.md should mention server-side secret scanning / push protection in MODE=live"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
