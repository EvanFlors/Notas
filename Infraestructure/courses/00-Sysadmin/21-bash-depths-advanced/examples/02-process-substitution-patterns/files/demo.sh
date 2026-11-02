#!/usr/bin/env bash
# Patrones de process substitution: diff y tee multi-sink.

set -euo pipefail
IFS=$'\n\t'

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cd "$workdir"

printf 'alpha\nbeta\ngamma\n'   > list_a.txt
printf 'alpha\nbeta\ndelta\n'   > list_b.txt

echo "== diff <(sort list_a.txt) <(sort list_b.txt) =="
# Comparar dos salidas transformadas sin crear temporales
if diff <(sort list_a.txt) <(sort list_b.txt); then
  echo "idénticos"
else
  echo "diferencias detectadas (exit code de diff: $?)"
fi

echo
echo "== tee a múltiples sinks: gzip + sha256sum =="
# Fuente única (cat) → tee → dos consumidores en paralelo.
# Nada toca disco intermedio salvo los outputs finales.
cat list_a.txt list_b.txt \
  | tee >(gzip > payload.gz) >(sha256sum > payload.sha) \
  > /dev/null

echo "generados en $workdir:"
ls -la payload.gz payload.sha

echo
echo "contenido de payload.sha:"
cat payload.sha

echo
echo "== verificación: nada quedó en /tmp aparte del propio workdir =="
# Mostramos sólo entradas con 'proc-subst' por si existieran leftovers; no habrá.
# shellcheck disable=SC2010
ls /tmp | grep -c 'proc-subst' || true
echo "workdir se eliminará por el trap EXIT: $workdir"
