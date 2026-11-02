#!/usr/bin/env bash
# sys-10-02 — Valida respuestas de triage.
# Lee starter/answers.md y comprueba layer: por caso.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSWERS="${HERE}/../starter/answers.md"

declare -A EXPECTED=(
    [case1]="dns"
    [case2]="route"
    [case3]="tls"
)

fail=0

if [[ ! -f "${ANSWERS}" ]]; then
    echo "FAIL: no existe ${ANSWERS}"
    exit 1
fi

echo "== Validando sys-10-02 =="

# Parse by section: ## caseN  ...  layer: X
for case in case1 case2 case3; do
    want="${EXPECTED[${case}]}"
    # Extraer el bloque desde "## caseN" hasta la siguiente "## " o EOF
    got="$(awk -v tag="## ${case}" '
        $0 == tag {inblk=1; next}
        inblk && /^## / {exit}
        inblk && /^layer:/ {print $2; exit}
    ' "${ANSWERS}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"

    if [[ -z "${got}" ]]; then
        echo "  FAIL ${case}: no encontré 'layer:' en el bloque."
        fail=$((fail+1))
        continue
    fi

    if [[ "${got}" == "${want}" ]]; then
        echo "  OK   ${case}: layer=${got}"
    else
        echo "  FAIL ${case}: layer='${got}' (esperado '${want}')"
        fail=$((fail+1))
    fi

    # probe y root_cause no se validan literal, pero deben no estar en TODO
    probe="$(awk -v tag="## ${case}" '
        $0 == tag {inblk=1; next}
        inblk && /^## / {exit}
        inblk && /^probe:/ {sub(/^probe:[[:space:]]*/,""); print; exit}
    ' "${ANSWERS}")"
    root="$(awk -v tag="## ${case}" '
        $0 == tag {inblk=1; next}
        inblk && /^## / {exit}
        inblk && /^root_cause:/ {sub(/^root_cause:[[:space:]]*/,""); print; exit}
    ' "${ANSWERS}")"

    if [[ -z "${probe}" || "${probe}" == "TODO" ]]; then
        echo "  FAIL ${case}: 'probe:' vacío o TODO."
        fail=$((fail+1))
    else
        echo "  OK   ${case}: probe presente."
    fi
    if [[ -z "${root}" || "${root}" == "TODO" ]]; then
        echo "  FAIL ${case}: 'root_cause:' vacío o TODO."
        fail=$((fail+1))
    else
        echo "  OK   ${case}: root_cause presente."
    fi
done

echo
if [[ "${fail}" -gt 0 ]]; then
    echo "RESULT: ${fail} check(s) fallaron."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
