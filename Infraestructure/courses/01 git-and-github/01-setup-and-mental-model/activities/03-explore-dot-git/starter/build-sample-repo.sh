#!/usr/bin/env bash
# Builds a sample repo for gh-01-03-explore-dot-git.
# Features:
#   - 3 commits on main (with varied content)
#   - 1 feature branch "feature/x" diverging after commit 2
#   - 1 annotated tag v0.1 on commit 2
#   - .git/info/exclude populated with a sample entry
#   - No git gc run (so loose objects remain visible)

set -euo pipefail

REPO="${1:-/tmp/explore-dot-git}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Explorer"
git config user.email "explorer@example.com"

# --- commit 1 on main ---
cat > README.md <<'EOF'
# Sample

Un repo para explorar `.git/`.
EOF
git add README.md
git commit -q -m "init: README mínimo"

# --- commit 2 on main ---
mkdir -p src
cat > src/app.py <<'EOF'
def run() -> str:
    return "hola"
EOF
git add src/app.py
git commit -q -m "feat: src/app.py"

# Annotated tag on commit 2
git tag -a v0.1 -m "primera versión"

# --- commit 3 on main ---
echo "- Nota: todo-list" >> README.md
git add README.md
git commit -q -m "docs: añade nota al README"

# --- feature/x diverging from commit 2 ---
git checkout -q -b feature/x v0.1   # branch desde el tag (= commit 2)
mkdir -p feature
cat > feature/future.md <<'EOF'
# Idea

Explorar algo en el futuro.
EOF
git add feature/future.md
git commit -q -m "feat(feature/x): borrador de idea"

# Volver a main
git checkout -q main

# .git/info/exclude: pattern local no versionado
cat >> .git/info/exclude <<'EOF'

# Ignorar basura del editor (ejemplo para la actividad)
*.swp
.DS_Store
EOF

# Summary
echo "Sample repo built at: $REPO"
echo
echo "Branches:"
git branch -a
echo
echo "Tags:"
git tag -l
echo
echo "Log main:"
git log --oneline main
echo
echo "Log feature/x:"
git log --oneline feature/x
echo
echo "Objects (loose) count: $(find .git/objects -type f -not -path '*/pack/*' | wc -l | tr -d ' ')"
