#!/usr/bin/env bash
# Reproduces the reflog-rescue walkthrough end to end.
set -euo pipefail

BASE="${1:-/tmp/reflog-demo}"
rm -rf "$BASE" && mkdir -p "$BASE" && cd "$BASE"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "line 1" > notes.md
git add . && git commit -q -m "init: notes"

echo "line 2" >> notes.md
git add . && git commit -q -m "add: line 2"

echo "line 3" >> notes.md
git add . && git commit -q -m "add: line 3 (important work)"

echo "---- log antes del reset ----"
git log --oneline

echo "---- reset --hard HEAD~2 ----"
git reset --hard HEAD~2
git log --oneline

echo "---- reflog ----"
git reflog

LOST="$(git rev-parse HEAD@{1})"
echo "---- hash perdido: $LOST ----"
git cat-file -t "$LOST"

echo "---- rescate con reset --hard HEAD@{1} ----"
git reset --hard "HEAD@{1}"
git log --oneline
cat notes.md

echo "---- OK: trabajo recuperado ----"
echo "Limpieza: rm -rf $BASE"
