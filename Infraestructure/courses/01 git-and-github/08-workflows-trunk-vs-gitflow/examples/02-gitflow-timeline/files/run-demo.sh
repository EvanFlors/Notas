#!/usr/bin/env bash
# Reproduces a full GitFlow cycle: 2 features -> develop -> release/1.0.0
# -> main (tag v1.0.0) + hotfix/typo -> main (tag v1.0.1). Both the release
# and the hotfix are merged back to develop as well — the classic double merge.
set -euo pipefail

REPO="${1:-/tmp/gitflow-timeline}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# ---------- Initial state on main ----------
cat > app.py <<'EOF'
VERSION = "0.1.0"


def greet():
    return "Hello from app"
EOF
cat > README.md <<'EOF'
# demo-app

Example GitFlow repository.
EOF
git add .
git commit -q -m "init: scaffold app and README"
git tag v0.1.0

# ---------- develop branches off main ----------
git switch -q -c develop

# ---------- feature/auth ----------
git switch -q -c feature/auth
cat >> app.py <<'EOF'


def login(user, password):
    # placeholder
    return True
EOF
git add app.py && git commit -q -m "feat(auth): add login placeholder"

git switch -q develop
git merge -q --no-ff feature/auth -m "merge: feature/auth into develop"
git branch -d feature/auth >/dev/null

# ---------- feature/payments ----------
git switch -q -c feature/payments
cat >> app.py <<'EOF'


def charge(amount):
    return f"charged:{amount}"
EOF
git add app.py && git commit -q -m "feat(payments): add charge() placeholder"
cat >> app.py <<'EOF'


def refund(amount):
    return f"refunded:{amount}"
EOF
git add app.py && git commit -q -m "feat(payments): add refund() placeholder"

git switch -q develop
git merge -q --no-ff feature/payments -m "merge: feature/payments into develop"
git branch -d feature/payments >/dev/null

# ---------- release/1.0.0 branched from develop ----------
git switch -q -c release/1.0.0

# bump version in release branch (classic GitFlow)
sed -i.bak 's/VERSION = "0.1.0"/VERSION = "1.0.0"/' app.py && rm -f app.py.bak
git add app.py && git commit -q -m "chore(release): bump version to 1.0.0"

# QA finds a bug during stabilization — fixed in release/* only
cat >> app.py <<'EOF'


def _qa_sanity_check():
    # QA-reported edge case fix during 1.0.0 stabilization
    return "ok"
EOF
git add app.py && git commit -q -m "fix(release-1.0.0): QA sanity check"

# ---------- Merge release/1.0.0 into main and tag ----------
git switch -q main
git merge -q --no-ff release/1.0.0 -m "merge: release/1.0.0 into main"
git tag -a v1.0.0 -m "Release 1.0.0"

# ---------- Merge release/1.0.0 BACK into develop (the double merge!) ----------
git switch -q develop
git merge -q --no-ff release/1.0.0 -m "merge: release/1.0.0 back into develop"

# Clean up release branch
git branch -d release/1.0.0 >/dev/null

# ---------- hotfix/typo-greet branched from main ----------
git switch -q main
git switch -q -c hotfix/typo-greet
sed -i.bak 's/Hello from app/Hello from the app/' app.py && rm -f app.py.bak
# bump patch version
sed -i.bak 's/VERSION = "1.0.0"/VERSION = "1.0.1"/' app.py && rm -f app.py.bak
git add app.py && git commit -q -m "fix(greet): typo in greeting (v1.0.1)"

# Merge hotfix into main and tag
git switch -q main
git merge -q --no-ff hotfix/typo-greet -m "merge: hotfix/typo-greet into main"
git tag -a v1.0.1 -m "Hotfix 1.0.1"

# Merge hotfix BACK into develop (the second double merge!)
git switch -q develop
git merge -q --no-ff hotfix/typo-greet -m "merge: hotfix/typo-greet back into develop"

git branch -d hotfix/typo-greet >/dev/null

# ---------- Report ----------
echo
echo "== Branches alive =="
git branch -a
echo
echo "== Tags =="
git tag -l
echo
echo "== Final DAG =="
git log --oneline --graph --all --decorate
echo
echo "Done. Count merges and compare to example 01."
