#!/usr/bin/env bash
# Scaffolding for gh-13-03-oidc-federation-to-cloud.
set -euo pipefail

BASE="${1:-/tmp/oidc-fed}"
rm -rf "$BASE"
mkdir -p "$BASE/project/.github/workflows" "$BASE/project/docs"

cat > "$BASE/project/README.md" <<'EOF'
# OIDC federation to AWS — starter

Tareas:
1. Crear `trust-policy.json` con pin del sub al repo + environment.
2. Crear `.github/workflows/deploy.yml` que asume el rol vía OIDC.
3. Crear `docs/oidc.md` explicando el flujo.

Validar con:  bash tests/validate.sh /tmp/oidc-fed
EOF

echo "Scaffolding listo en $BASE/project/"
ls -R "$BASE/project"
