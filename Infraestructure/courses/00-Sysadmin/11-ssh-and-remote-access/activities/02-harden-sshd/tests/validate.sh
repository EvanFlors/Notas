#!/usr/bin/env bash
# Validate: sys-11-02-harden-sshd
# Uso:  bash tests/validate.sh <sshd_config>
# 1) sintaxis con `sshd -t -f`.
# 2) directivas minimas presentes con el valor adecuado.

set -euo pipefail

CFG="${1:-sshd_config.hardened}"
fail=0

echo "== Validando: $CFG =="

if [ ! -f "$CFG" ]; then
    echo "FAIL: no existe el archivo '$CFG'."
    exit 1
fi

# Localizar sshd (no esta siempre en PATH de usuario)
SSHD_BIN=""
for p in sshd /usr/sbin/sshd /usr/local/sbin/sshd /opt/homebrew/sbin/sshd; do
    if command -v "$p" >/dev/null 2>&1; then
        SSHD_BIN="$(command -v "$p")"
        break
    fi
done

if [ -n "$SSHD_BIN" ]; then
    # `sshd -t -f` tambien verifica que existan hostkeys reales en el sistema;
    # en una maquina de alumno sin hostkeys propias, eso emite:
    #   "sshd: no hostkeys available -- exiting."
    # Ese error NO es un problema de sintaxis, lo filtramos.
    out="$("$SSHD_BIN" -t -f "$CFG" 2>&1 || true)"
    syntax_err="$(printf '%s\n' "$out" | grep -viE 'no hostkeys available|could not load host key' || true)"
    if [ -z "$syntax_err" ]; then
        echo "  OK   sintaxis valida ($SSHD_BIN -t -f)"
    else
        echo "  FAIL sintaxis invalida:"
        printf '%s\n' "$syntax_err" | sed 's/^/      /'
        fail=$((fail+1))
    fi
else
    echo "  WARN sshd no encontrado en PATH; omito validacion de sintaxis."
fi

# Devuelve el ultimo valor de una directiva (gana el ultimo en sshd_config),
# ignorando comentarios y lineas en blanco. Case-insensitive en la clave.
get() {
    local key="$1"
    awk -v k="$key" '
        BEGIN{IGNORECASE=1}
        /^[[:space:]]*#/ {next}
        /^[[:space:]]*$/ {next}
        {
            kk=$1
            if (tolower(kk)==tolower(k)) {
                $1=""; sub(/^[[:space:]]+/,""); val=$0
            }
        }
        END{ print val }
    ' "$CFG"
}

check_eq() {
    local label="$1" expected="$2" actual
    actual="$(get "$label")"
    if [ "$actual" = "$expected" ]; then
        echo "  OK   $label = $actual"
    else
        echo "  FAIL $label: esperado '$expected', obtenido '$actual'"
        fail=$((fail+1))
    fi
}

check_in_range() {
    local label="$1" min="$2" max="$3" actual
    actual="$(get "$label")"
    if [[ "$actual" =~ ^[0-9]+$ ]] && [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
        echo "  OK   $label = $actual (en [$min, $max])"
    else
        echo "  FAIL $label='$actual' fuera de [$min, $max]"
        fail=$((fail+1))
    fi
}

check_le() {
    local label="$1" max="$2" actual
    actual="$(get "$label")"
    if [[ "$actual" =~ ^[0-9]+$ ]] && [ "$actual" -le "$max" ]; then
        echo "  OK   $label = $actual (<= $max)"
    else
        echo "  FAIL $label='$actual' no es <= $max"
        fail=$((fail+1))
    fi
}

check_eq "PermitRootLogin"              "no"
check_eq "PasswordAuthentication"       "no"
check_eq "KbdInteractiveAuthentication" "no"
check_eq "PermitEmptyPasswords"         "no"
check_eq "PubkeyAuthentication"         "yes"
check_eq "X11Forwarding"                "no"
check_eq "AllowAgentForwarding"         "no"
check_eq "LogLevel"                     "VERBOSE"
check_in_range "ClientAliveInterval" 60 600
check_in_range "ClientAliveCountMax" 1 3
check_le       "LoginGraceTime"      30
check_le       "MaxAuthTries"        4

# Protocol: ausente, o exactamente "2"
proto="$(get Protocol)"
if [ -z "$proto" ] || [ "$proto" = "2" ]; then
    echo "  OK   Protocol = '${proto:-<unset>}'"
else
    echo "  FAIL Protocol='$proto' (esperado ausente o 2; nunca incluir 1)"
    fail=$((fail+1))
fi

# AllowUsers debe incluir deploy y evan
allow="$(get AllowUsers)"
for u in deploy evan; do
    if echo " $allow " | grep -qE "[[:space:]]${u}[[:space:]]"; then
        echo "  OK   AllowUsers contiene '$u'"
    else
        echo "  FAIL AllowUsers no contiene '$u' (valor: '$allow')"
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
