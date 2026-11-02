#!/usr/bin/env bash
# setup.sh — prepara el entorno de sys-08-02.
# Crea: 1 archivo imagen 1.5G, 1 loop, 1 PV, VG 'vg_snap', LV 'lv_data' ext4
# con un fichero canónico 'datos-oro.txt' cuyo hash guarda en /tmp.
#
# Uso:
#   CONFIRM=yes sudo -E bash starter/setup.sh

set -euo pipefail
IFS=$'\n\t'

IMG="/tmp/sys08-02.img"
MNT="/mnt/sys08-02"
VG="vg_snap"
LV="lv_data"
SIZE_IMG="1500M"
SIZE_LV="400M"
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

cleanup_existing() {
  echo "== Limpieza previa =="
  umount "${MNT}" 2>/dev/null || true
  umount "/mnt/sys08-02-snap" 2>/dev/null || true
  if vgs "${VG}" >/dev/null 2>&1; then
    lvremove -f "${VG}" 2>/dev/null || true
    vgremove -f "${VG}" 2>/dev/null || true
  fi
  while read -r loop; do
    [[ -z "${loop}" ]] && continue
    pvremove -ff "${loop}" 2>/dev/null || true
    losetup -d "${loop}" 2>/dev/null || true
  done < <(losetup -j "${IMG}" 2>/dev/null | awk -F: '{print $1}')
  rm -f "${IMG}" "${HASH_FILE}"
}

cleanup_existing

echo "== Imagen y loop =="
truncate -s "${SIZE_IMG}" "${IMG}"
LOOP="$(losetup --find --show "${IMG}")"
echo "  ${IMG} -> ${LOOP}"

echo "== PV + VG + LV =="
pvcreate "${LOOP}"
vgcreate "${VG}" "${LOOP}"
lvcreate -L "${SIZE_LV}" -n "${LV}" "${VG}"

echo "== Formato y montaje =="
mkfs.ext4 -F -L "sys08-02" "/dev/${VG}/${LV}" >/dev/null
mkdir -p "${MNT}"
mount "/dev/${VG}/${LV}" "${MNT}"

echo "== Archivo canónico =="
cat > "${MNT}/datos-oro.txt" <<'EOF'
Este es el estado DE ORO.
Es lo que un snapshot bien hecho debe conservar
y a lo que debe volverse tras un rollback.

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
EOF
chmod 644 "${MNT}/datos-oro.txt"

HASH="$(md5sum "${MNT}/datos-oro.txt" | awk '{print $1}')"
echo "${HASH}" > "${HASH_FILE}"
chmod 644 "${HASH_FILE}"

echo
echo "ESTADO INICIAL:"
vgs "${VG}"
lvs "${VG}"
df -hT "${MNT}"
echo
echo "Hash canónico guardado en: ${HASH_FILE}"
echo "  md5(datos-oro.txt) = ${HASH}"
echo
echo "LISTO. Resuelve las tareas T1..T7 del README."
