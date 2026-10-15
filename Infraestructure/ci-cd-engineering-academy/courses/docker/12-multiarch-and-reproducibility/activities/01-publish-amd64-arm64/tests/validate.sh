#!/usr/bin/env bash
# Validate dkr-12-01-publish-amd64-arm64.
#
# Note: deliberately NO 'set -o pipefail' — multiple checks pipe long outputs
# into 'grep -q', and pipefail would surface spurious SIGPIPE (exit 141)
# from the producer when grep exits early.

BASE="${1:-${BASE_DIR:-/tmp/dkr-12-publish}}"
MODE="${MODE:-local}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }
note_skip() { report+="  SKIP -- $1\n"; }

echo "== Validating dkr-12-01-publish-amd64-arm64 ($MODE) =="

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi
if ! docker buildx version >/dev/null 2>&1; then
  echo "SKIP: docker buildx no disponible."
  exit 0
fi

# ---- Check 1: builder docker-container existe ----
# Aceptamos cualquier builder cuyo driver sea docker-container
# (el estudiante puede usar un nombre distinto).
if docker buildx ls 2>/dev/null | awk 'NR>1 {print $2}' | grep -q 'docker-container'; then
  note_ok "existe al menos un builder con driver docker-container"
else
  note_fail "no hay ningun builder con driver docker-container (crealo con: docker buildx create --driver docker-container --use)"
fi

# ---- Determinar REF segun modo ----
if [ "$MODE" = "local" ]; then
  REF="127.0.0.1:5050/dkr-12-app:v1"

  # ---- Check 2: registry local responde ----
  if curl -sf http://127.0.0.1:5050/v2/ >/dev/null 2>&1; then
    note_ok "registry local responde en 127.0.0.1:5050"
  else
    note_fail "registry local NO responde (ejecuta el bootstrap otra vez)"
  fi

elif [ "$MODE" = "live" ]; then
  if [ -z "${GHCR_OWNER:-}" ]; then
    echo "ERROR: MODE=live requiere GHCR_OWNER." >&2
    exit 2
  fi
  REF="ghcr.io/$GHCR_OWNER/dkr-12-app:v1"
  note_ok "modo live con ref $REF"
else
  echo "ERROR: MODE desconocido '$MODE'." >&2
  exit 2
fi

# ---- Check 3: inspect del tag ----
INSPECT_OUT="$(docker buildx imagetools inspect "$REF" 2>&1 || true)"
if printf '%s\n' "$INSPECT_OUT" | grep -q '^Name:'; then
  note_ok "tag $REF presente en el registry"
else
  note_fail "tag $REF NO encontrado. Ejecuta: docker buildx build --platform linux/amd64,linux/arm64 -t $REF --push <ctx>"
  printf 'Detalle: %s\n' "$INSPECT_OUT" | head -5 >&2
fi

# ---- Check 4: MediaType es un image index ----
if printf '%s\n' "$INSPECT_OUT" | grep -q 'image.index.v1+json\|manifest.list.v2+json'; then
  note_ok "MediaType = OCI image index (o manifest list)"
else
  note_fail "MediaType NO es image index. Se publico mono-arch. Reconstruye con --platform linux/amd64,linux/arm64"
fi

# ---- Check 5: ambas plataformas presentes ----
if printf '%s\n' "$INSPECT_OUT" | grep -q 'Platform: *linux/amd64'; then
  note_ok "plataforma linux/amd64 presente"
else
  note_fail "plataforma linux/amd64 NO esta en el indice"
fi

if printf '%s\n' "$INSPECT_OUT" | grep -q 'Platform: *linux/arm64'; then
  note_ok "plataforma linux/arm64 presente"
else
  note_fail "plataforma linux/arm64 NO esta en el indice"
fi

echo
printf '%b' "$report"
echo
total=$((passed+failed))
if [ "$failed" -eq 0 ]; then
  echo "PASS ($passed/$total)"
  exit 0
else
  echo "FAIL ($passed/$total)"
  exit 1
fi
