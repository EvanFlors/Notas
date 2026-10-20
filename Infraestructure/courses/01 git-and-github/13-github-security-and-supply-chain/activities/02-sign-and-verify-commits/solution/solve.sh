#!/usr/bin/env bash
# Reference solution for gh-13-02-sign-and-verify-commits.
# Usage: ./solve.sh [BASE_DIR]
set -euo pipefail

BASE="${1:-/tmp/sign-and-verify}"
if [ ! -d "$BASE/repo/.git" ]; then
  echo "FAIL: $BASE/repo is not a git repo. Run starter/bootstrap.sh first."
  exit 1
fi

EMAIL="student@example.com"
KEY="$BASE/keys/signing_ed25519"
ALLOWED="$BASE/config/allowed_signers"

# 1) Generar clave de firma dedicada (sin passphrase)
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -C "git-signing" -f "$KEY" -N "" >/dev/null
fi

# 2) Preparar allowed_signers
mkdir -p "$(dirname "$ALLOWED")"
printf '%s %s\n' "$EMAIL" "$(cat "${KEY}.pub")" > "$ALLOWED"

# 3) Configurar repo (LOCAL — no --global)
cd "$BASE/repo"
git config user.name  "Student"
git config user.email "$EMAIL"
git config gpg.format ssh
git config user.signingkey "${KEY}.pub"
git config commit.gpgsign true
git config tag.gpgsign true
git config gpg.ssh.allowedSignersFile "$ALLOWED"

# 4) Hacer >= 2 commits firmados
echo "# Signed repo" > docs.md
git add docs.md
git commit -q -m "docs: add project docs"

cat > app.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from signed app"
EOF
chmod +x app.sh
git add app.sh
git commit -q -m "feat: add app.sh"

echo
echo "---- git log --show-signature ----"
git log --show-signature -n2
echo
echo "Done."
