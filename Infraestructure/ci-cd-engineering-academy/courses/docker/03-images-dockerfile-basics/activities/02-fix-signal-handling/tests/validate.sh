#!/usr/bin/env bash
# Validate dkr-03-02-fix-signal-handling.
#
# SKIP gracioso si docker no esta disponible.
# NO usamos `set -o pipefail` (grep -q en pipes).

BASE="${1:-${BASE_DIR:-/tmp/dkr-03-02}}"
PROJECT="$BASE/project"
IMAGE_TAG="${IMAGE_TAG:-signal-check:test}"
CT_NAME="${CT_NAME:-signal-check-ct}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

cleanup() {
  docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
  docker rmi "$IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== Validating dkr-03-02-fix-signal-handling under $BASE =="

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker no disponible (binario o daemon)."
  echo "RESULT: skipped."
  exit 0
fi

if [ ! -f "$PROJECT/Dockerfile" ]; then
  echo "FAIL: no existe $PROJECT/Dockerfile. Corre starter/bootstrap.sh primero." >&2
  exit 1
fi

# ---- Check 1: Dockerfile fue modificado ----
# El starter tiene literal `CMD python /app.py`.
if grep -qx 'CMD python /app.py' "$PROJECT/Dockerfile" && ! grep -q '^CMD exec' "$PROJECT/Dockerfile"; then
  note_fail "Dockerfile sigue como el starter (shell form sin exec)"
else
  note_ok "Dockerfile fue modificado respecto al starter"
fi

# ---- Check 2: build ----
build_log="$(mktemp)"
if docker build -t "$IMAGE_TAG" "$PROJECT" >"$build_log" 2>&1; then
  note_ok "docker build OK"
else
  note_fail "docker build fallo (ver $build_log)"
  tail -20 "$build_log" >&2
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed OK, $failed FAIL."
  exit 1
fi
rm -f "$build_log"

# ---- Check 3: run + stop timing ----
docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
if ! docker run -d --name "$CT_NAME" "$IMAGE_TAG" >/dev/null 2>&1; then
  note_fail "docker run fallo"
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed OK, $failed FAIL."
  exit 1
fi
sleep 2

start=$(date +%s)
docker stop "$CT_NAME" >/dev/null 2>&1 || true
end=$(date +%s)
elapsed=$((end - start))

# Umbral generoso (< 8s) para tolerar daemons congestionados; la prueba
# determinista del fix son los checks de 'recibi SIGTERM' en logs y PID 1 = python
# mas abajo. El default de grace de docker stop son 10s; estar bajo 8s indica
# shutdown ordenado (no SIGKILL).
if [ "$elapsed" -lt 8 ]; then
  note_ok "docker stop termino en ${elapsed}s (< 8s, no se llego al SIGKILL default)"
else
  note_fail "docker stop tardo ${elapsed}s (esperado < 8s); PID 1 probablemente sigue siendo /bin/sh"
fi

# ---- Check 4: logs contienen 'recibi SIGTERM' ----
logs="$(docker logs "$CT_NAME" 2>&1 || true)"
if printf '%s' "$logs" | grep -q 'recibi SIGTERM'; then
  note_ok "logs contienen 'recibi SIGTERM' (el proceso recibio la senal)"
else
  note_fail "logs NO contienen 'recibi SIGTERM' (el proceso nunca recibio la senal)"
fi

# ---- Check 5: PID 1 fue 'python' (re-run efimero y chequea ps antes de stop) ----
docker rm -f "$CT_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CT_NAME" "$IMAGE_TAG" >/dev/null 2>&1
sleep 1
pid1_comm="$(docker exec "$CT_NAME" sh -c 'cat /proc/1/comm 2>/dev/null' 2>/dev/null | tr -d '[:space:]')"
if [ "$pid1_comm" = "python" ] || [ "$pid1_comm" = "python3" ] || [ "$pid1_comm" = "python3.12" ]; then
  note_ok "PID 1 dentro del contenedor es '$pid1_comm'"
else
  note_fail "PID 1 dentro del contenedor es '$pid1_comm' (esperado python/python3)"
fi
docker rm -f "$CT_NAME" >/dev/null 2>&1 || true

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
