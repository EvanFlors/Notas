#!/usr/bin/env bash
# validate.sh — ejecuta good_playbook.yml dos veces y verifica idempotencia.
# Si ansible-core no está instalado, imprime SKIP y termina con exit 0.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK="${HERE}/good_playbook.yml"
INVENTORY="${HERE}/inventory.yml"

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "SKIP: ansible-core no disponible en el PATH. Documenta el entorno en run-transcript.txt."
  exit 0
fi

if [[ ! -f "${PLAYBOOK}" ]]; then
  echo "FAIL: falta ${PLAYBOOK}. Debes crearlo (OP-task-2)."
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "=== Primera corrida (se esperan cambios) ==="
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" | tee "${TMP}/run1.log"

echo
echo "=== Segunda corrida (se esperan 0 cambios) ==="
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" | tee "${TMP}/run2.log"

# El PLAY RECAP tiene la forma:
#   localhost   : ok=N  changed=M  unreachable=0  failed=0 ...
RECAP="$(grep -E '^localhost' "${TMP}/run2.log" | tail -n1 || true)"
if [[ -z "${RECAP}" ]]; then
  echo "FAIL: no se encontró PLAY RECAP para localhost en la segunda corrida."
  exit 1
fi

CHANGED="$(echo "${RECAP}" | sed -nE 's/.*changed=([0-9]+).*/\1/p')"
FAILED="$(echo "${RECAP}"  | sed -nE 's/.*failed=([0-9]+).*/\1/p')"

echo
echo "Segunda corrida: changed=${CHANGED} failed=${FAILED}"

if [[ "${CHANGED}" != "0" || "${FAILED}" != "0" ]]; then
  echo "FAIL: la segunda corrida debió reportar changed=0 failed=0."
  exit 1
fi

echo "OK: idempotencia verificada."
