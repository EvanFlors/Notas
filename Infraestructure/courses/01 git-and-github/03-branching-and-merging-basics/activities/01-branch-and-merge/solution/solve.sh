#!/usr/bin/env bash
# Reference solution for gh-03-01-branch-and-merge.
# Students should NOT run this before trying themselves.
#
# Usage:
#   bash starter/build-starter.sh /tmp/branch-merge
#   bash solution/solve.sh         /tmp/branch-merge
set -euo pipefail

BASE="${1:-/tmp/branch-merge}"
if [ ! -d "$BASE/.git" ]; then
  echo "FAIL: $BASE is not a Git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$BASE"

############################################################
# Task 1 — Fast-forward merge: fix typo on a branch, merge back.
############################################################
echo "---- Task 1: fast-forward ----"
git switch -q -c feature/typo-fix

# notes.md starts with '# Nootes' → fix to '# Notes'
# Use python for a portable in-place edit of just the first line.
python3 - <<'PY'
from pathlib import Path
p = Path("notes.md")
lines = p.read_text().splitlines(keepends=True)
if lines and lines[0].startswith("# Nootes"):
    lines[0] = "# Notes\n"
p.write_text("".join(lines))
PY

git add notes.md
git commit -q -m "fix: correct Notes title typo"

git switch -q main
git merge -q --ff-only feature/typo-fix
echo "After Task 1:"
git log --oneline main
echo

############################################################
# Task 2 — 3-way merge forced via --no-ff (both sides advance).
############################################################
echo "---- Task 2: --no-ff merge ----"
git switch -q -c feature/usage

# Append Usage section to notes.md on the feature branch.
cat >> notes.md <<'EOF'

## Usage

Run with `./notes.sh`.
EOF
git add notes.md
git commit -q -m "docs: add Usage section"

git switch -q main
# On main, create a different file (so the 3-way merge has no conflict).
cat > INSTALL.md <<'EOF'
# Install

Clone and run `./setup.sh`.
EOF
git add INSTALL.md
git commit -q -m "docs: add INSTALL.md"

# Force the merge commit even if FF were possible (it is not FF here — main advanced).
git merge -q --no-ff -m "Merge branch 'feature/usage'" feature/usage
echo "After Task 2:"
git log --graph --oneline --all --decorate
echo

############################################################
# Task 3 — 3-way merge with a conflict on the title line.
############################################################
echo "---- Task 3: conflict + resolve ----"
git switch -q -c feature/subtitle

# Change the first line to "# Notes — personal"
python3 - <<'PY'
from pathlib import Path
p = Path("notes.md")
lines = p.read_text().splitlines(keepends=True)
lines[0] = "# Notes — personal\n"
p.write_text("".join(lines))
PY
git add notes.md
git commit -q -m "docs: subtitle 'personal'"

git switch -q main
# Change the same first line to "# Notes — project"
python3 - <<'PY'
from pathlib import Path
p = Path("notes.md")
lines = p.read_text().splitlines(keepends=True)
lines[0] = "# Notes — project\n"
p.write_text("".join(lines))
PY
git add notes.md
git commit -q -m "docs: subtitle 'project'"

# Trigger the conflict (allow non-zero to continue the script).
set +e
git merge --no-edit feature/subtitle
MERGE_EXIT=$?
set -e
echo "Merge exited with $MERGE_EXIT (1 = conflict, expected)."

# Resolve: first line becomes "# Notes — personal project".
python3 - <<'PY'
from pathlib import Path
p = Path("notes.md")
text = p.read_text()
# Strip conflict markers block covering the first line.
# Rewrite the file assuming diff3-style markers around the first "line region".
lines = text.splitlines(keepends=True)
out = []
in_conflict = False
in_our = False
in_base = False
in_theirs = False
replaced = False
for ln in lines:
    s = ln.rstrip("\n")
    if s.startswith("<<<<<<<"):
        in_conflict = True
        in_our = True
        continue
    if s.startswith("|||||||") and in_conflict:
        in_our = False
        in_base = True
        continue
    if s == "=======" and in_conflict:
        in_base = False
        in_theirs = True
        continue
    if s.startswith(">>>>>>>") and in_conflict:
        in_conflict = False
        in_our = in_base = in_theirs = False
        if not replaced:
            out.append("# Notes — personal project\n")
            replaced = True
        continue
    if in_conflict:
        # skip; we'll emit our resolved line once at the end of the block
        continue
    out.append(ln)
p.write_text("".join(out))
PY

git add notes.md
git commit -q --no-edit

echo "After Task 3:"
git log --graph --oneline --all --decorate
echo

echo "Done. Run tests/validate.sh to verify."
