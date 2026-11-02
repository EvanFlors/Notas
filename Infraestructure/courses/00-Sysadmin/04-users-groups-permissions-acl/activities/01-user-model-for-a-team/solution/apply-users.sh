#!/usr/bin/env bash
# Solución de referencia: aplica el modelo de team-spec.md.
# Idempotente. Ejecutar como root en VM descartable.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecuta como root" >&2
    exit 1
fi

for cmd in useradd usermod groupadd chage setfacl getfacl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: falta '$cmd'. Instala shadow-utils y acl." >&2
        exit 1
    fi
done

# ---------- grupos ----------
for g in developers auditors; do
    if ! getent group "$g" >/dev/null; then
        echo "==> grupo $g"
        groupadd "$g"
    fi
done

# ---------- usuarios ----------
create_user() {
    local login="$1" gecos="$2" primary_grp="$3"
    if ! id "$login" >/dev/null 2>&1; then
        echo "==> usuario $login"
        useradd \
            --create-home \
            --shell /bin/bash \
            --user-group \
            --comment "$gecos" \
            "$login"
    fi
    if [ -n "$primary_grp" ]; then
        usermod -aG "$primary_grp" "$login"
    fi
}

create_user ana    "Ana Lopez"    developers
create_user diego  "Diego Ruiz"   developers
create_user sofia  "Sofia Paz"    developers
create_user audit1 "Auditor Ext"  auditors

# ---------- política de expiración ----------
# 90 días max, aviso 7 días antes
for u in ana diego sofia audit1; do
    chage -M 90 -W 7 "$u"
done

# sofia: cuenta expira en 90 días
expire_date="$(date -d "+90 days" +%Y-%m-%d)"
chage -E "$expire_date" sofia

# ---------- /srv/project ----------
mkdir -p /srv/project
chown root:developers /srv/project
chmod 2770 /srv/project

setfacl -m   "g:developers:rwx,g:auditors:rx" /srv/project
setfacl -d -m "u::rwx,g::rwx,o::---,g:developers:rwx,g:auditors:rx" /srv/project

# ---------- /srv/audit ----------
mkdir -p /srv/audit
chown root:auditors /srv/audit
chmod 2750 /srv/audit

setfacl -d -m "u::rwx,g::rx,o::---,g:auditors:rx" /srv/audit

echo
echo "OK: modelo aplicado."
echo "    getfacl /srv/project"
echo "    getfacl /srv/audit"
echo "    ejecuta sudo bash tests/validate.sh"
