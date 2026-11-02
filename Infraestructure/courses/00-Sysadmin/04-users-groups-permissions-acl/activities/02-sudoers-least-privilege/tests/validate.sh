#!/usr/bin/env bash
# Validador: comprueba que solution/fixed-sudoers pasa sintaxis
# (visudo -cf) y cumple políticas de mínimo privilegio.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOL="${SCRIPT_DIR}/../solution/fixed-sudoers"

fail=0
ok()  { echo "  OK   $1"; }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }

if [ ! -f "$SOL" ]; then
    echo "FAIL: no existe $SOL" >&2
    exit 1
fi

if ! command -v visudo >/dev/null 2>&1; then
    echo "ERROR: 'visudo' no instalado (apt install sudo / dnf install sudo)" >&2
    exit 1
fi

echo "== Sintaxis =="
if visudo -cf "$SOL" >/dev/null 2>&1; then
    ok "visudo -cf acepta el archivo"
else
    bad "visudo -cf rechaza el archivo:"
    visudo -cf "$SOL" || true
fi

echo
echo "== Política =="

# 1. Define un Cmnd_Alias que contenga NGINX en el nombre
if grep -Eq '^[[:space:]]*Cmnd_Alias[[:space:]]+[A-Z0-9_]*NGINX[A-Z0-9_]*[[:space:]]*=' "$SOL"; then
    ok "define un Cmnd_Alias con 'NGINX' en el nombre"
else
    bad "no se encuentra un Cmnd_Alias cuyo nombre contenga NGINX"
fi

# 2. %webops está autorizado y usa ese alias (no ALL)
if grep -Eq '^[[:space:]]*%webops[[:space:]]+.*=.*' "$SOL"; then
    ok "regla para %webops presente"
else
    bad "no hay regla para %webops"
fi

# 3. No se permite 'ALL' como comando a webops
if grep -Eq '^[[:space:]]*%webops[[:space:]]+.*(NOPASSWD:[[:space:]]*ALL|=[[:space:]]*\(?[A-Za-z:,]*\)?[[:space:]]+ALL[[:space:]]*$)' "$SOL"; then
    bad "%webops tiene permiso ALL (debería ser un alias restringido)"
else
    ok "%webops no tiene permiso ALL"
fi

# 4. Nada de NOPASSWD: ALL en ninguna línea
if grep -Eq 'NOPASSWD:[[:space:]]*ALL\b' "$SOL"; then
    bad "aparece 'NOPASSWD: ALL' (antipatrón)"
else
    ok "no aparece 'NOPASSWD: ALL'"
fi

# 5. Rutas absolutas en todos los comandos (líneas de Cmnd_Alias)
#    Busca comandos sueltos (que no empiezan por '/') dentro de Cmnd_Alias.
awk '
    /^[[:space:]]*Cmnd_Alias/ { inalias=1 }
    inalias {
        line=$0
        # quitar comentarios
        sub(/#.*/, "", line)
        # extraer parte derecha del =
        n = index(line, "=")
        if (n > 0) line = substr(line, n+1)
        # separar por comas
        gsub(/\\$/, "", line)
        split(line, parts, ",")
        for (i in parts) {
            cmd = parts[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
            if (cmd == "") continue
            # primer token
            split(cmd, toks, /[[:space:]]+/)
            first = toks[1]
            if (first !~ /^\//) {
                print "RELATIVE:" first
            }
        }
        # fin de alias si no termina en \
        if (line !~ /\\[[:space:]]*$/) inalias=0
    }
' "$SOL" > /tmp/.sudoers-check.$$ || true

if [ -s /tmp/.sudoers-check.$$ ]; then
    bad "hay comandos con ruta no absoluta:"
    sed 's/^/    /' /tmp/.sudoers-check.$$
else
    ok "todos los comandos usan ruta absoluta"
fi
rm -f /tmp/.sudoers-check.$$

# 6. Comandos prohibidos (shells / editores / systemctl abierto)
forbidden_regex='(/bin/bash|/bin/sh|/usr/bin/bash|/usr/bin/sh|/usr/bin/vim?|/usr/bin/vi|/usr/bin/less|/usr/bin/more|/bin/su\b|/usr/bin/su\b)'
if grep -Eq "$forbidden_regex" "$SOL"; then
    bad "aparecen binarios peligrosos (shell/editor/su):"
    grep -En "$forbidden_regex" "$SOL" | sed 's/^/    /'
else
    ok "sin shells/editores/su autorizados"
fi

# 7. systemctl sin argumento específico -> peligroso
#    (permite poweroff, reboot...). Debe ir siempre con 'restart|reload|status|is-active' + 'nginx'.
if awk '
    /^[[:space:]]*Cmnd_Alias/ { inalias=1 }
    inalias {
        line=$0
        sub(/#.*/, "", line)
        n = index(line, "=")
        if (n>0) line = substr(line, n+1)
        gsub(/\\$/, "", line)
        split(line, parts, ",")
        for (i in parts) {
            cmd = parts[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
            if (cmd ~ /systemctl/) {
                # debe mencionar nginx
                if (cmd !~ /nginx/) { print cmd; found=1 }
            }
        }
        if (line !~ /\\[[:space:]]*$/) inalias=0
    }
    END { exit (found ? 0 : 1) }
' "$SOL" > /tmp/.sudoers-sysctl.$$; then
    bad "systemctl sin acotar a nginx:"
    sed 's/^/    /' /tmp/.sudoers-sysctl.$$
else
    ok "todo systemctl acotado a nginx"
fi
rm -f /tmp/.sudoers-sysctl.$$

echo
if [ "$fail" -gt 0 ]; then
    echo "RESULT: $fail comprobación(es) fallaron."
    exit 1
fi
echo "OK: fixed-sudoers pasa sintaxis y política."
exit 0
