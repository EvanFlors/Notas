#!/usr/bin/env bash
# validate.sh — comprueba que el alumno completó sys-08-01 correctamente.
# Requiere sudo.

set -o pipefail
IFS=$'\n\t'

MNT="/mnt/sys08-01"
VG="vg_grow"
LV="lv_app"
fail=0

echo "== Validando actividad sys-08-01 =="

if [[ "${EUID}" -ne 0 ]]; then
  echo "FAIL: ejecuta con sudo." >&2
  exit 2
fi

# 1. VG existe
if vgs "${VG}" >/dev/null 2>&1; then
  echo "  OK   VG '${VG}' existe"
else
  echo "  FAIL VG '${VG}' no existe"
  fail=$((fail+1))
fi

# 2. VG tiene >=2 PVs
pv_count="$(vgs --noheadings -o pv_count "${VG}" 2>/dev/null | tr -d ' ' || echo 0)"
if [[ "${pv_count}" -ge 2 ]]; then
  echo "  OK   VG tiene ${pv_count} PVs (>=2)"
else
  echo "  FAIL VG tiene ${pv_count} PV(s) (se esperaba >=2)"
  fail=$((fail+1))
fi

# 3. LV existe y >= 900 MiB
lv_size_m="$(lvs --noheadings --units m --nosuffix -o lv_size "${VG}/${LV}" 2>/dev/null | awk '{print int($1)}' || echo 0)"
if [[ "${lv_size_m}" -ge 900 ]]; then
  echo "  OK   LV '${LV}' tiene ${lv_size_m} MiB (>=900)"
else
  echo "  FAIL LV '${LV}' tiene ${lv_size_m} MiB (se esperaba >=900)"
  fail=$((fail+1))
fi

# 4. Está montado
if mountpoint -q "${MNT}"; then
  echo "  OK   ${MNT} está montado"
else
  echo "  FAIL ${MNT} no está montado"
  fail=$((fail+1))
fi

# 5. El fs refleja el nuevo tamaño (>=800 MiB disponibles+usados)
fs_size_m="$(df -BM --output=size "${MNT}" 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
if [[ "${fs_size_m}" -ge 800 ]]; then
  echo "  OK   filesystem reporta ${fs_size_m} MiB totales (>=800)"
else
  echo "  FAIL filesystem reporta ${fs_size_m} MiB (se esperaba >=800) — ¿faltó resize2fs?"
  fail=$((fail+1))
fi

# 6. Archivo de prueba sigue vivo
if [[ -f "${MNT}/README-prueba.txt" ]] && grep -q "sobreviven" "${MNT}/README-prueba.txt"; then
  echo "  OK   README-prueba.txt íntegro"
else
  echo "  FAIL README-prueba.txt ausente o corrupto"
  fail=$((fail+1))
fi

# 7. Filesystem usable (write + read)
TESTFILE="${MNT}/.validate-write-$$"
if echo "ok" > "${TESTFILE}" && [[ "$(cat "${TESTFILE}")" == "ok" ]]; then
  echo "  OK   filesystem usable (write+read)"
  rm -f "${TESTFILE}"
else
  echo "  FAIL filesystem no acepta escrituras"
  fail=$((fail+1))
fi

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULT: ${fail} check(s) fallaron."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
