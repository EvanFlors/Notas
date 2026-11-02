#!/usr/bin/env bash
# Validate sys-14-02-shellcheck-cleanup.
# Usage: bash tests/validate.sh [path/to/clean.sh]
# Default: ./clean.sh in CWD. Falls back to the solution if missing.
set -o pipefail

CLEAN="${1:-./clean.sh}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter/dirty.sh"

if [[ ! -f "$CLEAN" ]]; then
    CLEAN="$HERE/../solution/clean.sh"
fi

if [[ ! -f "$CLEAN" ]]; then
    echo "FAIL: no encontré clean.sh"
    exit 1
fi

echo "== Validando: $CLEAN =="

fail=0
pass() { printf '  OK   %s\n' "$*"; }
err()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }

# 1. shebang + flags
if head -n1 "$CLEAN" | grep -q '^#!/usr/bin/env bash'; then
    pass "shebang #!/usr/bin/env bash"
else
    err "shebang incorrecto (se esperaba #!/usr/bin/env bash)"
fi

if grep -qE 'set[[:space:]]+-[a-z]*e[a-z]*u[a-z]*' "$CLEAN" && grep -q 'pipefail' "$CLEAN"; then
    pass "set -euo pipefail presente"
else
    err "falta set -euo pipefail"
fi

# 2. shellcheck -S warning con 0 findings
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "  WARN shellcheck no instalado — este test lo requiere para ser significativo."
    err "shellcheck requerido para validar la actividad"
else
    if shellcheck -S warning "$CLEAN" >/dev/null 2>&1; then
        pass "shellcheck -S warning: 0 findings"
    else
        err "shellcheck -S warning reporta findings:"
        shellcheck -S warning "$CLEAN" || true
    fi
fi

# 3. Equivalencia semántica en stdout contra un directorio de prueba
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

# Generar directorio con contenido predecible
mkdir -p "$sandbox/data/sub1" "$sandbox/data/sub2"
printf 'aaa\n'       > "$sandbox/data/a.txt"
printf 'bbbbbbbbb\n' > "$sandbox/data/b.txt"
printf '%s' "$(head -c 100 /dev/urandom | base64)" > "$sandbox/data/c.bin"

out_dirty=$(bash "$STARTER" "$sandbox/data" 2>/dev/null | sort)
out_clean=$(bash "$CLEAN"   "$sandbox/data" 2>/dev/null | sort)

if [[ "$out_dirty" == "$out_clean" ]]; then
    pass "stdout equivalente al starter en directorio de prueba"
else
    err "stdout difiere del starter"
    echo "--- dirty ---"; echo "$out_dirty"
    echo "--- clean ---"; echo "$out_clean"
fi

# 4. Chequeo de uso: argumento faltante debe fallar (no colgar) con exit != 0
set +e
bash "$CLEAN" </dev/null >/dev/null 2>&1
rc=$?
set -e
if (( rc != 0 )); then
    pass "sin argumentos: exit != 0 (reporta mal uso)"
else
    err "sin argumentos: esperaba exit != 0, obtuve 0"
fi

echo
if (( fail > 0 )); then
    echo "RESULT: $fail check(s) failed."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
