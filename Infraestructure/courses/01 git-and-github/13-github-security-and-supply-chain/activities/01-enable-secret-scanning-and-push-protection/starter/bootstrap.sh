#!/usr/bin/env bash
# Scaffolding for gh-13-01-enable-secret-scanning-and-push-protection.
set -euo pipefail

BASE="${1:-/tmp/sec-scanning}"
rm -rf "$BASE"
mkdir -p "$BASE/repo"

cd "$BASE/repo"
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# SECURITY.md incompleto (el estudiante lo rellena)
cat > SECURITY.md <<'EOF'
# Security Policy

<!--
TODO: Completa las 3 secciones siguientes.
Las secciones son requeridas por el validador (headers con los nombres exactos).
-->

## Reporting

<!-- TODO: Describe cómo reportar vulnerabilidades (vía Private Vulnerability
Reporting en GitHub: Security -> Advisories -> Report a vulnerability). -->

## Controls

<!-- TODO: Lista los controles de seguridad activos en este repo
(secret scanning + push protection, firma de commits, Dependabot, OIDC, etc.). -->

## Rotation

<!-- TODO: Describe la política de rotación de credenciales inevitables. -->
EOF

cat > README.md <<'EOF'
# Repo de prueba — secret scanning + push protection

Tareas:

1. Escribe un hook en .git/hooks/pre-commit (bash, ejecutable) que bloquee
   commits que contengan patrones de secretos típicos.
2. Completa SECURITY.md (headers Reporting / Controls / Rotation).
3. (Opcional MODE=live) Habilita en GitHub con:
     gh api -X PATCH /repos/OWNER/REPO \
       -f security_and_analysis.secret_scanning.status=enabled \
       -f security_and_analysis.secret_scanning_push_protection.status=enabled
4. Valida con: bash tests/validate.sh /tmp/sec-scanning
EOF
git add README.md SECURITY.md
git commit -q -m "chore: initial scaffolding"

echo "Scaffolding listo en $BASE."
