#!/usr/bin/env bash
# Valida la actividad sys-09-02-make-a-scheduled-backup.
# Uso: bash tests/validate.sh <solution-dir>

set -o pipefail

SOL="${1:-./solution}"
fail=0

echo "== Validando directorio: ${SOL} =="

SCRIPT="${SOL}/backup.sh"
SERVICE="${SOL}/backup.service"
TIMER="${SOL}/backup.timer"

for f in "${SCRIPT}" "${SERVICE}" "${TIMER}"; do
    if [[ -f "${f}" ]]; then
        echo "  OK   existe: ${f}"
    else
        echo "  FAIL falta: ${f}"
        fail=$((fail + 1))
    fi
done

# Script style/content
if [[ -f "${SCRIPT}" ]]; then
    first="$(head -n1 "${SCRIPT}" || true)"
    if [[ "${first}" == "#!/usr/bin/env bash" ]]; then
        echo "  OK   backup.sh shebang correcto"
    else
        echo "  FAIL backup.sh no empieza con #!/usr/bin/env bash (encontró: ${first})"
        fail=$((fail + 1))
    fi

    if grep -qE '^set[[:space:]]+-euo[[:space:]]+pipefail' "${SCRIPT}"; then
        echo "  OK   backup.sh declara set -euo pipefail"
    else
        echo "  FAIL backup.sh no declara 'set -euo pipefail'"
        fail=$((fail + 1))
    fi

    for want in "flock" "KEEP" "tar"; do
        if grep -q "${want}" "${SCRIPT}"; then
            echo "  OK   backup.sh referencia '${want}'"
        else
            echo "  FAIL backup.sh no referencia '${want}'"
            fail=$((fail + 1))
        fi
    done

    if command -v shellcheck >/dev/null 2>&1; then
        if shellcheck "${SCRIPT}"; then
            echo "  OK   shellcheck limpio en backup.sh"
        else
            echo "  FAIL shellcheck reportó issues en backup.sh"
            fail=$((fail + 1))
        fi
    else
        echo "  SKIP shellcheck no instalado"
    fi

    # ---- Smoke functional tests ----
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' EXIT

    SRC="${tmpdir}/src"
    DST="${tmpdir}/dst"
    LOCK="${tmpdir}/lock"
    mkdir -p "${SRC}"
    echo "hello" > "${SRC}/a.txt"
    mkdir -p "${SRC}/sub"
    echo "world" > "${SRC}/sub/b.txt"

    echo "  -- smoke: primera ejecución --"
    if SRC="${SRC}" DST="${DST}" KEEP=3 LOCK="${LOCK}" bash "${SCRIPT}"; then
        echo "  OK   backup.sh ejecuta sin error"
    else
        echo "  FAIL backup.sh falló en primera ejecución"
        fail=$((fail + 1))
    fi

    echo "  -- smoke: segunda ejecución (idempotencia) --"
    if SRC="${SRC}" DST="${DST}" KEEP=3 LOCK="${LOCK}" bash "${SCRIPT}"; then
        echo "  OK   segunda ejecución (idempotente) ok"
    else
        echo "  FAIL segunda ejecución falló (no es idempotente)"
        fail=$((fail + 1))
    fi

    count="$(find "${DST}" -maxdepth 1 -name 'backup-*.tar.gz' | wc -l | tr -d ' ')"
    if [[ "${count}" == "1" ]]; then
        echo "  OK   exactamente 1 backup tras dos ejecuciones del mismo día"
    else
        echo "  FAIL se esperaba 1 backup, hay ${count}"
        fail=$((fail + 1))
    fi

    only="$(find "${DST}" -maxdepth 1 -name 'backup-*.tar.gz' | head -n1)"
    if [[ -n "${only}" ]]; then
        if tar -tzf "${only}" | grep -q 'a.txt' && tar -tzf "${only}" | grep -q 'b.txt'; then
            echo "  OK   tarball contiene a.txt y b.txt"
        else
            echo "  FAIL tarball no contiene los archivos esperados"
            fail=$((fail + 1))
        fi
    fi

    # Rotation test: inject fake old backups and re-run with KEEP=3.
    echo "  -- smoke: rotación con 5 backups falsos + KEEP=3 --"
    for d in 2000-01-01 2000-01-02 2000-01-03 2000-01-04 2000-01-05; do
        fname="${DST}/backup-${d}.tar.gz"
        # Use a tiny valid gzip so file still looks real.
        printf '' | gzip -c > "${fname}"
    done
    SRC="${SRC}" DST="${DST}" KEEP=3 LOCK="${LOCK}" bash "${SCRIPT}" >/dev/null || true
    final_count="$(find "${DST}" -maxdepth 1 -name 'backup-*.tar.gz' | wc -l | tr -d ' ')"
    if [[ "${final_count}" -le 3 ]]; then
        echo "  OK   rotación respeta KEEP=3 (quedan ${final_count})"
    else
        echo "  FAIL rotación no respeta KEEP=3 (quedan ${final_count})"
        fail=$((fail + 1))
    fi

    rm -rf "${tmpdir}"
    trap - EXIT
fi

# Service checks
if [[ -f "${SERVICE}" ]]; then
    for want in "Type=oneshot" "ExecStart=/usr/local/bin/backup.sh" "StandardOutput=journal"; do
        if grep -qF "${want}" "${SERVICE}"; then
            echo "  OK   service tiene '${want}'"
        else
            echo "  FAIL service no tiene '${want}'"
            fail=$((fail + 1))
        fi
    done
fi

# Timer checks
if [[ -f "${TIMER}" ]]; then
    for want in "OnCalendar=" "Persistent=true" "WantedBy=timers.target"; do
        if grep -qF "${want}" "${TIMER}"; then
            echo "  OK   timer tiene '${want}'"
        else
            echo "  FAIL timer no tiene '${want}'"
            fail=$((fail + 1))
        fi
    done
fi

# systemd-analyze opcional
if command -v systemd-analyze >/dev/null 2>&1; then
    if systemd-analyze verify "${SERVICE}" "${TIMER}" 2>/tmp/sa-verify.$$; then
        echo "  OK   systemd-analyze verify sin errores"
    else
        if [[ -s /tmp/sa-verify.$$ ]]; then
            echo "  WARN systemd-analyze reportó (no bloquea):"
            sed 's/^/      /' /tmp/sa-verify.$$ || true
        fi
    fi
    rm -f /tmp/sa-verify.$$
else
    echo "  SKIP systemd-analyze no disponible"
fi

echo
if [[ "${fail}" -gt 0 ]]; then
    echo "RESULT: ${fail} check(s) fallaron."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
