#!/usr/bin/env bash
# Prepara el scaffolding para gh-13-02-sign-and-verify-commits.
# NO configura firma ni genera claves — esa es la tarea del estudiante.
set -euo pipefail

BASE="${1:-/tmp/sign-and-verify}"
rm -rf "$BASE"
mkdir -p "$BASE/keys" "$BASE/config" "$BASE/repo"

cd "$BASE/repo"
git init -q -b main

cat > README.md <<'EOF'
# Firmar commits con SSH — scaffolding

Repo vacío. Tu tarea:

1. Generar una clave SSH ed25519 en ../keys/signing_ed25519 (sin passphrase).
2. Configurar este repo (git config, LOCAL no global):
     gpg.format               = ssh
     user.name                = Student
     user.email               = student@example.com
     user.signingkey          = ../keys/signing_ed25519.pub (ruta absoluta)
     commit.gpgsign           = true
     tag.gpgsign              = true (opcional)
     gpg.ssh.allowedSignersFile = ../config/allowed_signers (ruta absoluta)
3. Crear ../config/allowed_signers con una línea:
     student@example.com <contenido-de-signing_ed25519.pub>
4. Hacer al menos 2 commits firmados en main.
5. Verificar: git log --show-signature
6. Validar: bash tests/validate.sh /tmp/sign-and-verify
EOF

echo "Scaffolding listo en $BASE."
echo "  repo:   $BASE/repo"
echo "  keys:   $BASE/keys  (vacío — tú lo rellenas)"
echo "  config: $BASE/config (vacío — tú lo rellenas)"
