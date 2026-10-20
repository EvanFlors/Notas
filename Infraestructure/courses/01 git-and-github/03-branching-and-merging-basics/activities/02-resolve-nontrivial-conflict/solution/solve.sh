#!/usr/bin/env bash
# Reference solution for gh-03-02-resolve-nontrivial-conflict.
# Students should NOT run this before trying themselves.
set -euo pipefail

BASE="${1:-/tmp/nontrivial}"
if [ ! -d "$BASE/.git" ]; then
  echo "FAIL: $BASE is not a Git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$BASE"

############################################################
# First merge: feature/caching → main
# Expected: real 3-way merge, no conflicts because main's change
# (CHANGELOG.md) touches a different file.
############################################################
echo "---- Merge #1: feature/caching ----"
git switch -q main
git merge -q --no-ff -m "Merge branch 'feature/caching'" feature/caching
echo "After merge #1:"
git log --oneline main | head -5
echo

############################################################
# Second merge: feature/retries → main
# Expected: conflicts in config.yaml, app.py, README.md.
############################################################
echo "---- Merge #2: feature/retries (expect conflicts) ----"
set +e
git merge --no-ff -m "Merge branch 'feature/retries'" feature/retries
MERGE_EXIT=$?
set -e
echo "merge exit=$MERGE_EXIT (1 = conflict expected)"

# Resolve config.yaml — both cache: true and retries: 3.
cat > config.yaml <<'EOF'
timeout: 30
retries: 3
cache: true
log_level: info
EOF

# Resolve app.py — compose both wrappers.
cat > app.py <<'EOF'
def make_client(cfg):
    client = Client(timeout=cfg["timeout"])
    if cfg.get("cache"):
        client = CachingClient(client)
    if cfg.get("retries", 0) > 0:
        client = RetryingClient(client, attempts=cfg["retries"])
    return client
EOF

# Resolve README.md — both bullets, alphabetical.
cat > README.md <<'EOF'
# Project

A tiny HTTP client wrapper.

## Features

- Caching: in-memory response cache
- Retries: automatic retry on transient failures
EOF

git add config.yaml app.py README.md
git commit -q --no-edit

echo "After merge #2:"
git log --graph --oneline --all --decorate
echo

# Deliverable: write the graph to docs/graph.txt
mkdir -p docs
git log --graph --oneline --all --decorate > docs/graph.txt
git add docs/graph.txt
git commit -q -m "docs: add DAG snapshot" || true

echo "Done. Run tests/validate.sh to verify."
