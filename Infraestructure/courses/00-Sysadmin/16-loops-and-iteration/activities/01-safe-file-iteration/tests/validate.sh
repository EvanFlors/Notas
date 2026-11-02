#!/usr/bin/env bash
# Validación automática para sys-16-01-safe-file-iteration.
# Comprueba: existencia del reporte, nº de líneas = nº de archivos regulares (excluyendo el reporte),
# idempotencia (segunda ejecución -> mismo contenido),
# ausencia de /tmp/sys16-pwn (prueba de no-inyección).
#
# Uso: validate.sh [DIR]
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-/tmp/sys16-tricky}"
REPORT="$DIR/report.tsv"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../process.sh"
if [[ ! -f $SCRIPT ]]; then
  SCRIPT="$HERE/../solution/process.sh"
fi

fail=0

echo "== Validación sys-16-01 en $DIR =="

if [[ ! -d $DIR ]]; then
  echo "FAIL: $DIR no existe. Ejecuta starter/make-tricky-files.sh antes."
  exit 1
fi
if [[ ! -x $SCRIPT && ! -f $SCRIPT ]]; then
  echo "FAIL: no se encontró process.sh en $(dirname "$SCRIPT")"
  exit 1
fi

# Baseline: no debe existir /tmp/sys16-pwn
rm -f /tmp/sys16-pwn

# 1a ejecución
bash "$SCRIPT" "$DIR" "$REPORT" > /tmp/sys16-out1 2>&1 || {
  echo "FAIL: process.sh terminó con error en la 1a ejecución"
  cat /tmp/sys16-out1
  exit 1
}
cp -- "$REPORT" "$REPORT.run1"

# 2a ejecución (idempotencia)
bash "$SCRIPT" "$DIR" "$REPORT" > /tmp/sys16-out2 2>&1 || {
  echo "FAIL: process.sh terminó con error en la 2a ejecución"
  cat /tmp/sys16-out2
  exit 1
}

if cmp -s "$REPORT" "$REPORT.run1"; then
  echo "  OK   reporte idempotente entre 2 ejecuciones"
else
  echo "  FAIL reporte difiere entre 2 ejecuciones"
  diff -u "$REPORT.run1" "$REPORT" | head -40 || true
  fail=$((fail + 1))
fi

# Conteo esperado: archivos regulares - el propio report.tsv (y los backups .run1)
expected=$(find "$DIR" -mindepth 1 -maxdepth 1 -type f -print0 \
  | tr -cd '\0' | wc -c)
# Restamos el report y el .run1 (ambos existen ahora)
expected=$((expected - 2))

actual=$(wc -l < "$REPORT" | tr -d ' ')
if [[ $actual -eq $expected ]]; then
  echo "  OK   reporte tiene $actual líneas = $expected archivos reales"
else
  echo "  FAIL reporte tiene $actual líneas, se esperaban $expected"
  fail=$((fail + 1))
fi

# Anti-inyección: /tmp/sys16-pwn no debe existir
if [[ -e /tmp/sys16-pwn ]]; then
  echo "  FAIL /tmp/sys16-pwn fue creado: hubo ejecución de código. Revisa el quoting."
  fail=$((fail + 1))
else
  echo "  OK   ningún efecto lateral de inyección detectado"
fi

# Cada línea debe empezar por un número (tamaño) seguido de TAB
bad_lines=$(grep -cvE $'^[0-9]+\t' "$REPORT" || true)
if [[ $bad_lines -eq 0 ]]; then
  echo "  OK   todas las líneas tienen formato <tamaño>TAB<ruta>"
else
  echo "  FAIL $bad_lines líneas con formato incorrecto"
  fail=$((fail + 1))
fi

# shellcheck (si está disponible)
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT"; then
    echo "  OK   shellcheck limpio"
  else
    echo "  FAIL shellcheck reporta warnings en $SCRIPT"
    fail=$((fail + 1))
  fi
else
  echo "  SKIP shellcheck no instalado"
fi

# Limpieza del backup
rm -f "$REPORT.run1" /tmp/sys16-out1 /tmp/sys16-out2

echo
if [[ $fail -gt 0 ]]; then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK: todas las validaciones pasaron."
