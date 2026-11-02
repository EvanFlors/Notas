#!/usr/bin/env bash
# broken.sh — copia archivos que matchean un patron. ESTA ROTO. Arreglalo.
#
# Uso: ./broken.sh <src> <dst> <pattern>
# Ejemplo: ./broken.sh /var/log /tmp/backup '*.log'

set -euo pipefail

src=$1
dst=$2
pattern=$3

echo Procesando $src con patron $pattern

count=0
for f in $(find $src -type f -name $pattern); do
  cp $f $dst/
  count=$(($count + 1))
done

echo Copiados $count archivos
