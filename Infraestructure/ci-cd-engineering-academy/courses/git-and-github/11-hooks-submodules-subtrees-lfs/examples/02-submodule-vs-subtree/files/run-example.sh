#!/usr/bin/env bash
# Side-by-side demo of integrating the same upstream repo as a submodule and as a subtree.
set -u

BASE="${1:-/tmp/sm-vs-st}"
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

gc() { git -c user.name=Demo -c user.email=demo@example.com "$@"; }

# --- 0) upstream repo ---
echo "== Building upstream repo at $BASE/upstream =="
mkdir upstream && cd upstream
git init -q -b main
cat > greet.py <<'EOF'
def greet(name: str) -> str:
    return f"Hello, {name}!"
EOF
cat > README.md <<'EOF'
# libgreet
A trivial greeting library.
EOF
gc add .
gc commit -q -m "init: libgreet"

cat >> greet.py <<'EOF'


def shout(text: str) -> str:
    return text.upper()
EOF
gc add greet.py
gc commit -q -m "feat: add shout"

echo "VERSION = \"0.2.0\"" > version.py
gc add version.py
gc commit -q -m "chore: tag version 0.2.0"
cd ..

# --- 1) super-sub (SUBMODULE) ---
echo
echo "== Building super-sub (SUBMODULE) =="
mkdir super-sub && cd super-sub
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
gc add app.py
gc commit -q -m "init: super app"

gc -c protocol.file.allow=always submodule add -q "$BASE/upstream" vendor/libgreet
gc commit -q -m "chore: add libgreet as submodule"
cd ..

# --- 2) super-tree (SUBTREE) ---
echo "== Building super-tree (SUBTREE) =="
mkdir super-tree && cd super-tree
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
gc add app.py
gc commit -q -m "init: super app"

gc subtree add --prefix=vendor/libgreet "$BASE/upstream" main --squash -q
cd ..

# --- 3) Inspect both ---
echo
echo "============================================================"
echo "=== super-sub (SUBMODULE) ==="
echo "============================================================"
cd "$BASE/super-sub"
echo "-- git ls-tree HEAD vendor/ --"
git ls-tree HEAD vendor/
echo
echo "-- cat .gitmodules --"
cat .gitmodules
echo
echo "-- git log --oneline (only super history; submodule history is separate) --"
git log --oneline

echo
echo "============================================================"
echo "=== super-tree (SUBTREE) ==="
echo "============================================================"
cd "$BASE/super-tree"
echo "-- git ls-tree HEAD vendor/ --"
git ls-tree HEAD vendor/
echo
echo "-- .gitmodules exists? --"
if [ -f .gitmodules ]; then
  cat .gitmodules
else
  echo "(no .gitmodules — this is a subtree, not a submodule)"
fi
echo
echo "-- git log --oneline (includes squashed subtree commit) --"
git log --oneline

# --- 4) Reclone both and show the submodule-empty gotcha ---
echo
echo "============================================================"
echo "=== Recloning both (no --recurse-submodules) ==="
echo "============================================================"
cd "$BASE"
git -c protocol.file.allow=always clone -q super-sub reclone-sub
git -c protocol.file.allow=always clone -q super-tree reclone-tree

echo
echo "-- reclone-sub/vendor/libgreet contents --"
ls -la reclone-sub/vendor/libgreet || true
if [ -z "$(ls -A reclone-sub/vendor/libgreet 2>/dev/null)" ]; then
  echo "  → EMPTY. Fix: cd reclone-sub && git submodule update --init --recursive"
else
  echo "  → not empty (something odd)"
fi

echo
echo "-- reclone-tree/vendor/libgreet contents --"
ls reclone-tree/vendor/libgreet

echo
echo "Done. Cleanup: rm -rf $BASE"
