#!/usr/bin/env bash
# Reference solution for gh-08-02-simulate-gitflow.
set -euo pipefail

REPO="${1:-/tmp/gitflow-sim}"
if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$REPO"

# Create develop from main
git switch -q -c develop

# ---------- feature/greet-name ----------
git switch -q -c feature/greet-name
cat > app.py <<'EOF'
VERSION = "0.1.0"


def greet(name=None):
    if name:
        return f"Hello, {name}"
    return "Hello from app"
EOF
git add app.py && git commit -q -m "feat(greet): accept optional name"

git switch -q develop
git merge -q --no-ff feature/greet-name -m "merge: feature/greet-name into develop"
git branch -d feature/greet-name >/dev/null

# ---------- feature/farewell ----------
git switch -q -c feature/farewell
cat > app.py <<'EOF'
VERSION = "0.1.0"


def greet(name=None):
    if name:
        return f"Hello, {name}"
    return "Hello from app"


def farewell():
    return "Bye"
EOF
git add app.py && git commit -q -m "feat(farewell): add farewell()"

git switch -q develop
git merge -q --no-ff feature/farewell -m "merge: feature/farewell into develop"
git branch -d feature/farewell >/dev/null

# ---------- release/1.0.0 ----------
git switch -q -c release/1.0.0 develop

cat > app.py <<'EOF'
VERSION = "1.0.0"


def greet(name=None):
    if name:
        return f"Hello, {name}"
    return "Hello from app"


def farewell():
    return "Bye"
EOF
git add app.py && git commit -q -m "chore(release): bump version to 1.0.0"

cat > app.py <<'EOF'
VERSION = "1.0.0"


def greet(name=None):
    if name:
        return f"Hello, {name}"
    return "Hello from app"


def farewell():
    return "Bye"


def _qa_check():
    return "ok"
EOF
git add app.py && git commit -q -m "fix(release-1.0.0): QA edge case"

# Merge release into main + tag
git switch -q main
git merge -q --no-ff release/1.0.0 -m "merge: release/1.0.0 into main"
git tag -a v1.0.0 -m "Release 1.0.0"

# Merge release BACK into develop
git switch -q develop
git merge -q --no-ff release/1.0.0 -m "merge: release/1.0.0 back into develop"

git branch -d release/1.0.0 >/dev/null

# ---------- hotfix/typo ----------
git switch -q -c hotfix/typo main
cat > app.py <<'EOF'
VERSION = "1.0.1"


def greet(name=None):
    if name:
        return f"Hello, {name}"
    return "Hello from the app"


def farewell():
    return "Bye"


def _qa_check():
    return "ok"
EOF
git add app.py && git commit -q -m "fix(greet): fix typo in default greeting (v1.0.1)"

git switch -q main
git merge -q --no-ff hotfix/typo -m "merge: hotfix/typo into main"
git tag -a v1.0.1 -m "Hotfix 1.0.1"

git switch -q develop
git merge -q --no-ff hotfix/typo -m "merge: hotfix/typo back into develop"

git branch -d hotfix/typo >/dev/null

echo
echo "== Final DAG =="
git log --oneline --graph --all --decorate
echo
echo "== Branches =="
git branch -a
echo
echo "== Tags =="
git tag -l
echo
echo "Solution applied."
