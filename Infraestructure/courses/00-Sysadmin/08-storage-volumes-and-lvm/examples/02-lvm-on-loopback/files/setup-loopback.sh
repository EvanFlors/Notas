#!/usr/bin/env bash
# setup-loopback.sh — crea dos archivos imagen y los asocia a loop devices
# para servir como PVs del ejemplo 02 (sys-08).
#
# Uso:
#   CONFIRM=yes sudo -E bash setup-loopback.sh
#
# Idempotente: si los archivos ya existen y están asociados, no duplica.
# Destructivo: sobreescribe /tmp/lvm-demo-{1,2}.img si existían.

set -euo pipefail
IFS=$'\n\t'

IMG1="/tmp/lvm-demo-1.img"
IMG2="/tmp/lvm-demo-2.img"
SIZE="1G"

if [[ "${CONFIRM:-}" != "yes" ]]; then
  echo "ERROR: este script crea archivos imagen y loop devices." >&2
  echo "       Reejecuta con: CONFIRM=yes sudo -E bash $0" >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: requiere privilegios (losetup, pvcreate)." >&2
  echo "       Usa: sudo -E bash $0" >&2
  exit 2
fi

echo "== Creando imágenes dispersas de ${SIZE} =="
truncate -s "${SIZE}" "${IMG1}"
truncate -s "${SIZE}" "${IMG2}"
ls -lh "${IMG1}" "${IMG2}"

echo "== Liberando loops previos asociados a estas imágenes (si hubiera) =="
for img in "${IMG1}" "${IMG2}"; do
  while read -r loop; do
    [[ -n "${loop}" ]] && losetup -d "${loop}" || true
  done < <(losetup -j "${img}" | awk -F: '{print $1}')
done

echo "== Asociando loops nuevos =="
LOOP1="$(losetup --find --show "${IMG1}")"
LOOP2="$(losetup --find --show "${IMG2}")"
echo "  ${IMG1} -> ${LOOP1}"
echo "  ${IMG2} -> ${LOOP2}"

echo "== Creando PVs =="
pvcreate "${LOOP1}" "${LOOP2}"
pvs

echo
echo "LISTO. Loops expuestos:"
echo "  LOOP1=${LOOP1}"
echo "  LOOP2=${LOOP2}"
echo
echo "Siguiente paso sugerido:"
echo "  sudo vgcreate vg_demo ${LOOP1} ${LOOP2}"
echo "  sudo lvcreate -L 500M -n lv_app vg_demo"
