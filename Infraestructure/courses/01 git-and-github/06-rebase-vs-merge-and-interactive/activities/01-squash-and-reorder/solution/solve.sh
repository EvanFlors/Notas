#!/usr/bin/env bash
# Reference solution for gh-06-01-squash-and-reorder.
# Rebuilds the starter and performs a fully-automated interactive rebase.
set -euo pipefail

REPO="${1:-/tmp/squash-and-reorder}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# Rebuild starter
bash "$SELF_DIR/../starter/build-messy-branch.sh" "$REPO"
cd "$REPO"

# Plan: reorder so that the 3 fixups land immediately after the "wip" pick,
# then reword both picks (wip -> feat..., add tests -> test...).
PLAN_FILE="$(mktemp)"
cat > "$PLAN_FILE" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
todo="$1"

line_wip=""
line_typo=""
line_tests=""
line_header=""
line_typo2=""
while IFS= read -r l; do
  case "$l" in
    *" wip")                   line_wip="$l" ;;
    *" typo")                  line_typo="$l" ;;
    *" add tests")             line_tests="$l" ;;
    *" oops forgot header")    line_header="$l" ;;
    *" fix typo again")        line_typo2="$l" ;;
  esac
done < <(grep -E '^(pick|p) ' "$todo")

{
  echo "reword ${line_wip#pick }"
  echo "fixup ${line_typo#pick }"
  echo "fixup ${line_header#pick }"
  echo "fixup ${line_typo2#pick }"
  echo "reword ${line_tests#pick }"
} > "$todo"
SH
chmod +x "$PLAN_FILE"

# Message editor: translate the current first line into our chosen subject.
MSG_FILE="$(mktemp)"
cat > "$MSG_FILE" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
msgfile="$1"
first=$(head -n1 "$msgfile" || true)
case "$first" in
  wip)         new="feat(payments): add refund processor" ;;
  "add tests") new="test(payments): cover refund processor" ;;
  *)           new="$first" ;;
esac
tmp="${msgfile}.new"
printf "%s\n" "$new" > "$tmp"
tail -n +2 "$msgfile" >> "$tmp" || true
mv "$tmp" "$msgfile"
SH
chmod +x "$MSG_FILE"

GIT_SEQUENCE_EDITOR="$PLAN_FILE" \
GIT_EDITOR="$MSG_FILE" \
  git rebase -i HEAD~5

rm -f "$PLAN_FILE" "$MSG_FILE"

echo
echo "===== Resultado ====="
git log --oneline
echo
echo "Branch: $(git symbolic-ref --short HEAD)"
echo "Working tree:"
git status --short || true
