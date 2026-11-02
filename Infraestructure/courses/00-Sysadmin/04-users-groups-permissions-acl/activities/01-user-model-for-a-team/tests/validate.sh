#!/usr/bin/env bash
# Validador: comprueba el modelo definido en team-spec.md.
# Requiere root (lee /etc/shadow via chage, inspecciona /srv/*).

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecuta como root (sudo bash tests/validate.sh)" >&2
    exit 1
fi

fail=0
ok()   { echo "  OK   $1"; }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }

echo "== Grupos =="
for g in developers auditors; do
    if getent group "$g" >/dev/null; then
        ok "grupo existe: $g"
    else
        bad "grupo no existe: $g"
    fi
done

echo
echo "== Usuarios =="
check_user() {
    local u="$1" shell="$2" grp="$3"
    if ! id "$u" >/dev/null 2>&1; then
        bad "usuario no existe: $u"
        return
    fi
    ok "usuario existe: $u"
    local real_shell
    real_shell="$(getent passwd "$u" | cut -d: -f7)"
    if [ "$real_shell" = "$shell" ]; then
        ok "shell $u = $shell"
    else
        bad "shell $u = $real_shell (esperado $shell)"
    fi
    if id -nG "$u" | tr ' ' '\n' | grep -qx "$grp"; then
        ok "$u pertenece a $grp"
    else
        bad "$u no pertenece a $grp"
    fi
}

check_user ana    /bin/bash developers
check_user diego  /bin/bash developers
check_user sofia  /bin/bash developers
check_user audit1 /bin/bash auditors

echo
echo "== Política de expiración (chage) =="
for u in ana diego sofia audit1; do
    maxdays="$(chage -l "$u" 2>/dev/null | awk -F: '/Maximum number of days/ {gsub(/ /,"",$2); print $2}')"
    warn="$(chage -l "$u"   2>/dev/null | awk -F: '/Number of days of warning/ {gsub(/ /,"",$2); print $2}')"
    if [ "$maxdays" = "90" ]; then
        ok "$u max 90 días"
    else
        bad "$u max = $maxdays (esperado 90)"
    fi
    if [ "$warn" = "7" ]; then
        ok "$u aviso 7 días"
    else
        bad "$u aviso = $warn (esperado 7)"
    fi
done

exp_sofia="$(chage -l sofia 2>/dev/null | awk -F: '/Account expires/ {sub(/^[ \t]+/,"",$2); print $2}')"
if [ -n "$exp_sofia" ] && [ "$exp_sofia" != "never" ]; then
    ok "sofia tiene fecha de expiración ($exp_sofia)"
else
    bad "sofia sin fecha de expiración"
fi

echo
echo "== /srv/project =="
if [ -d /srv/project ]; then
    ok "existe /srv/project"
    mode="$(stat -c '%a' /srv/project)"
    owner="$(stat -c '%U:%G' /srv/project)"
    [ "$mode"  = "2770" ]              && ok "modo 2770" || bad "modo = $mode (esperado 2770)"
    [ "$owner" = "root:developers" ]    && ok "owner root:developers" || bad "owner = $owner"
    # ACL
    acl="$(getfacl -p /srv/project 2>/dev/null)"
    echo "$acl" | grep -q "^group:auditors:r-x"       && ok "ACL g:auditors:rx" || bad "ACL g:auditors:rx ausente"
    echo "$acl" | grep -q "^default:group:developers:rwx" && ok "default ACL g:developers:rwx" || bad "default ACL g:developers:rwx ausente"
    echo "$acl" | grep -q "^default:group:auditors:r-x"   && ok "default ACL g:auditors:rx"    || bad "default ACL g:auditors:rx ausente"

    # Prueba funcional: ana crea un archivo, hereda grupo developers
    tmpf="/srv/project/.probe-$$"
    rm -f "$tmpf" 2>/dev/null || true
    if sudo -u ana touch "$tmpf" 2>/dev/null; then
        fgrp="$(stat -c '%G' "$tmpf")"
        [ "$fgrp" = "developers" ] && ok "archivo nuevo hereda grupo developers" || bad "archivo nuevo grupo = $fgrp"
        rm -f "$tmpf"
    else
        bad "ana no pudo crear archivo en /srv/project"
    fi
else
    bad "no existe /srv/project"
fi

echo
echo "== /srv/audit =="
if [ -d /srv/audit ]; then
    ok "existe /srv/audit"
    mode="$(stat -c '%a' /srv/audit)"
    owner="$(stat -c '%U:%G' /srv/audit)"
    [ "$mode"  = "2750" ]            && ok "modo 2750" || bad "modo = $mode (esperado 2750)"
    [ "$owner" = "root:auditors" ]    && ok "owner root:auditors" || bad "owner = $owner"
    # auditor NO escribe
    if sudo -u audit1 touch /srv/audit/.probe-$$ 2>/dev/null; then
        bad "audit1 pudo escribir en /srv/audit (no debería)"
        rm -f /srv/audit/.probe-$$
    else
        ok "audit1 no puede escribir en /srv/audit"
    fi
    # auditor SÍ lista
    if sudo -u audit1 ls /srv/audit >/dev/null 2>&1; then
        ok "audit1 puede listar /srv/audit"
    else
        bad "audit1 no puede listar /srv/audit"
    fi
else
    bad "no existe /srv/audit"
fi

echo
if [ "$fail" -gt 0 ]; then
    echo "RESULT: $fail comprobación(es) fallaron."
    exit 1
fi
echo "OK: todas las comprobaciones pasaron."
exit 0
