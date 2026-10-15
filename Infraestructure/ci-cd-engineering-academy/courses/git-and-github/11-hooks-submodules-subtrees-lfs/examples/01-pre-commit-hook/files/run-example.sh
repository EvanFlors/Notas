#!/usr/bin/env bash
# Demo of a native .git/hooks/pre-commit that rejects TODOs without an owner.
# Runs end-to-end: builds the repo, installs the hook, shows a FAIL commit and a PASS commit.
set -u

REPO="${1:-/tmp/hook-native}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "== Available hook samples =="
ls .git/hooks/ | head -20
echo

# Install our hook
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
# Reject commits that add TODOs without an owner "TODO(name):".
set -e

files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|sh|md|txt)$' || true)
if [ -z "$files" ]; then
  exit 0
fi

bad=""
for f in $files; do
  hits=$(grep -nE 'TODO([^(]|$)' "$f" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    bad+="--- $f ---"$'\n'"$hits"$'\n'
  fi
done

if [ -n "$bad" ]; then
  echo "ERROR: TODOs sin owner. Usa 'TODO(nombre): texto'." >&2
  echo "$bad" >&2
  exit 1
fi
HOOK
chmod +x .git/hooks/pre-commit
echo "== Hook installed at .git/hooks/pre-commit =="
echo

# Attempt 1: should FAIL
cat > app.py <<'EOF'
def foo():
    # TODO: refactor this
    return 42
EOF
git add app.py

echo "== Attempt 1: TODO without owner (expected: ABORTED) =="
if git commit -m "feat: add foo" 2>&1; then
  echo "UNEXPECTED: commit succeeded"
  exit 2
else
  echo "OK: commit was aborted as expected."
fi
echo

# Attempt 2: should PASS
cat > app.py <<'EOF'
def foo():
    # TODO(alice): refactor this
    return 42
EOF
git add app.py

echo "== Attempt 2: TODO with owner (expected: SUCCESS) =="
git commit -m "feat: add foo"
echo

echo "== Final history =="
git log --oneline

echo
echo "Done. Cleanup: rm -rf $REPO"
