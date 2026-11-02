#!/usr/bin/env bash
# Valida la actividad sys-09-01-cron-to-timer-migration.
# Uso: bash tests/validate.sh <solution-dir>
# Si se omite el argumento, intenta ./solution relativo al cwd actual.

set -o pipefail

SOL="${1:-./solution}"
fail=0

echo "== Validando directorio: ${SOL} =="

if [[ ! -d "${SOL}" ]]; then
    echo "FAIL: no existe el directorio ${SOL}"
    exit 1
fi

TIMER="${SOL}/backup.timer"
SERVICE="${SOL}/backup.service"
INSTALL="${SOL}/install.sh"

for f in "${TIMER}" "${SERVICE}" "${INSTALL}"; do
    if [[ -f "${f}" ]]; then
        echo "  OK   existe: ${f}"
    else
        echo "  FAIL falta: ${f}"
        fail=$((fail + 1))
    fi
done

# install.sh style
if [[ -f "${INSTALL}" ]]; then
    first="$(head -n1 "${INSTALL}" || true)"
    if [[ "${first}" == "#!/usr/bin/env bash" ]]; then
        echo "  OK   install.sh usa shebang #!/usr/bin/env bash"
    else
        echo "  FAIL install.sh no empieza con #!/usr/bin/env bash (encontró: ${first})"
        fail=$((fail + 1))
    fi

    if grep -qE '^set[[:space:]]+-euo[[:space:]]+pipefail' "${INSTALL}"; then
        echo "  OK   install.sh declara set -euo pipefail"
    else
        echo "  FAIL install.sh no declara 'set -euo pipefail'"
        fail=$((fail + 1))
    fi

    if command -v shellcheck >/dev/null 2>&1; then
        if shellcheck "${INSTALL}"; then
            echo "  OK   shellcheck limpio en install.sh"
        else
            echo "  FAIL shellcheck reportó issues en install.sh"
            fail=$((fail + 1))
        fi
    else
        echo "  SKIP shellcheck no instalado"
    fi
fi

# Service checks
if [[ -f "${SERVICE}" ]]; then
    for want in "Type=oneshot" "User=root" "Environment=PATH="; do
        if grep -qF "${want}" "${SERVICE}"; then
            echo "  OK   service tiene '${want}'"
        else
            echo "  FAIL service no tiene '${want}'"
            fail=$((fail + 1))
        fi
    done
    if grep -qE '^ExecStart=/usr/local/bin/backup\.sh[[:space:]]+--target[[:space:]]+/srv/data[[:space:]]+--dest[[:space:]]+/var/backups/data' "${SERVICE}"; then
        echo "  OK   service tiene ExecStart correcto"
    else
        echo "  FAIL service no tiene ExecStart esperado"
        fail=$((fail + 1))
    fi
fi

# Timer checks
if [[ -f "${TIMER}" ]]; then
    if grep -qE '^OnCalendar=.*02:30' "${TIMER}"; then
        echo "  OK   timer tiene OnCalendar con 02:30"
    else
        echo "  FAIL timer no tiene OnCalendar=... 02:30"
        fail=$((fail + 1))
    fi
    for want in "Persistent=true" "RandomizedDelaySec=10min" "WantedBy=timers.target"; do
        if grep -qF "${want}" "${TIMER}"; then
            echo "  OK   timer tiene '${want}'"
        else
            echo "  FAIL timer no tiene '${want}'"
            fail=$((fail + 1))
        fi
    done
fi

# systemd-analyze verify (opcional, requiere systemd)
if command -v systemd-analyze >/dev/null 2>&1; then
    if systemd-analyze verify "${SERVICE}" "${TIMER}" 2>/tmp/sa-verify.$$; then
        echo "  OK   systemd-analyze verify sin errores"
    else
        if [[ -s /tmp/sa-verify.$$ ]]; then
            echo "  WARN systemd-analyze reportó (no bloquea en entornos sin systemd corriendo):"
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
