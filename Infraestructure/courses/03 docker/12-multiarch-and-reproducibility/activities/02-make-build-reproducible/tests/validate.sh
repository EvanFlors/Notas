#!/usr/bin/env bash
# Validate dkr-12-02-make-build-reproducible.
# Builds the student's Dockerfile twice to OCI tarballs and compares sha256sum.
#
# Note: deliberately NO 'set -o pipefail' — some checks pipe into 'grep -q'
# and pipefail would surface spurious SIGPIPE from the producer.

BASE="${1:-${BASE_DIR:-/tmp/dkr-12-repro}}"
APP="$BASE/app"
BUILDER="dkr12-repro"
OUT_A="$BASE/out-a.tar"
OUT_B="$BASE/out-b.tar"

export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"

passed=0
failed=0
report=""
note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-12-02-make-build-reproducible =="

if ! docker buildx version >/dev/null 2>&1; then
  echo "SKIP: docker buildx no disponible."
  exit 0
fi

if [ ! -f "$APP/Dockerfile" ]; then
  echo "FAIL: $APP/Dockerfile no existe. Ejecuta starter/bootstrap.sh." >&2
  exit 1
fi

# ---- Check 1: builder docker-container ----
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  if docker buildx create --name "$BUILDER" --driver docker-container >/dev/null 2>&1; then
    note_ok "builder $BUILDER creado"
  else
    note_fail "no se pudo crear builder $BUILDER"
  fi
else
  note_ok "builder $BUILDER ya existe"
fi
docker buildx inspect --bootstrap "$BUILDER" >/dev/null 2>&1 || true

# ---- Check 2: Dockerfile ya no contiene heuristicas obvias de no-reproducibilidad ----
# No es dura; el gate real es el sha256sum. Esto solo da pistas.
if grep -qE '^[[:space:]]*RUN[[:space:]].*(^|[[:space:]])date([[:space:]]|$)' "$APP/Dockerfile"; then
  report+="  HINT -- 'RUN date' sigue en el Dockerfile; probablemente no es reproducible\n"
fi
if grep -qE '^FROM[[:space:]]+[^[:space:]@]+(:[^@[:space:]]+)?[[:space:]]*$' "$APP/Dockerfile"; then
  report+="  HINT -- FROM sin @sha256:... (tag flotante)\n"
fi

# ---- Check 3: dos builds consecutivos, comparar sha256 ----
rm -f "$OUT_A" "$OUT_B"
build_once() {
  local out="$1"
  docker buildx build \
    --builder "$BUILDER" \
    --provenance=false --sbom=false \
    --build-arg SOURCE_DATE_EPOCH \
    --output "type=oci,dest=$out,rewrite-timestamp=true" \
    "$APP" >"/tmp/.dkr12-repro-build.log" 2>&1
}

if build_once "$OUT_A"; then
  note_ok "primer build OK"
else
  note_fail "primer build fallo (ver /tmp/.dkr12-repro-build.log)"
fi

if build_once "$OUT_B"; then
  note_ok "segundo build OK"
else
  note_fail "segundo build fallo (ver /tmp/.dkr12-repro-build.log)"
fi

if [ -f "$OUT_A" ] && [ -f "$OUT_B" ]; then
  SUM_A="$(sha256sum "$OUT_A" | awk '{print $1}')"
  SUM_B="$(sha256sum "$OUT_B" | awk '{print $1}')"
  report+="  A: $SUM_A\n"
  report+="  B: $SUM_B\n"
  if [ "$SUM_A" = "$SUM_B" ]; then
    note_ok "sha256sum coincide => REPRODUCIBLE"
  else
    note_fail "sha256sum NO coincide => aun hay drift"
  fi
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
