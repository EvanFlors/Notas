#!/usr/bin/env bash
# Crea un directorio con archivos de nombres deliberadamente hostiles.
# Uso: make-tricky-files.sh [DIR]
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-/tmp/sys16-tricky}"

rm -rf "$DIR"
mkdir -p "$DIR"

# Normales
echo "contenido A" > "$DIR/alpha.log"
echo "contenido B" > "$DIR/beta.log"

# Con espacios
echo "x"   > "$DIR/with space.log"
echo "xy"  > "$DIR/with  double  space.log"

# Con tabs
printf 't' > "$DIR/tab	in	name.log"

# Con asterisco literal
echo "star" > "$DIR/*.log"

# Con pretensión de inyección (si tu loop expande esto, creas /tmp/sys16-pwn)
echo "injected" > "$DIR/evil\$(touch /tmp/sys16-pwn).log"

# Con newline en el nombre (si el filesystem lo permite — ext4, apfs, zfs sí)
echo "newline" > "$DIR/$(printf 'line1\nline2').log"

# Un unicode
echo "héllo" > "$DIR/café — niño.log"

# Un archivo vacío
: > "$DIR/empty.log"

# Nos aseguramos de que /tmp/sys16-pwn no exista como baseline
rm -f /tmp/sys16-pwn

echo "Listo. Directorio: $DIR"
echo "Archivos creados (ls -1b):"
ls -1b -- "$DIR"
