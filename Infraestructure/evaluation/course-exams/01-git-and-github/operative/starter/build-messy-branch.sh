#!/usr/bin/env bash
# Exam operative starter — Git & GitHub certification.
# Builds a repo on branch feature/payments with 1 base commit + 5 messy commits.
# Adapted from courses/git-and-github/06-rebase-vs-merge-and-interactive/activities/01-squash-and-reorder.
set -euo pipefail

REPO="${1:-/tmp/exam-op}"

# --- Preflight: SKIP gracefully if required tools are missing ---
if ! command -v git >/dev/null 2>&1; then
  echo "SKIP: git not found in PATH. Install Git >= 2.30 to run this exercise." >&2
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found in PATH. Install Python 3 to run this exercise." >&2
  exit 0
fi

git_ver_major="$(git --version | awk '{print $3}' | cut -d. -f1)"
git_ver_minor="$(git --version | awk '{print $3}' | cut -d. -f2)"
if [ "$git_ver_major" -lt 2 ] || { [ "$git_ver_major" -eq 2 ] && [ "$git_ver_minor" -lt 30 ]; }; then
  echo "SKIP: git $(git --version) is below 2.30; this exercise expects >= 2.30." >&2
  exit 0
fi

rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Exam Candidate"
git config user.email "candidate@example.local"

# --- Base commit on main ---
cat > README.md <<'EOF'
# Payments module

Scaffold.
EOF
git add README.md
git commit -q -m "init: payments module scaffold"

# --- Feature branch with 5 messy commits ---
git switch -q -c feature/payments

cat > payments.py <<'EOF'
def refnd(amount):
    return {"status": "pending", "amount": amount}
EOF
git add payments.py
git commit -q -m "wip"

python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("refnd", "refund"))
PY
git commit -q -am "typo"

mkdir -p tests
cat > tests/test_payments.py <<'EOF'
from payments import refund


def test_refund_accepted():
    assert refund(10)["status"] == "accepted"
EOF
git add tests/test_payments.py
git commit -q -m "add tests"

python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
header = "# Copyright 2026 Exam Co. SPDX-License-Identifier: Apache-2.0\n"
p.write_text(header + p.read_text())
PY
git commit -q -am "oops forgot header"

python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("pending", "accepted"))
PY
git commit -q -am "fix typo again"

echo
echo "Exam repo ready at: $REPO"
echo "Branch:             $(git symbolic-ref --short HEAD)"
echo
git log --oneline
echo
echo "Goal: leave exactly 2 commits on top of 'init: payments module scaffold':"
echo "  - feat(payments): add refund processor   (payments.py only)"
echo "  - test(payments): cover refund processor (tests/ only)"
echo
echo "Validate with: bash operative/tests/validate.sh $REPO"
