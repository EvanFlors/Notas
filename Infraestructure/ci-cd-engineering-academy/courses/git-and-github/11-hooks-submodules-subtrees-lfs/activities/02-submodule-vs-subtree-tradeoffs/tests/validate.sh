#!/usr/bin/env bash
# Validate gh-11-02-submodule-vs-subtree-tradeoffs.
# No `pipefail` on the whole script to avoid SIGPIPE on `git ... | grep -q`.

BASE="${1:-${BASE_DIR:-/tmp/adr-sub-vs-tree}}"
fail=0

echo "== Validating $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Build with starter/build-scenario.sh"
  exit 1
fi

# ---------------------------------------------------------
# 1) super-sub: must be a Git repo with a gitlink (160000)
#    in vendor/libgreet and a tracked .gitmodules
# ---------------------------------------------------------
SUB="$BASE/scratch/super-sub"
if [ ! -d "$SUB/.git" ]; then
  echo "  FAIL $SUB missing or not a Git repo"
  fail=$((fail+1))
else
  cd "$SUB"
  mode=$(git ls-tree HEAD vendor/libgreet 2>/dev/null | awk '{print $1}')
  if [ "$mode" = "160000" ]; then
    echo "  OK   super-sub: gitlink (mode 160000) in vendor/libgreet"
  else
    echo "  FAIL super-sub: vendor/libgreet mode is '$mode' (expected 160000 gitlink)"
    fail=$((fail+1))
  fi
  if git ls-tree HEAD .gitmodules 2>/dev/null | grep -q "blob"; then
    echo "  OK   super-sub: .gitmodules tracked"
  else
    echo "  FAIL super-sub: .gitmodules not tracked"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------
# 2) super-tree: a Git repo WITHOUT .gitmodules,
#    vendor/libgreet is a normal tree with greet.py as blob
# ---------------------------------------------------------
TREE="$BASE/scratch/super-tree"
if [ ! -d "$TREE/.git" ]; then
  echo "  FAIL $TREE missing or not a Git repo"
  fail=$((fail+1))
else
  cd "$TREE"
  mode=$(git ls-tree HEAD vendor/libgreet 2>/dev/null | awk '{print $1}')
  if [ "$mode" = "040000" ]; then
    echo "  OK   super-tree: vendor/libgreet is a tree (mode 040000)"
  else
    echo "  FAIL super-tree: vendor/libgreet mode is '$mode' (expected 040000 tree)"
    fail=$((fail+1))
  fi
  if [ -f .gitmodules ] || git ls-tree HEAD .gitmodules 2>/dev/null | grep -q "blob"; then
    echo "  FAIL super-tree: .gitmodules present (subtree should NOT have one)"
    fail=$((fail+1))
  else
    echo "  OK   super-tree: no .gitmodules"
  fi
  # greet.py must exist as blob under vendor/libgreet
  if git ls-tree -r HEAD -- vendor/libgreet/greet.py 2>/dev/null | grep -q "blob"; then
    echo "  OK   super-tree: vendor/libgreet/greet.py present as blob"
  else
    echo "  FAIL super-tree: vendor/libgreet/greet.py missing or not a blob"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------
# 3) ADR.md with required headings, decision marker, min size
# ---------------------------------------------------------
ADR="$BASE/ADR.md"
if [ ! -f "$ADR" ]; then
  echo "  FAIL ADR.md missing at $ADR"
  fail=$((fail+1))
else
  size=$(wc -c < "$ADR" | tr -d ' ')
  if [ "$size" -ge 1500 ]; then
    echo "  OK   ADR.md size: $size bytes (>=1500)"
  else
    echo "  FAIL ADR.md too short: $size bytes (expected >=1500)"
    fail=$((fail+1))
  fi

  missing_hdr=""
  for hdr in "## Status" "## Context" "## Decision" "## Rationale" "## Consequences" "## Alternatives considered" "## References"; do
    if ! grep -qxF "$hdr" "$ADR"; then
      missing_hdr+="  - '$hdr'"$'\n'
    fi
  done
  if [ -z "$missing_hdr" ]; then
    echo "  OK   ADR.md contains all required headings"
  else
    echo "  FAIL ADR.md missing headings:"
    printf "%s" "$missing_hdr"
    fail=$((fail+1))
  fi

  # Decision marker: exactly one of the three options
  n_sub=$(grep -c "^Use submodule\b" "$ADR" 2>/dev/null || true)
  n_tree=$(grep -c "^Use subtree\b" "$ADR" 2>/dev/null || true)
  n_mono=$(grep -c "^Use monorepo\b" "$ADR" 2>/dev/null || true)
  total=$((n_sub + n_tree + n_mono))
  if [ "$total" -ge 1 ]; then
    echo "  OK   ADR.md declares a decision (submodule=$n_sub, subtree=$n_tree, monorepo=$n_mono)"
  else
    echo "  FAIL ADR.md decision not declared. Expected one line starting with 'Use submodule', 'Use subtree', or 'Use monorepo'."
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
