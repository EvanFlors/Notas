#!/bin/bash
# dirty.sh — resume el contenido de un directorio.
# Uso: dirty.sh DIR
# NOTA: este script "funciona" en el caso feliz pero shellcheck lo odia.
# Tu trabajo (sys-14-02) es dejarlo pasando shellcheck -S warning.

DIR=$1

cd $DIR

total=`ls | wc -l`
echo "total entries: $total"

files=`ls -l | grep ^- | wc -l`
dirs=`ls -l | grep ^d | wc -l`

echo "files: $files"
echo "dirs: $dirs"

function biggest() {
    local max=$(ls -S | head -1)
    echo "biggest: $max"
}

biggest

for f in $(ls); do
    if [ -f $f ]; then
        size=`stat -c %s $f 2>/dev/null || stat -f %z $f`
        echo "$f $size"
    fi
done
