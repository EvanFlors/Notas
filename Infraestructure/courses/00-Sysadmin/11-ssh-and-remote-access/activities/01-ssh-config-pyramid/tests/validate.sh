#!/usr/bin/env bash
# Validate: sys-11-01-ssh-config-pyramid
# Uso:  bash tests/validate.sh <ssh-config>
# Comprueba estaticamente (ssh -G) que el config propuesto resuelve
# correctamente para los alias bastion.example.com, app1, app2, db1.

set -euo pipefail

CFG="${1:-ssh-config}"
fail=0

echo "== Validando archivo: $CFG =="

if [ ! -f "$CFG" ]; then
    echo "FAIL: no existe el archivo '$CFG'."
    exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
    echo "FAIL: no se encuentra el binario 'ssh' en PATH."
    exit 1
fi

# Devuelve el valor efectivo de una directiva para un alias dado.
get() {
    local alias="$1" key="$2"
    ssh -G "$alias" -F "$CFG" 2>/dev/null \
        | awk -v k="$key" 'tolower($1)==tolower(k){ $1=""; sub(/^ +/,""); print; exit }'
}

check_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  OK   $label = $actual"
    else
        echo "  FAIL $label: esperado '$expected', obtenido '$actual'"
        fail=$((fail+1))
    fi
}

check_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  OK   $label contiene '$needle'"
    else
        echo "  FAIL $label no contiene '$needle' (valor: '$haystack')"
        fail=$((fail+1))
    fi
}

echo "-- bastion.example.com --"
check_eq   "user"       "jump"                                "$(get bastion.example.com user)"
check_eq   "hostname"   "bastion.example.com"                 "$(get bastion.example.com hostname)"
check_contains "identityfile" "id_ed25519_bastion"            "$(get bastion.example.com identityfile)"
# bastion no debe tener ProxyJump
pj_bastion="$(get bastion.example.com proxyjump)"
if [ -z "$pj_bastion" ] || [ "$pj_bastion" = "none" ]; then
    echo "  OK   bastion sin ProxyJump"
else
    echo "  FAIL bastion tiene ProxyJump='$pj_bastion' (no deberia)"
    fail=$((fail+1))
fi

for host in app1 app2 db1; do
    echo "-- $host --"
    case "$host" in
        app1) want_ip="10.0.1.10"; want_user="deploy";  want_key="id_ed25519_app1" ;;
        app2) want_ip="10.0.1.11"; want_user="deploy";  want_key="id_ed25519_app2" ;;
        db1)  want_ip="10.0.2.10"; want_user="dbadmin"; want_key="id_ed25519_db1"  ;;
    esac
    check_eq       "user"          "$want_user"             "$(get "$host" user)"
    check_eq       "hostname"      "$want_ip"               "$(get "$host" hostname)"
    check_contains "identityfile"  "$want_key"              "$(get "$host" identityfile)"
    check_eq       "proxyjump"     "bastion.example.com"    "$(get "$host" proxyjump)"
done

# IdentitiesOnly debe estar activo en los bloques especificos.
for host in bastion.example.com app1 app2 db1; do
    val="$(get "$host" identitiesonly)"
    if [ "$val" = "yes" ]; then
        echo "  OK   $host IdentitiesOnly=yes"
    else
        echo "  FAIL $host IdentitiesOnly='$val' (esperado yes)"
        fail=$((fail+1))
    fi
done

echo
if [ "$fail" -gt 0 ]; then
    echo "RESULT: $fail chequeo(s) fallaron."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
