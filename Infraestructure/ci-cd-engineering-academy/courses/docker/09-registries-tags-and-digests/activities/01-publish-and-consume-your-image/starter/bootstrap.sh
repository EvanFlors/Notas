#!/usr/bin/env bash
# Bootstrap for dkr-09-01-publish-and-consume-your-image.
#
# Creates:
#   $BASE/repo/            git repo with Dockerfile + app.sh + 1 base commit
#   $BASE/publish/         empty staging area for DIGEST and tag-policy.md
#
# MODE=local (default): also ensures a local registry:2 is running on
#                       localhost:${REGISTRY_PORT:-5000}.
# MODE=live:            verifies gh auth status; does NOT push (student will).
set -euo pipefail

BASE="${1:-/tmp/dkr-09-publish}"
MODE="${MODE:-local}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

rm -rf "$BASE"
mkdir -p "$BASE/repo" "$BASE/publish"

REPO="$BASE/repo"
cd "$REPO"

cat > Dockerfile <<'EOF'
FROM alpine:3.20

LABEL org.opencontainers.image.title="publish-demo"
LABEL org.opencontainers.image.description="dkr-09 activity 01 — publish and consume"

COPY app.sh /app.sh
RUN chmod +x /app.sh

ENTRYPOINT ["/app.sh"]
EOF

cat > app.sh <<'EOF'
#!/bin/sh
# Payload identifiable: the validator greps for the first word.
echo "publish-demo | hostname=$(hostname) | date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
chmod +x app.sh

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
git add .
git commit -q -m "chore: scaffold publish-demo (base commit)"

echo "== Bootstrap OK =="
echo "Repo scratch:   $REPO"
echo "Publish stage:  $BASE/publish/"
echo "Git short SHA:  $(git -C "$REPO" rev-parse --short=7 HEAD)"

if [ "$MODE" = "local" ]; then
  REG_CONTAINER="dkr09-registry"
  if ! docker ps --format '{{.Names}}' | grep -qx "$REG_CONTAINER"; then
    echo
    echo "+ docker run -d --rm --name $REG_CONTAINER -p ${REGISTRY_PORT}:5000 registry:2"
    docker run -d --rm --name "$REG_CONTAINER" -p "${REGISTRY_PORT}:5000" registry:2 >/dev/null
    for _ in 1 2 3 4 5; do
      if curl -fsS "http://localhost:${REGISTRY_PORT}/v2/" >/dev/null 2>&1; then break; fi
      sleep 1
    done
    echo "registry:2 listo en localhost:${REGISTRY_PORT}"
  else
    echo "registry:2 ya estaba corriendo como '$REG_CONTAINER'."
  fi
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI no instalado." >&2; exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh no autenticado. Ejecuta: gh auth login -s write:packages" >&2; exit 2
  fi
  echo
  echo "gh auth OK. Despues de taggear y pushear, usa el OWNER:"
  echo "  OWNER=\$(gh api user -q .login)"
  echo "  REG=ghcr.io/\$OWNER/dkr-09-publish-demo"
  echo "y haz login:"
  echo "  gh auth token | docker login ghcr.io -u \"\$OWNER\" --password-stdin"
else
  echo "WARNING: MODE desconocido '$MODE' (usa 'local' o 'live'); continuando como 'local'." >&2
fi

echo
echo "Siguiente: sigue README seccion 5 (build, tag x4, push, DIGEST, pull por digest)."
