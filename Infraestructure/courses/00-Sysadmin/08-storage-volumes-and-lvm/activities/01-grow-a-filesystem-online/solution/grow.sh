#!/usr/bin/env bash
# grow.sh — solución de referencia para sys-08-01.
# Asume que starter/setup.sh se ejecutó correctamente.
# Ejecuta la operación de crecimiento en caliente.
#
# Uso:
#   CONFIRM=yes sudo -E bash solution/grow.sh

set -euo pipefail
IFS=$'\n\t'

IMG2="/tmp/sys08-01-2.img"
MNT="/mnt/sys08-01"
VG="vg_grow"
LV="lv_app"

if [[ "${CONFIRM:-}" != "yes" ]]; then
  echo "ERROR: operación destructiva (modifica VG/LV). Reejecuta con:" >&2
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

echo "== Simulando consumo (dejará ~400 MiB usados) =="
if [[ ! -f "${MNT}/relleno.bin" ]]; then
  dd if=/dev/zero of="${MNT}/relleno.bin" bs=1M count=400 status=none
fi
df -hT "${MNT}"

echo "== Localizando LOOP2 =="
LOOP2="$(losetup -j "${IMG2}" | awk -F: '{print $1}' | head -n1)"
if [[ -z "${LOOP2}" ]]; then
  echo "ERROR: no hay loop asociado a ${IMG2}." >&2
  exit 1
fi
echo "  LOOP2=${LOOP2}"

echo "== Añadiendo LOOP2 como PV y al VG =="
if ! pvs "${LOOP2}" >/dev/null 2>&1; then
  pvcreate "${LOOP2}"
fi
if ! vgs -o+pv_name "${VG}" | grep -q "${LOOP2}"; then
  vgextend "${VG}" "${LOOP2}"
fi
vgs "${VG}"

echo "== Hash del relleno ANTES del crecimiento =="
HASH_BEFORE="$(md5sum "${MNT}/relleno.bin" | awk '{print $1}')"
echo "  md5(relleno.bin) = ${HASH_BEFORE}"

echo "== lvextend +400M (sin desmontar) =="
lvextend -L +400M "/dev/${VG}/${LV}"
lvs "${VG}"

echo "== resize2fs =="
resize2fs "/dev/${VG}/${LV}"

echo "== lvextend -r +100M (atajo: extiende LV + fs en una pasada) =="
lvextend -r -L +100M "/dev/${VG}/${LV}"

echo "== Hash del relleno DESPUÉS =="
HASH_AFTER="$(md5sum "${MNT}/relleno.bin" | awk '{print $1}')"
echo "  md5(relleno.bin) = ${HASH_AFTER}"

if [[ "${HASH_BEFORE}" != "${HASH_AFTER}" ]]; then
  echo "FAIL: el hash cambió. Algo salió mal." >&2
  exit 1
fi

echo
echo "ESTADO FINAL:"
vgs "${VG}"
lvs "${VG}"
df -hT "${MNT}"
echo
echo "OK: LV crecido en caliente, datos íntegros."
