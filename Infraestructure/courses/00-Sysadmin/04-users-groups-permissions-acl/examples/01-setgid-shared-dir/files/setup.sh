#!/usr/bin/env bash
# Demo: directorio compartido /srv/team con setgid + default ACL.
# Pensado para VM descartable. NO ejecutar en una máquina de trabajo.

set -euo pipefail

GROUP="developers"
USERS=("ana" "diego")
SHARED="/srv/team"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: ejecuta como root (sudo bash setup.sh)" >&2
        exit 1
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: falta '$1'. Instala el paquete 'acl'." >&2
        exit 1
    fi
}

require_root
require_cmd setfacl
require_cmd getfacl

# 1. Grupo
if ! getent group "$GROUP" >/dev/null; then
    echo "==> creando grupo $GROUP"
    groupadd "$GROUP"
fi

# 2. Usuarios de prueba
for u in "${USERS[@]}"; do
    if ! id "$u" >/dev/null 2>&1; then
        echo "==> creando usuario $u"
        useradd --create-home --shell /bin/bash --user-group "$u"
    fi
    usermod -aG "$GROUP" "$u"
done

# 3. Directorio compartido con setgid
echo "==> creando $SHARED con setgid"
mkdir -p "$SHARED"
chown "root:${GROUP}" "$SHARED"
chmod 2770 "$SHARED"

# 4. Default ACL: lo que se cree dentro hereda rwx para el grupo
echo "==> aplicando default ACL"
setfacl -m "d:u::rwx,d:g::rwx,d:o::---,d:g:${GROUP}:rwx" "$SHARED"
setfacl -m "g:${GROUP}:rwx" "$SHARED"

# 5. Prueba
echo "==> prueba: ana crea un archivo"
sudo -u ana touch "${SHARED}/hola.txt"

echo
echo "---- estado del directorio ----"
ls -ld "$SHARED"
echo
echo "---- getfacl $SHARED ----"
getfacl "$SHARED"
echo
echo "---- archivo creado por ana ----"
ls -l "${SHARED}/hola.txt"
getfacl "${SHARED}/hola.txt"

echo
echo "OK: observa que hola.txt pertenece al grupo '${GROUP}'"
echo "    y que la default ACL se heredó automáticamente."
