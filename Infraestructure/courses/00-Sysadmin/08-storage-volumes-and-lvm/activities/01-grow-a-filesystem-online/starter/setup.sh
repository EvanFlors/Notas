#!/usr/bin/env bash
# setup.sh — prepara el entorno de la actividad sys-08-01.
# Crea: 2 archivos imagen, 2 loop devices, 1 PV, 1 VG, 1 LV ext4 montado.
#
# Uso:
#   CONFIRM=yes sudo -E bash starter/setup.sh
#
# Idempotente: desarma y rehace si ya existe.

set -euo pipefail
IFS=$'\n\t'

IMG1="/tmp/sys08-01-1.img"
IMG2="/tmp/sys08-01-2.img"
MNT="/mnt/sys08-01"
VG="vg_grow"
LV="lv_app"
SIZE_IMG="1G"
SIZE_LV="500M"

if [[ "${CONFIRM:-}" != "yes" ]]; then
  echo "ERROR: operación destructiva. Reejecuta con:" >&2
  echo "       CONFIRM=yes sudo -E bash $0" >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: requiere privilegios (losetup, lvm, mount)." >&2
  exit 2
fi

cleanup_existing() {
  echo "== Limpieza previa (idempotencia) =="
  umount "${MNT}" 2>/dev/null || true
  if vgs "${VG}" >/dev/null 2>&1; then
    lvremove -f "${VG}" 2>/dev/null || true
    vgremove -f "${VG}" 2>/dev/null || true
  fi
  for img in "${IMG1}" "${IMG2}"; do
    while read -r loop; do
      [[ -z "${loop}" ]] && continue
      pvremove -ff "${loop}" 2>/dev/null || true
      losetup -d "${loop}" 2>/dev/null || true
    done < <(losetup -j "${img}" 2>/dev/null | awk -F: '{print $1}')
  done
  rm -f "${IMG1}" "${IMG2}"
}

cleanup_existing

echo "== Creando imágenes (${SIZE_IMG} cada una) =="
truncate -s "${SIZE_IMG}" "${IMG1}"
truncate -s "${SIZE_IMG}" "${IMG2}"

echo "== Asociando loops =="
LOOP1="$(losetup --find --show "${IMG1}")"
LOOP2="$(losetup --find --show "${IMG2}")"
echo "  ${IMG1} -> ${LOOP1}"
echo "  ${IMG2} -> ${LOOP2}  (añadir al VG es parte de la actividad)"

echo "== PV + VG + LV sobre LOOP1 =="
pvcreate "${LOOP1}"
vgcreate "${VG}" "${LOOP1}"
lvcreate -L "${SIZE_LV}" -n "${LV}" "${VG}"

echo "== Formateando ext4 y montando =="
mkfs.ext4 -F -L "sys08-01" "/dev/${VG}/${LV}" >/dev/null
mkdir -p "${MNT}"
mount "/dev/${VG}/${LV}" "${MNT}"

echo "== Archivo de prueba =="
cat > "${MNT}/README-prueba.txt" <<'EOF'
Este archivo valida que los datos previos sobreviven al crecimiento del LV.
No lo borres: tests/validate.sh lo comprueba.
EOF
chmod 644 "${MNT}/README-prueba.txt"

echo
echo "ESTADO INICIAL:"
lsblk "${LOOP1}" "${LOOP2}" 2>/dev/null || true
vgs "${VG}"
lvs "${VG}"
df -hT "${MNT}"
echo
echo "LISTO. Procede con §5.2 del README."
