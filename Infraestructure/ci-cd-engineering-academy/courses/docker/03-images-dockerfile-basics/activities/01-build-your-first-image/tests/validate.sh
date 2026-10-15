#!/usr/bin/env bash
# Validate dkr-03-01-build-your-first-image.
#
# SKIP gracioso si docker no esta disponible: exit 0 con mensaje claro.
#
# NOTA: deliberadamente NO usamos `set -o pipefail`. Varios checks hacen
# `cmd | grep -q ...`; pipefail convierte SIGPIPE del productor en falla.

BASE="${1:-${BASE_DIR:-/tmp/dkr-03-01}}"
PROJECT="$BASE/project"
IMAGE_TAG="${IMAGE_TAG:-dkr-03-01:test}"
CT_NAME="${CT_NAME:-dkr-03-01-ct}"
HOST_PORT="${HOST_PORT:-8000}"
MAX_MB="${MAX_MB:-250}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }
note_skip() { report+="  SKIP -- $1\n"; }

cleanup() {
  docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
  docker rmi "$IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== Validating dkr-03-01-build-your-first-image under $BASE =="

# ---- Pre: Docker disponible? ----
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado; esta actividad requiere Docker."
  echo "RESULT: skipped (docker ausente)."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde; esta actividad requiere el daemon activo."
  echo "RESULT: skipped (daemon down)."
  exit 0
fi

# ---- Check 1: estructura del proyecto ----
if [ -f "$PROJECT/Dockerfile" ]; then
  note_ok "Dockerfile existe"
else
  note_fail "Dockerfile NO existe en $PROJECT"
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed OK, $failed FAIL."
  exit 1
fi

# Detecta placeholder: shell-form CMD + sin USER
if grep -q '^CMD uvicorn app.main' "$PROJECT/Dockerfile" && ! grep -qE '^USER ' "$PROJECT/Dockerfile"; then
  note_fail "Dockerfile sigue siendo el PLACEHOLDER (CMD shell-form y sin USER)"
else
  note_ok "Dockerfile fue modificado (no es el placeholder)"
fi

if [ -f "$PROJECT/.dockerignore" ] && [ -s "$PROJECT/.dockerignore" ]; then
  if grep -q '^\.git' "$PROJECT/.dockerignore" \
     && grep -q 'pycache' "$PROJECT/.dockerignore" \
     && grep -q 'venv'    "$PROJECT/.dockerignore" \
     && grep -q '\.env'   "$PROJECT/.dockerignore"; then
    note_ok ".dockerignore cubre .git/, pycache, venv, .env"
  else
    note_fail ".dockerignore existe pero falta alguna entrada (git/pycache/venv/env)"
  fi
else
  note_fail ".dockerignore vacio o inexistente"
fi

# ---- Check 2: Dockerfile usa exec form en CMD o ENTRYPOINT ----
if grep -qE '^(CMD|ENTRYPOINT) *\[' "$PROJECT/Dockerfile"; then
  note_ok "Dockerfile usa exec form (JSON array) en CMD o ENTRYPOINT"
else
  note_fail "Dockerfile NO tiene CMD/ENTRYPOINT en exec form"
fi

# ---- Check 3: Dockerfile declara USER ----
if grep -qE '^USER ' "$PROJECT/Dockerfile"; then
  note_ok "Dockerfile declara USER"
else
  note_fail "Dockerfile NO declara USER (correria como root)"
fi

# ---- Check 4: docker build ----
echo "  INFO -- construyendo imagen (puede tardar la primera vez)..."
build_log="$(mktemp)"
if docker build -t "$IMAGE_TAG" "$PROJECT" >"$build_log" 2>&1; then
  note_ok "docker build termino con exito"
else
  note_fail "docker build fallo (ver $build_log)"
  tail -20 "$build_log" >&2
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed OK, $failed FAIL."
  exit 1
fi
rm -f "$build_log"

# ---- Check 5: docker run --rm <img> echo ok -> "ok" ----
echo_output="$(docker run --rm "$IMAGE_TAG" echo ok 2>&1 || true)"
if [ "$echo_output" = "ok" ]; then
  note_ok "docker run --rm <img> echo ok -> ok"
else
  note_fail "docker run --rm <img> echo ok no imprimio 'ok' (output: $echo_output)"
fi

# ---- Check 6: USER no-root segun image inspect ----
user_cfg="$(docker image inspect "$IMAGE_TAG" --format '{{.Config.User}}' 2>/dev/null || echo '')"
if [ -z "$user_cfg" ] || [ "$user_cfg" = "0" ] || [ "$user_cfg" = "root" ] || [ "$user_cfg" = "0:0" ]; then
  note_fail "Config.User es root o vacio ('$user_cfg'); debe ser no-root"
else
  note_ok "Config.User no-root: '$user_cfg'"
fi

# ---- Check 7: Config.Cmd o Config.Entrypoint es array (exec form reflejado en metadata) ----
cmd_raw="$(docker image inspect "$IMAGE_TAG" --format '{{json .Config.Cmd}}' 2>/dev/null)"
ep_raw="$(docker image inspect "$IMAGE_TAG" --format '{{json .Config.Entrypoint}}' 2>/dev/null)"
# Shell form queda como ["/bin/sh","-c","..."]: lo detectamos.
if printf '%s' "$cmd_raw" | grep -q '"/bin/sh","-c"' \
   || printf '%s' "$ep_raw"  | grep -q '"/bin/sh","-c"'; then
  note_fail "Metadata indica shell form (/bin/sh -c ...): usa exec form"
else
  note_ok "Metadata consistente con exec form (sin /bin/sh -c)"
fi

# ---- Check 8: run + curl /healthz ----
if ! command -v curl >/dev/null 2>&1; then
  note_skip "curl no instalado; se omite el chequeo HTTP"
else
  docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
  if docker run -d --name "$CT_NAME" -p "${HOST_PORT}:8000" "$IMAGE_TAG" >/dev/null 2>&1; then
    # Espera hasta 10 s a que la app levante
    ok=0
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      sleep 1
      code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${HOST_PORT}/healthz" 2>/dev/null || echo 000)"
      if [ "$code" = "200" ]; then ok=1; break; fi
    done
    if [ "$ok" = "1" ]; then
      note_ok "GET /healthz respondio 200"
    else
      note_fail "GET /healthz no respondio 200 en 10s (ultimo code=$code)"
    fi
    docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
  else
    note_fail "No se pudo arrancar el contenedor (puerto $HOST_PORT ocupado?)"
  fi
fi

# ---- Check 9: tamano razonable ----
size_bytes="$(docker image inspect "$IMAGE_TAG" --format '{{.Size}}' 2>/dev/null || echo 0)"
size_mb=$(( size_bytes / 1024 / 1024 ))
if [ "$size_mb" -lt "$MAX_MB" ] && [ "$size_mb" -gt 0 ]; then
  note_ok "tamano imagen = ${size_mb}MB (< ${MAX_MB}MB)"
else
  note_fail "tamano imagen = ${size_mb}MB (esperado < ${MAX_MB}MB)"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
