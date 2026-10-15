#!/usr/bin/env bash
# Builds the starter repo for gh-03-02-resolve-nontrivial-conflict.
# Three branches diverge from a base commit; feature/caching and feature/retries
# both touch config.yaml, app.py, and README.md in incompatible but composable ways.
set -euo pipefail

BASE="${1:-/tmp/nontrivial}"
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
git config merge.conflictStyle diff3

############################################################
# Base commit: skeleton used by all three branches.
############################################################
cat > config.yaml <<'EOF'
timeout: 30
retries: 0
cache: false
log_level: info
EOF

cat > app.py <<'EOF'
def make_client(cfg):
    client = Client(timeout=cfg["timeout"])
    return client
EOF

cat > README.md <<'EOF'
# Project

A tiny HTTP client wrapper.

## Features

(none yet)
EOF

git add config.yaml app.py README.md
git commit -q -m "init: project skeleton"

############################################################
# One extra commit on main (so the first merge is a real 3-way too).
############################################################
cat > CHANGELOG.md <<'EOF'
# Changelog

- Baseline release.
EOF
git add CHANGELOG.md
git commit -q -m "chore: baseline"

BASE_HASH="$(git rev-parse HEAD~1)"       # init: project skeleton
MAIN_HASH="$(git rev-parse HEAD)"         # chore: baseline

############################################################
# feature/caching — starts from BASE (init: project skeleton)
############################################################
git switch -q -c feature/caching "$BASE_HASH"

cat > config.yaml <<'EOF'
timeout: 30
retries: 0
cache: true
log_level: info
EOF

cat > app.py <<'EOF'
def make_client(cfg):
    client = Client(timeout=cfg["timeout"])
    if cfg.get("cache"):
        client = CachingClient(client)
    return client
EOF

cat > README.md <<'EOF'
# Project

A tiny HTTP client wrapper.

## Features

- Caching: in-memory response cache
EOF

git add config.yaml app.py README.md
git commit -q -m "feat: enable caching in config and app"

############################################################
# feature/retries — also starts from BASE
############################################################
git switch -q -c feature/retries "$BASE_HASH"

cat > config.yaml <<'EOF'
timeout: 30
retries: 3
cache: false
log_level: info
EOF

cat > app.py <<'EOF'
def make_client(cfg):
    client = Client(timeout=cfg["timeout"])
    if cfg.get("retries", 0) > 0:
        client = RetryingClient(client, attempts=cfg["retries"])
    return client
EOF

cat > README.md <<'EOF'
# Project

A tiny HTTP client wrapper.

## Features

- Retries: automatic retry on transient failures
EOF

git add config.yaml app.py README.md
git commit -q -m "feat: enable retries in config and app"

############################################################
# Return to main.
############################################################
git switch -q main

echo "Starter ready at: $BASE"
echo
git log --graph --oneline --all --decorate
