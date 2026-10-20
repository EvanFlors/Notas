#!/usr/bin/env bash
# Build a repo on branch feature/payments with 1 base commit + 5 messy commits.
set -euo pipefail

REPO="${1:-/tmp/squash-and-reorder}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# --- Base commit on main ---
cat > README.md <<'EOF'
# Payments module

Scaffold.
EOF
git add README.md
git commit -q -m "init: payments module scaffold"

# --- Switch to feature branch ---
git switch -q -c feature/payments

# commit 1: wip (scaffold payments.py with a typo in the function name)
cat > payments.py <<'EOF'
def refnd(amount):
    return {"status": "pending", "amount": amount}
EOF
git add payments.py
git commit -q -m "wip"

# commit 2: typo (fix refnd -> refund)
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("refnd", "refund"))
PY
git commit -q -am "typo"

# commit 3: add tests
mkdir -p tests
cat > tests/test_payments.py <<'EOF'
from payments import refund


def test_refund_accepted():
    assert refund(10)["status"] == "accepted"
EOF
git add tests/test_payments.py
git commit -q -m "add tests"

# commit 4: oops forgot header (prepend a license header to payments.py)
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
header = "# Copyright 2026 Acme Inc. SPDX-License-Identifier: Apache-2.0\n"
p.write_text(header + p.read_text())
PY
git commit -q -am "oops forgot header"

# commit 5: fix typo again (change "pending" to "accepted" so tests pass)
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("pending", "accepted"))
PY
git commit -q -am "fix typo again"

echo
echo "Repo listo en: $REPO"
echo "Rama actual:  $(git symbolic-ref --short HEAD)"
echo
git log --oneline
echo
echo "Objetivo: 2 commits sobre 'init: payments module scaffold':"
echo "  - feat(payments): add refund processor"
echo "  - test(payments): cover refund processor"
echo
echo "Lee README.md para la guia. Valida con tests/validate.sh."
