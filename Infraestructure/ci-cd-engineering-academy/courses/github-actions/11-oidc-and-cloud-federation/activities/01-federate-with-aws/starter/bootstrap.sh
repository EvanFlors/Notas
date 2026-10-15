#!/usr/bin/env bash
# Scaffolding for gha-11-01-federate-with-aws.
# NOTE: do NOT use `set -o pipefail` globally when piping into tools that may close early
# (e.g. grep -q, head, awk) — SIGPIPE from the producer side (git/ls/etc.) can be
# misreported as an error by the shell. See notes in the git-and-github/02 module.
set -eu

BASE="${1:-/tmp/gha-oidc}"
rm -rf "$BASE"
mkdir -p "$BASE/project/.github/workflows" "$BASE/project/docs"

cat > "$BASE/project/README.md" <<'EOF'
# OIDC federation to AWS — starter (gha-11-01)

Tareas:
1. Crear `trust-policy.json` con pin del sub por `environment:production`.
2. Crear `.github/workflows/deploy.yml` que asume el rol vía OIDC
   (sin AKIA, sin secrets.AWS_*, sin permissions: write-all, sin
   `id-token: write` top-level).
3. Crear `docs/oidc.md` explicando AssumeRoleWithWebIdentity, sub,
   OIDC provider y environment.

Validar:
  bash tests/validate.sh /tmp/gha-oidc
EOF

echo "Scaffolding listo en $BASE/project/"
ls -R "$BASE/project"
