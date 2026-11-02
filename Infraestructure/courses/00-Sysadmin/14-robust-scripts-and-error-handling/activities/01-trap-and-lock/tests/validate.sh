#!/usr/bin/env bash
# Validate sys-14-01-trap-and-lock.
# Usage: bash tests/validate.sh [path/to/job.sh]
# Default: ./job.sh in CWD. Falls back to the solution if missing.
set -o pipefail

JOB="${1:-./job.sh}"
if [[ ! -f "$JOB" ]]; then
    # fallback: validar la solución (útil para CI del propio curso)
    JOB="$(dirname "$0")/../solution/job.sh"
fi

if [[ ! -f "$JOB" ]]; then
    echo "FAIL: no encontré job.sh (ni $1 ni la solución)."
    exit 1
fi

JOB=$(readlink -f "$JOB" 2>/dev/null || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$JOB")
echo "== Validando: $JOB =="

fail=0
pass() { printf '  OK   %s\n' "$*"; }
err()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }

# Sandbox
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export OUT_DIR="$work/out"
export LOCK_FILE="$work/job.lock"

# 1. shebang + set flags
if head -n1 "$JOB" | grep -q '^#!/usr/bin/env bash'; then
    pass "shebang #!/usr/bin/env bash"
else
    err "shebang incorrecto o ausente"
fi

if grep -qE 'set[[:space:]]+-[a-z]*e[a-z]*u[a-z]*' "$JOB" && grep -q 'pipefail' "$JOB"; then
    pass "set -euo pipefail presente"
else
    err "falta set -euo pipefail"
fi

if grep -q "IFS=\$'\\\\n\\\\t'" "$JOB" || grep -q 'IFS=$'"'"'\\n\\t'"'" "$JOB"; then
    pass "IFS endurecido"
else
    err "falta IFS=\$'\\n\\t'"
fi

# 2. shellcheck -S warning
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$JOB" >/dev/null 2>&1; then
        pass "shellcheck -S warning sin findings"
    else
        err "shellcheck -S warning reporta findings:"
        shellcheck -S warning "$JOB" || true
    fi
else
    echo "  WARN shellcheck no instalado; saltando chequeo (instala util/paquete 'shellcheck')"
fi

# 3. Caso feliz: exit 0 + sin tmpdir residual
pre_tmp=$(find /tmp -maxdepth 1 -name 'job-tmp.*' 2>/dev/null | wc -l | tr -d ' ')
if bash "$JOB" >/dev/null 2>&1; then
    post_tmp=$(find /tmp -maxdepth 1 -name 'job-tmp.*' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$pre_tmp" == "$post_tmp" ]]; then
        pass "caso feliz: exit 0 y tmpdir limpio"
    else
        err "caso feliz: quedaron tmpdirs residuales ($pre_tmp → $post_tmp)"
    fi
    if [[ -f "$OUT_DIR/report.txt" ]]; then
        pass "report.txt escrito en OUT_DIR"
    else
        err "no se escribió $OUT_DIR/report.txt"
    fi
else
    err "caso feliz: exit != 0"
fi

# 4. Concurrencia: segunda invocación debe salir con 75
SLOW=3 bash "$JOB" >/dev/null 2>&1 &
bg_pid=$!
sleep 1
set +e
bash "$JOB" >/dev/null 2>&1
second_rc=$?
set -e
wait "$bg_pid" || true
if [[ "$second_rc" == "75" ]]; then
    pass "concurrencia: segunda instancia exit 75 (EX_TEMPFAIL)"
else
    err "concurrencia: esperaba exit 75, obtuve $second_rc"
fi

# 5. SIGINT: cleanup corre y exit 130
pre_tmp=$(find /tmp -maxdepth 1 -name 'job-tmp.*' 2>/dev/null | wc -l | tr -d ' ')
SLOW=10 bash "$JOB" >/dev/null 2>&1 &
sig_pid=$!
sleep 1
kill -INT "$sig_pid" 2>/dev/null || true
set +e
wait "$sig_pid"
sig_rc=$?
set -e
post_tmp=$(find /tmp -maxdepth 1 -name 'job-tmp.*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$sig_rc" == "130" ]]; then
    pass "SIGINT: exit 130"
else
    err "SIGINT: esperaba exit 130, obtuve $sig_rc"
fi
if [[ "$pre_tmp" == "$post_tmp" ]]; then
    pass "SIGINT: tmpdir limpio tras cleanup"
else
    err "SIGINT: quedaron tmpdirs residuales ($pre_tmp → $post_tmp)"
fi

echo
if (( fail > 0 )); then
    echo "RESULT: $fail check(s) failed."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
