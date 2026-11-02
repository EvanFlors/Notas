#!/usr/bin/env bash
#
# validate.sh — comprueba la CLI de la actividad sys-18-01.
#
# Valida contra `starter/mytool.sh` por defecto; con TARGET=solution usa la
# solución de referencia (útil para auto-verificar los tests).
#
set -uo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TARGET="${TARGET:-starter}"
SCRIPT="$ROOT/$TARGET/mytool.sh"

fail=0
pass=0

[[ -x "$SCRIPT" ]] || chmod +x "$SCRIPT" 2>/dev/null || true
[[ -f "$SCRIPT" ]] || { echo "FAIL: no existe $SCRIPT"; exit 1; }

check() {
    # check "descripción" expected_rc "stream" "needle" -- cmd...
    local desc=$1 want_rc=$2 stream=$3 needle=$4
    shift 4
    shift   # consume el "--"

    local stdout stderr rc
    local tmp_out tmp_err
    tmp_out=$(mktemp)
    tmp_err=$(mktemp)

    "$@" >"$tmp_out" 2>"$tmp_err"
    rc=$?

    stdout=$(cat "$tmp_out")
    stderr=$(cat "$tmp_err")
    rm -f "$tmp_out" "$tmp_err"

    local ok=1
    if [[ "$rc" -ne "$want_rc" ]]; then
        ok=0
    fi

    if [[ -n "$needle" ]]; then
        case "$stream" in
            stdout) [[ "$stdout" == *"$needle"* ]] || ok=0 ;;
            stderr) [[ "$stderr" == *"$needle"* ]] || ok=0 ;;
            any)    [[ "$stdout$stderr" == *"$needle"* ]] || ok=0 ;;
        esac
    fi

    if (( ok )); then
        printf '  PASS  %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf '  FAIL  %s\n' "$desc"
        printf '        rc=%d (esperado %d)\n' "$rc" "$want_rc"
        [[ -n "$needle" ]] && printf '        buscaba "%s" en %s\n' "$needle" "$stream"
        printf '        stdout: %s\n' "$stdout" | head -c 300
        printf '\n        stderr: %s\n' "$stderr" | head -c 300
        fail=$((fail + 1))
    fi
}

echo "Validando $SCRIPT"

# 1. -h sale 0 y escribe "Uso" en stdout
check "-h muestra ayuda y exit 0" 0 stdout "Uso:" -- bash "$SCRIPT" -h

# 2. ejecución correcta
check "ejecución normal: -o out ARG -> exit 0" 0 stdout "iter 1" -- \
    bash "$SCRIPT" -o out.txt hola

# 3. count=3 produce 3 iteraciones (buscamos "iter 3")
check "-n 3 produce iter 3" 0 stdout "iter 3" -- \
    bash "$SCRIPT" -o out.txt -n 3 hola

# 4. flag desconocido -> exit 2 + mensaje a stderr
check "flag desconocido -> exit 2" 2 stderr "Error" -- \
    bash "$SCRIPT" -x

# 5. opción sin argumento -> exit 2
check "-o sin argumento -> exit 2" 2 stderr "Error" -- \
    bash "$SCRIPT" -o

# 6. -o requerido
check "falta -o -> exit 2" 2 stderr "Error" -- \
    bash "$SCRIPT" hola

# 7. count no entero -> exit 2
check "COUNT no entero -> exit 2" 2 stderr "Error" -- \
    bash "$SCRIPT" -o out.txt -n cero hola

# 8. ARG posicional faltante -> exit 2
check "falta ARG posicional -> exit 2" 2 stderr "Error" -- \
    bash "$SCRIPT" -o out.txt

# 9. "--" permite ARG que empiece por "-"
check "-- permite ARG con guion" 0 stdout "iter 1" -- \
    bash "$SCRIPT" -o out.txt -- -arg-con-guion

# 10. verbose emite a stderr, no a stdout
tmp_out=$(mktemp); tmp_err=$(mktemp)
bash "$SCRIPT" -v -o out.txt hola >"$tmp_out" 2>"$tmp_err" || true
if grep -q "verbose" "$tmp_err" && ! grep -q "verbose" "$tmp_out"; then
    echo "  PASS  -v loguea a stderr y no a stdout"
    pass=$((pass + 1))
else
    echo "  FAIL  -v debe loguear a stderr, no a stdout"
    fail=$((fail + 1))
fi
rm -f "$tmp_out" "$tmp_err"

echo
echo "Resultado: $pass OK, $fail FAIL"
if (( fail == 0 )); then
    echo "OK"
    exit 0
else
    exit 1
fi
