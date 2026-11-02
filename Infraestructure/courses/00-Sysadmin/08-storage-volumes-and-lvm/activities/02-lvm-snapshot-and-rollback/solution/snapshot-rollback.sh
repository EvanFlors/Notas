#!/usr/bin/env bash
# snapshot-rollback.sh — solución de referencia para sys-08-02.
# Realiza el ciclo completo: snapshot -> destruir origen -> verificar
# que el snapshot preserva -> rollback -> verificar restauración.
#
# Uso:
#   CONFIRM=yes sudo -E bash solution/snapshot-rollback.sh

set -euo pipefail
IFS=$'\n\t'

MNT="/mnt/sys08-02"
MNT_SNAP="/mnt/sys08-02-snap"
VG="vg_snap"
LV="lv_data"
SNAP="lv_data_snap"
HASH_FILE="/tmp/sys08-02-hash-original.txt"

if [[ "${CONFIRM:-}" != "yes" ]]; then
  echo "ERROR: operación destructiva. Reejecuta con:" >&2
  echo "       CONFIRM=yes sudo -E bash $0" >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: requiere privilegios." >&2
  exit 2
fi

if ! mountpoint -q "${MNT}"; then
  echo "ERROR: ${MNT} no está montado. Ejecuta starter/setup.sh primero." >&2
  exit 1
fi

if [[ ! -s "${HASH_FILE}" ]]; then
  echo "ERROR: no existe ${HASH_FILE}. Ejecuta starter/setup.sh primero." >&2
  exit 1
fi

HASH_ORIG="$(cat "${HASH_FILE}")"
echo "== Hash canónico: ${HASH_ORIG} =="

# T1. Snapshot de 100 MiB
echo "== T1. Crear snapshot (100M) =="
lvcreate -L 100M -s -n "${SNAP}" "/dev/${VG}/${LV}"

# T2. Verificar
echo "== T2. Estado del VG =="
lvs "${VG}"

# T3. Romper el origen
echo "== T3. Destruir datos-oro.txt y crear basura.bin =="
rm -f "${MNT}/datos-oro.txt"
dd if=/dev/zero of="${MNT}/basura.bin" bs=1M count=50 status=none
ls -lh "${MNT}"
lvs "${VG}"   # Data% del snapshot subió

# T4. Montar snapshot RO y verificar que preserva
echo "== T4. Montar snapshot RO en ${MNT_SNAP} =="
mkdir -p "${MNT_SNAP}"
mount -o ro "/dev/${VG}/${SNAP}" "${MNT_SNAP}"

if [[ ! -f "${MNT_SNAP}/datos-oro.txt" ]]; then
  echo "FAIL: el snapshot NO contiene datos-oro.txt." >&2
  exit 1
fi
HASH_SNAP="$(md5sum "${MNT_SNAP}/datos-oro.txt" | awk '{print $1}')"
echo "  md5 en snapshot = ${HASH_SNAP}"
if [[ "${HASH_SNAP}" != "${HASH_ORIG}" ]]; then
  echo "FAIL: el hash en el snapshot no coincide con el canónico." >&2
  exit 1
fi
echo "  OK: snapshot preserva el estado canónico."

# T5. Desmontar snapshot y origen antes del merge
echo "== T5. Desmontar para merge =="
umount "${MNT_SNAP}"
umount "${MNT}"

# T6. Merge
echo "== T6. lvconvert --merge =="
lvconvert --merge "/dev/${VG}/${SNAP}"

# T7. Remontar y verificar
echo "== T7. Remontar y verificar =="
mount "/dev/${VG}/${LV}" "${MNT}"

if [[ ! -f "${MNT}/datos-oro.txt" ]]; then
  echo "FAIL: tras rollback, datos-oro.txt no está en el origen." >&2
  exit 1
fi
HASH_AFTER="$(md5sum "${MNT}/datos-oro.txt" | awk '{print $1}')"
echo "  md5 tras rollback = ${HASH_AFTER}"
if [[ "${HASH_AFTER}" != "${HASH_ORIG}" ]]; then
  echo "FAIL: hash tras rollback no coincide con el canónico." >&2
  exit 1
fi

if [[ -f "${MNT}/basura.bin" ]]; then
  echo "FAIL: basura.bin sobrevivió al rollback." >&2
  exit 1
fi

if lvs "${VG}/${SNAP}" >/dev/null 2>&1; then
  echo "WARN: el snapshot aún figura en lvs (merge diferido o incompleto)."
fi

echo
echo "ESTADO FINAL:"
lvs "${VG}"
ls -lh "${MNT}"
echo
echo "OK: rollback verificado por hash."
