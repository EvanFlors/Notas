#!/usr/bin/env bash
# validate.sh — verifica que el runaway se escala correctamente.
# Lanza el runaway, envia TERM (debe sobrevivir), KILL (debe morir),
# y confirma ausencia de zombies y evidencia en el log.

set -o pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="${HERE}/../starter/runaway.sh"
LOG="/tmp/runaway-validate.log"

fail=0

if [[ ! -f "${STARTER}" ]]; then
  echo "FAIL: no se encuentra starter/runaway.sh en ${STARTER}"
  exit 1
fi

chmod +x "${STARTER}" || true

echo "== Lanzando runaway =="
bash "${STARTER}" --log "${LOG}" >/dev/null 2>&1 &
RUN_PID=$!
sleep 1

if ! kill -0 "${RUN_PID}" 2>/dev/null; then
  echo "FAIL: runaway no arranco"
  exit 1
fi
echo "  OK   runaway vivo pid=${RUN_PID}"

echo "== Enviando SIGTERM (deberia ignorarlo) =="
kill -TERM "${RUN_PID}" 2>/dev/null || true
sleep 2

if kill -0 "${RUN_PID}" 2>/dev/null; then
  echo "  OK   runaway sobrevivio a TERM (ignorado como esperabamos)"
else
  echo "  FAIL runaway murio con TERM — el starter deberia ignorarlo"
  fail=$((fail+1))
fi

if grep -q 'received SIGTERM' "${LOG}" 2>/dev/null; then
  echo "  OK   log registro SIGTERM ignorado"
else
  echo "  FAIL log no registro SIGTERM"
  fail=$((fail+1))
fi

echo "== Escalando a SIGKILL =="
kill -KILL "${RUN_PID}" 2>/dev/null || true
# Esperar a que el shell "wait" implicito recoja al zombie.
wait "${RUN_PID}" 2>/dev/null
RC=$?

for _ in {1..10}; do
  kill -0 "${RUN_PID}" 2>/dev/null || break
  sleep 0.2
done

if kill -0 "${RUN_PID}" 2>/dev/null; then
  echo "  FAIL runaway sigue vivo tras KILL"
  fail=$((fail+1))
else
  echo "  OK   runaway murio tras KILL"
fi

echo "== Verificando ausencia de zombies del runaway =="
if ps -eo pid,ppid,stat,comm 2>/dev/null | awk '$3 ~ /Z/ { print }' | grep -qi 'runaway'; then
  echo "  FAIL hay un zombie de runaway"
  fail=$((fail+1))
else
  echo "  OK   sin zombies del runaway"
fi

echo "== Exit code tras KILL =="
# 128+9 = 137 cuando bash reporta la muerte por senal.
if (( RC == 137 )) || (( RC == 143 )) || (( RC == 0 )); then
  echo "  OK   exit code=${RC}"
else
  echo "  WARN exit code=${RC} (no critico)"
fi

rm -f "${LOG}"

echo
if (( fail > 0 )); then
  echo "RESULT: ${fail} check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
