#!/usr/bin/env bash
# Build a scratch repo with 1 base commit and a dirty working tree with
# 3 modified files mixing ~5 unrelated changes.
set -euo pipefail

REPO="${1:-/tmp/atomic-commits}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# ---------- Base state (committed) ----------
mkdir -p app tests
cat > app/calculator.py <<'EOF'
def add(a, b):
    return a + b


def multiply(a, b):
    return a * b


def divide(a, b):
    if b == 0:
        raise ValueError("Cannt divide by zero")
    return a / b
EOF

cat > app/config.py <<'EOF'
LOG_LEVEL = "DEBUG"
LOG_FORMAT = "%(levelname)s - %(message)s"
EOF

cat > tests/test_calculator.py <<'EOF'
from app.calculator import add, multiply


def test_add():
    assert add(2, 3) == 5


def test_multiply():
    assert multiply(3, 4) == 12
EOF

cat > .gitignore <<'EOF'
__pycache__/
.venv/
EOF

git add .
git commit -q -m "init: base state"

# ---------- Dirty state (not committed) ----------
# All 5 intents mixed into 3 files:
#   (1) refactor: type hints + docstring in add() and multiply()
#   (2) fix: typo "Cannt" -> "Cannot" in divide()
#   (3) feat: subtract() function
#   (4) test: subtract tests
#   (5) chore: raise log level WARNING; add LOG_FILE path

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


def subtract(a: int, b: int) -> int:
    """Return a - b."""
    return a - b
EOF

cat > app/config.py <<'EOF'
LOG_LEVEL = "WARNING"
LOG_FORMAT = "%(levelname)s - %(message)s"
LOG_FILE = "/var/log/app.log"
EOF

cat > tests/test_calculator.py <<'EOF'
from app.calculator import add, multiply, subtract


def test_add():
    assert add(2, 3) == 5


def test_multiply():
    assert multiply(3, 4) == 12


def test_subtract():
    assert subtract(10, 4) == 6
EOF

echo "Dirty repo built at: $REPO"
git status
echo
echo "Modified files contain ~5 unrelated changes. Produce >=4 atomic commits."
echo "See README.md for guidance."
