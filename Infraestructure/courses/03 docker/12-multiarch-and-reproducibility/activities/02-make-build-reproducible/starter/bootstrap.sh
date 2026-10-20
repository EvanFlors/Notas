#!/usr/bin/env bash
# Bootstrap for dkr-12-02-make-build-reproducible.
# Creates /tmp/dkr-12-repro/app/Dockerfile that is deliberately NON-reproducible.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/dkr-12-repro}}"
APP="$BASE/app"

if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx no esta disponible." >&2
  exit 2
fi

rm -rf "$BASE"
mkdir -p "$APP"

cat > "$APP/Dockerfile" <<'EOF'
# NON-REPRODUCIBLE on purpose. Fuentes de drift:
#   - Base por tag flotante (sin digest).
#   - 'RUN date' escribe el timestamp actual en una capa.
#   - 'apk add --no-cache curl' sin pin de version (metadata de red muta).
# El estudiante debe reescribirlo para que dos builds den el mismo digest.
FROM alpine:3.20
RUN date > /build-time
RUN apk add --no-cache curl
CMD ["cat", "/build-time"]
EOF

cat > "$APP/.dockerignore" <<'EOF'
.git
EOF

echo "== Bootstrap OK =="
echo "Dockerfile: $APP/Dockerfile  (NO reproducible por diseno)"
echo
echo "Siguiente:"
echo "  1) Edita $APP/Dockerfile hasta que sea reproducible."
echo "  2) bash .../tests/validate.sh"
