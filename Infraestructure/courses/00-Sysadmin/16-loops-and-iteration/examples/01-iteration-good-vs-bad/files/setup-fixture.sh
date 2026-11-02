#!/usr/bin/env bash
# Crea un directorio ./fixture con nombres de archivo hostiles.
# Didáctico: sirve a los scripts bad-iter.sh y good-iter.sh.
set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$HERE/fixture"

rm -rf "$FIX"
mkdir -p "$FIX"

touch "$FIX/plain.txt"
touch "$FIX/with space.txt"
touch "$FIX/with  double  space.txt"
touch "$FIX/*.sh"           # nombre literal con asterisco
touch "$FIX/tab	in	name.txt"

echo "Fixture lista en: $FIX"
echo "Contenido:"
ls -1b -- "$FIX"
