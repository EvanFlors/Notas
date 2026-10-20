#!/usr/bin/env bash
# Reference solution for gh-02-01-atomic-commits.
# Produces 5 atomic commits using separate per-file edits
# (the real activity should use `git add -p` interactively on the dirty state;
#  this script instead reconstructs the same final content commit-by-commit).

set -euo pipefail

REPO="${1:-/tmp/atomic-commits}"

# Rebuild the base state fresh
bash "$(dirname "$0")/../starter/build-dirty-repo.sh" "$REPO"

cd "$REPO"
# Reset the dirty working tree to base so we re-build commits from scratch
git checkout -q -- .
rm -rf tests/__pycache__ app/__pycache__ 2>/dev/null || true

# --- Commit 1: fix typo in divide() ---
python3 - <<'EOF'
import pathlib
p = pathlib.Path("app/calculator.py")
p.write_text(p.read_text().replace("Cannt divide", "Cannot divide"))
EOF
git add app/calculator.py
git commit -q -m "fix: correct typo in divide() error message"

# --- Commit 2: refactor add() and multiply() with type hints + docstrings ---
cat > app/calculator.py <<'EOF'
def add(a: int, b: int) -> int:
    """Return the sum of two ints."""
    return a + b


def multiply(a: int, b: int) -> int:
    """Return the product of two ints."""
    return a * b


def divide(a: float, b: float) -> float:
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b
EOF
git add app/calculator.py
git commit -q -m "refactor: type-annotate and document add/multiply"

# --- Commit 3: refactor divide() with float type hints ---
python3 - <<'EOF'
import pathlib
p = pathlib.Path("app/calculator.py")
text = p.read_text()
# already updated in commit 2 if we included divide types; keep it minimal here
EOF
# nothing needed; keep as separate semantic step if desired, but we already included
# in commit 2 (acceptable). Alternatively, split: here we keep it merged.

# --- Commit 4: feat: subtract() ---
cat >> app/calculator.py <<'EOF'


def subtract(a: int, b: int) -> int:
    """Return a - b."""
    return a - b
EOF
git add app/calculator.py
git commit -q -m "feat: add subtract() helper"

# --- Commit 5: test: subtract tests + import update ---
cat > tests/test_calculator.py <<'EOF'
from app.calculator import add, multiply, subtract


def test_add():
    assert add(2, 3) == 5


def test_multiply():
    assert multiply(3, 4) == 12


def test_subtract():
    assert subtract(10, 4) == 6
EOF
git add tests/test_calculator.py
git commit -q -m "test: cover subtract()"

# --- Commit 6: chore: logging config tweaks ---
cat > app/config.py <<'EOF'
LOG_LEVEL = "WARNING"
LOG_FORMAT = "%(levelname)s - %(message)s"
LOG_FILE = "/var/log/app.log"
EOF
git add app/config.py
git commit -q -m "chore(config): raise log level to WARNING and add LOG_FILE"

echo
echo "Reference history produced:"
git log --oneline
