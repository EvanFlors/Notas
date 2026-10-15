#!/usr/bin/env bash
# Build the starter repo for gh-08-01-simulate-trunk-based.
# Produces a single initial commit on main with an empty FLAGS dict and a
# legacy app + smoke test. The student will add two features behind flags.
set -euo pipefail

REPO="${1:-/tmp/tbd-sim}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

mkdir -p tests

cat > flags.py <<'EOF'
# Feature flags for the app. All default to OFF.
# Pattern: FLAGS = {"flag_name": False, ...}
FLAGS = {}
EOF

cat > app.py <<'EOF'
from flags import FLAGS


def checkout():
    # Legacy checkout. New flow will land here behind FLAGS["new_checkout"].
    return "legacy-checkout"


def render():
    # Legacy UI. Dark mode will land here behind FLAGS["dark_mode"].
    return "ui-light"
EOF

cat > tests/smoke.sh <<'SMOKE'
#!/usr/bin/env bash
# Minimal smoke test: main must always keep legacy behavior with flags OFF.
set -euo pipefail

python3 - <<'PY'
import sys
sys.path.insert(0, ".")
from flags import FLAGS
from app import checkout, render

# All flags must default to OFF in main (deploy != release).
assert all(v is False for v in FLAGS.values()), f"flags not all False: {FLAGS}"

# Legacy behavior must still be the default.
assert checkout() == "legacy-checkout", f"checkout()={checkout()!r}"
assert render() == "ui-light", f"render()={render()!r}"
print("smoke OK")
PY
SMOKE
chmod +x tests/smoke.sh

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
EOF

cat > README.md <<'EOF'
# tbd-sim

Starter repo for gh-08-01-simulate-trunk-based.
Build two features behind OFF flags, both merged to main the same day.
EOF

git add .
git commit -q -m "init: scaffold trunk-based repo"

echo "Starter repo built at: $REPO"
echo "Open README.md in the activity for next steps."
