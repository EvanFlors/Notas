#!/usr/bin/env bash
# Reproduces a trunk-based "one day" timeline: two short-lived branches
# behind feature flags, both merged to main the same day.
set -euo pipefail

REPO="${1:-/tmp/tbd-timeline}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# ---------- Scaffold ----------
cat > flags.py <<'EOF'
FLAGS = {
    # all flags default to False; turn on per environment
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
git add .
git commit -q -m "init: scaffold flags.py + legacy app"

# ---------- Add flag entries (one chore commit per flag) ----------
cat > flags.py <<'EOF'
FLAGS = {
    "new_checkout": False,
}
EOF
git add flags.py && git commit -q -m "chore: raise flag entry for new_checkout (off)"

cat > flags.py <<'EOF'
FLAGS = {
    "new_checkout": False,
    "dark_mode": False,
}
EOF
git add flags.py && git commit -q -m "chore: raise flag entry for dark_mode (off)"

# ---------- 09:30 — feat/new-checkout (lives ~2h) ----------
git switch -q -c feat/new-checkout
cat > app.py <<'EOF'
from flags import FLAGS


def _new_checkout():
    # scaffolding for the new checkout; wired but gated
    return "new-checkout(v2)"


def _legacy_checkout():
    return "legacy-checkout"


def checkout():
    if FLAGS.get("new_checkout"):
        return _new_checkout()
    return _legacy_checkout()


def render():
    if FLAGS.get("dark_mode"):
        return "ui-dark"
    return "ui-light"
EOF
git add app.py
git commit -q -m "feat(checkout): new flow scaffolding behind flag"

git switch -q main
git merge -q --no-ff feat/new-checkout -m "merge: feat/new-checkout behind flag (off)"
git branch -d feat/new-checkout >/dev/null

# ---------- 14:00 — feat/dark-mode (lives ~1h) ----------
git switch -q -c feat/dark-mode
cat > app.py <<'EOF'
from flags import FLAGS


def _new_checkout():
    return "new-checkout(v2)"


def _legacy_checkout():
    return "legacy-checkout"


def checkout():
    if FLAGS.get("new_checkout"):
        return _new_checkout()
    return _legacy_checkout()


def _dark():
    return "ui-dark"


def _light():
    return "ui-light"


def render():
    if FLAGS.get("dark_mode"):
        return _dark()
    return _light()
EOF
git add app.py
git commit -q -m "feat(ui): dark mode scaffolding behind flag"

git switch -q main
git merge -q --no-ff feat/dark-mode -m "merge: feat/dark-mode behind flag (off)"
git branch -d feat/dark-mode >/dev/null

echo
echo "== Final DAG =="
git log --oneline --graph --all
echo
echo "== Branches alive =="
git branch -a
echo
echo "Done. main is deployable; both features in main behind OFF flags."
