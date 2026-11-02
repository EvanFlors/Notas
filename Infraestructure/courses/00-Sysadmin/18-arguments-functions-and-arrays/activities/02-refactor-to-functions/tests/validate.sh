#!/usr/bin/env bash
#
# validate.sh — comprueba la refactorización de sys-18-02.
#
# Elige, en orden:
#   1. starter/refactored.sh (si existe)
#   2. starter/monolith.sh  (asumiendo que el alumno editó in situ)
# Puede sobrescribirse con TARGET=solution/refactored.sh
#
# Requisitos:
#   - Bash 4+ (asociativos). Si no, intenta /opt/homebrew/bin/bash o /usr/local/bin/bash.
#
set -uo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

pick_bash() {
    local candidate
    for candidate in bash /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash; do
        if command -v "$candidate" >/dev/null 2>&1; then
            # ¿Soporta assoc arrays?
            if "$candidate" -c 'set -e; declare -A m; m[x]=1' 2>/dev/null; then
                echo "$candidate"
                return 0
            fi
        fi
    done
    echo ""
}

BASH_BIN="$(pick_bash)"
if [[ -z "$BASH_BIN" ]]; then
    echo "FAIL: necesito bash 4+ con soporte de arrays asociativos" >&2
    exit 1
fi

if [[ -n "${TARGET:-}" ]]; then
    SCRIPT="$ROOT/$TARGET"
elif [[ -f "$ROOT/starter/refactored.sh" ]]; then
    SCRIPT="$ROOT/starter/refactored.sh"
elif [[ -f "$ROOT/starter/monolith.sh" ]]; then
    SCRIPT="$ROOT/starter/monolith.sh"
else
    echo "FAIL: no encontré script a validar" >&2
    exit 1
fi

MONOLITH="$ROOT/starter/monolith.sh"

echo "Validando $SCRIPT  (bash: $BASH_BIN)"

fail=0
pass=0

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# --------- 1. Chequeos estructurales ---------
if grep -qE '^[[:space:]]*declare[[:space:]]+-A[[:space:]]+CONFIG' "$SCRIPT"; then
    ok "define 'declare -A CONFIG'"
else
    nope "falta 'declare -A CONFIG'"
fi

fn_count=$(grep -cE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{?' "$SCRIPT" || true)
if (( fn_count >= 5 )); then
    ok "al menos 5 funciones definidas ($fn_count)"
else
    nope "esperaba >=5 funciones, encontré $fn_count"
fi

local_count=$(grep -cE '^[[:space:]]*local[[:space:]]+' "$SCRIPT" || true)
if (( local_count >= 5 )); then
    ok "usa 'local' al menos 5 veces ($local_count)"
else
    nope "esperaba >=5 usos de 'local', encontré $local_count"
fi

# Última línea no vacía debe ser 'main "$@"' (acepta comillas simples o dobles)
last_line="$(grep -vE '^[[:space:]]*$' "$SCRIPT" | tail -1)"
if [[ "$last_line" =~ ^[[:space:]]*main[[:space:]]+\"?\$@\"?[[:space:]]*$ ]]; then
    ok "última línea es 'main \"\$@\"'"
else
    nope "la última línea debería ser 'main \"\$@\"' (encontré: $last_line)"
fi

# --------- 2. Equivalencia de salida con el monolito ---------
run_both() {
    local label=$1; shift
    local a b rc_a rc_b
    a=$("$BASH_BIN" "$MONOLITH" "$@" 2>&1); rc_a=$?
    b=$("$BASH_BIN" "$SCRIPT"   "$@" 2>&1); rc_b=$?
    if [[ "$rc_a" -eq "$rc_b" && "$a" == "$b" ]]; then
        ok "equivale al monolito: $label"
    else
        nope "diverge del monolito: $label (rc $rc_a vs $rc_b)"
        diff <(echo "$a") <(echo "$b") | sed 's/^/        /' | head -20
    fi
}

run_both "-e dev -a app-1.0"   -e dev   -a app-1.0
run_both "-e stage -a app-1.0" -e stage -a app-1.0
run_both "-e prod -a app-1.0 -d" -e prod -a app-1.0 -d
run_both "-e marte -a x (inválido)" -e marte -a x

# -h: no exigimos equivalencia byte-a-byte (el nombre del binario cambia y
# el refactor añade 'qa' a la lista); solo exit 0 y que contenga "Uso".
h_out=$("$BASH_BIN" "$SCRIPT" -h 2>&1); h_rc=$?
if [[ "$h_rc" -eq 0 && "$h_out" == *"Uso"* ]]; then
    ok "-h imprime ayuda y sale 0"
else
    nope "-h debería imprimir ayuda y salir 0 (rc=$h_rc)"
fi

# --------- 3. Entorno nuevo 'qa' en el array ---------
out=$("$BASH_BIN" "$SCRIPT" -e qa -a app-1.0 2>&1)
rc=$?
if [[ "$rc" -eq 0 && "$out" == *"qa.example.com"* && "$out" == *"PUBLICANDO"* ]]; then
    ok "soporta entorno 'qa' vía CONFIG (sin tocar lógica)"
else
    nope "entorno 'qa' no funciona (rc=$rc). Esperaba host qa.example.com en la salida."
    echo "$out" | head -20 | sed 's/^/        /'
fi

echo
echo "Resultado: $pass OK, $fail FAIL"
if (( fail == 0 )); then
    echo "OK"
    exit 0
else
    exit 1
fi
