#!/usr/bin/env bash
# job.sh (STARTER) — genera un reporte y lo copia a OUT_DIR.
# Variables:
#   OUT_DIR : directorio destino (default /tmp/sys14-out)
#   SLOW    : si está set, duerme SLOW segundos (para probar concurrencia / señales)
#
# Problemas conocidos (los arreglas en esta actividad):
#   1. No tiene set -euo pipefail.
#   2. El tmpdir solo se borra al final del script (no si muere a mitad).
#   3. No evita ejecuciones concurrentes.
#   4. Siempre devuelve exit 0, pase lo que pase.
#   5. shellcheck -S warning reporta findings.

OUT_DIR=${OUT_DIR:-/tmp/sys14-out}
LOCK_FILE=/var/lock/sys14-job.lock

tmpdir=`mktemp -d /tmp/job-tmp.XXXXXX`
echo "tmpdir=$tmpdir"

mkdir -p $OUT_DIR

# "trabajo pesado"
echo "reporte generado $(date)" > $tmpdir/report.txt
if [ ! -z "$SLOW" ]; then
    sleep $SLOW
fi

cp $tmpdir/report.txt $OUT_DIR/report.txt

rm -rf $tmpdir
exit 0
