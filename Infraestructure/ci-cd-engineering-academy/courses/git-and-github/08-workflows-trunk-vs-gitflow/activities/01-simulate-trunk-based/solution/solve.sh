#!/usr/bin/env bash
# Reference solution for gh-08-01-simulate-trunk-based.
# Starts from the already-built starter repo.
set -euo pipefail

REPO="${1:-/tmp/tbd-sim}"
if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$REPO"

# ---------- feat/new-checkout ----------
git switch -q -c feat/new-checkout

cat > flags.py <<'EOF'
# Feature flags for the app. All default to OFF.
# Pattern: FLAGS = {"flag_name": False, ...}
FLAGS = {
    "new_checkout": False,
}
EOF

cat > app.py <<'EOF'
from flags import FLAGS


def checkout():
    if FLAGS.get("new_checkout"):
        return "new-checkout"
    return "legacy-checkout"


def render():
    return "ui-light"
EOF

bash tests/smoke.sh >/dev/null
git add flags.py app.py
git commit -q -m "feat(checkout): new flow behind flag (off)"

git switch -q main
git merge -q --no-ff feat/new-checkout -m "merge: feat/new-checkout"
git branch -d feat/new-checkout >/dev/null

# ---------- feat/dark-mode ----------
git switch -q -c feat/dark-mode

cat > flags.py <<'EOF'
# Feature flags for the app. All default to OFF.
# Pattern: FLAGS = {"flag_name": False, ...}
FLAGS = {
    "new_checkout": False,
    "dark_mode": False,
}
EOF

cat > app.py <<'EOF'
from flags import FLAGS


def checkout():
    if FLAGS.get("new_checkout"):
        return "new-checkout"
    return "legacy-checkout"


def render():
    if FLAGS.get("dark_mode"):
        return "ui-dark"
    return "ui-light"
EOF

bash tests/smoke.sh >/dev/null
git add flags.py app.py
git commit -q -m "feat(ui): dark mode behind flag (off)"

git switch -q main
git merge -q --no-ff feat/dark-mode -m "merge: feat/dark-mode"
git branch -d feat/dark-mode >/dev/null

echo
echo "== Final DAG =="
git log --oneline --graph --all
echo
bash tests/smoke.sh
echo
echo "Solution applied."
