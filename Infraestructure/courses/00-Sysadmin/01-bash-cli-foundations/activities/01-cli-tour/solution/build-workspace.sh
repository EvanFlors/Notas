#!/usr/bin/env bash
# Reference solution for sys-01-01-cli-tour.
# Builds /tmp/cli-tour matching the expected end state.
set -euo pipefail
IFS=$'\n\t'

WORKDIR="${1:-/tmp/cli-tour}"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

mkdir -p proyectos/{alpha,beta,gamma}/{src,tests,docs}

echo "contenido inicial" > notas.txt
touch nuevo-vacio.txt
touch -d '2020-01-15 10:00:00' viejo.txt

cp notas.txt notas-respaldo.txt
cp -a proyectos/alpha proyectos/alpha-copia

ln notas.txt notas-hard
ln -s notas.txt notas-sym

# Borramos original para dejar el sym roto (parte de la lección).
rm notas.txt

echo "Workspace listo en: $WORKDIR"
ls -lAh
