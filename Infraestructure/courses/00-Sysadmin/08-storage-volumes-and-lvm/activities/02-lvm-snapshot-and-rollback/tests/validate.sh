#!/usr/bin/env bash
# validate.sh — comprueba que el alumno completó sys-08-02 correctamente.

set -o pipefail
IFS=$'\n\t'

MNT="/mnt/sys08-02"
VG="vg_snap"
LV="lv_data"
SNAP="lv_data_snap"
HASH_FILE="/tmp/sys08-02-hash-original.txt"
fail=0

echo "== Validando actividad sys-08-02 =="

if [[ "${EUID}" -ne 0 ]]; then
  echo "FAIL: ejecuta con sudo." >&2
  exit 2
fi

# 1. VG existe
if vgs "${VG}" >/dev/null 2>&1; then
  echo "  OK   VG '${VG}' existe"
else
  echo "  FAIL VG '${VG}' no existe"
  fail=$((fail+1))
fi

# 2. LV origen existe
if lvs "${VG}/${LV}" >/dev/null 2>&1; then
  echo "  OK   LV '${LV}' existe"
else
  echo "  FAIL LV '${LV}' no existe"
  fail=$((fail+1))
fi

# 3. Está montado
if mountpoint -q "${MNT}"; then
  echo "  OK   ${MNT} está montado"
else
  echo "  FAIL ${MNT} no está montado"
  fail=$((fail+1))
fi

# 4. Snapshot ya no existe (fue consumido por el merge)
if lvs "${VG}/${SNAP}" >/dev/null 2>&1; then
  echo "  FAIL snapshot '${SNAP}' aún existe — ¿faltó lvconvert --merge?"
  fail=$((fail+1))
else
  echo "  OK   snapshot '${SNAP}' consumido/ausente"
fi

# 5. Hash file disponible
if [[ ! -s "${HASH_FILE}" ]]; then
  echo "  FAIL ${HASH_FILE} no existe — ejecuta starter/setup.sh"
  fail=$((fail+1))
else
  HASH_ORIG="$(cat "${HASH_FILE}")"
  echo "  OK   hash canónico cargado: ${HASH_ORIG}"

  # 6. datos-oro.txt existe y hash coincide
  if [[ -f "${MNT}/datos-oro.txt" ]]; then
    HASH_NOW="$(md5sum "${MNT}/datos-oro.txt" | awk '{print $1}')"
    if [[ "${HASH_NOW}" == "${HASH_ORIG}" ]]; then
      echo "  OK   datos-oro.txt restaurado (hash coincide)"
    else
      echo "  FAIL datos-oro.txt presente pero hash difiere (${HASH_NOW} vs ${HASH_ORIG})"
      fail=$((fail+1))
    fi
  else
    echo "  FAIL datos-oro.txt no existe tras rollback"
    fail=$((fail+1))
  fi
fi

# 7. basura.bin NO debe estar
if [[ -f "${MNT}/basura.bin" ]]; then
  echo "  FAIL basura.bin sobrevivió al rollback"
  fail=$((fail+1))
else
  echo "  OK   basura.bin ausente"
fi

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULT: ${fail} check(s) fallaron."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
