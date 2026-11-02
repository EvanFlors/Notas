#!/usr/bin/env bash
# Valida la actividad 02:
#  1. new.sh produce el mismo stdout que old.sh.
#  2. new.sh no deja temporales en /tmp (patrones del enunciado).
#  3. new.sh no contiene llamadas a mktemp ni rutas /tmp.
#  4. shellcheck pasa (si está instalado).

set -euo pipefail
IFS=$'\n\t'

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
activity_dir="$(cd "$here/.." && pwd)"

old="$activity_dir/starter/old.sh"
if [[ -f "$activity_dir/starter/new.sh" ]]; then
  new="$activity_dir/starter/new.sh"
else
  new="$activity_dir/solution/new.sh"
fi

for f in "$old" "$new"; do
  [[ -f $f ]] || { echo "ERROR: no encuentro $f" >&2; exit 2; }
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

run_dir_old="$workdir/old"
run_dir_new="$workdir/new"
mkdir -p "$run_dir_old" "$run_dir_new"

echo "== 1. stdout: new.sh vs old.sh =="
if diff <(bash "$old" "$run_dir_old/out" 2>/dev/null) \
        <(bash "$new" "$run_dir_new/out" 2>/dev/null); then
  echo "  OK (stdout idéntico)"
else
  echo "  FAIL: stdout difiere" >&2
  exit 1
fi

echo
echo "== 2. no leftovers en /tmp tras new.sh =="
# Snapshot: nombres antes
before="$(ls /tmp 2>/dev/null | sort)"
bash "$new" "$workdir/clean_run" >/dev/null 2>&1
after="$(ls /tmp 2>/dev/null | sort)"

# Diff: entradas nuevas
new_entries="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true)"
# Filtrar sólo nombres sospechosos del enunciado
suspects="$(printf '%s\n' "$new_entries" | grep -E '^(oracle_[ab]\.|payload(_gz|_sha)?\.)' || true)"
if [[ -n $suspects ]]; then
  echo "  FAIL: new.sh dejó archivos en /tmp:" >&2
  printf '    %s\n' $suspects >&2
  exit 1
fi
echo "  OK (sin leftovers)"

echo
echo "== 3. new.sh no usa mktemp ni rutas /tmp =="
# shellcheck disable=SC2016
if grep -nE '\bmktemp\b|/tmp/' "$new"; then
  echo "  FAIL: new.sh contiene mktemp o /tmp/ (debe evitar temporales)" >&2
  exit 1
fi
echo "  OK (sin mktemp ni /tmp/)"

echo
echo "== 4. shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "$new"; then
    echo "  OK (0 findings)"
  else
    echo "  FAIL: shellcheck reportó findings" >&2
    exit 1
  fi
else
  echo "  SKIP (shellcheck no instalado)"
fi

echo
echo "OK"
exit 0
