#!/usr/bin/env bash
# Demo reproducible: hardlinks comparten inodo; symlinks apuntan por ruta.
# Idempotente: borra y recrea /tmp/links-demo en cada ejecución.
set -euo pipefail
IFS=$'\n\t'

DEMO_DIR="/tmp/links-demo"

echo "==> Reseteando ${DEMO_DIR}"
rm -rf "${DEMO_DIR}"
mkdir -p "${DEMO_DIR}"
cd "${DEMO_DIR}"

echo
echo "==> 1. Crear archivo original"
printf 'Hola, Unix\n' > original.txt
ls -li original.txt
echo "Inodo del original:"
stat -c 'inodo=%i nlink=%h size=%s name=%n' original.txt

echo
echo "==> 2. Crear hardlink: ln original.txt hardlink.txt"
ln original.txt hardlink.txt
echo "Ahora ls -li muestra los DOS nombres con el MISMO inodo y nlink=2:"
ls -li original.txt hardlink.txt
stat -c 'inodo=%i nlink=%h %n' original.txt hardlink.txt

echo
echo "==> 3. Crear symlink: ln -s original.txt symlink.txt"
ln -s original.txt symlink.txt
echo "El symlink es otro inodo, tipo 'l', apunta por ruta:"
ls -li original.txt hardlink.txt symlink.txt
echo "readlink del symlink:"
readlink symlink.txt
echo "readlink -f (resolución canónica):"
readlink -f symlink.txt

echo
echo "==> 4. Editar via hardlink: el cambio se ve desde cualquier nombre"
printf 'Linea nueva via hardlink\n' >> hardlink.txt
echo "--- original.txt ---"
cat original.txt
echo "--- hardlink.txt ---"
cat hardlink.txt
echo "--- symlink.txt (sigue el target) ---"
cat symlink.txt

echo
echo "==> 5. Borrar el 'original'"
rm original.txt
echo "Hardlink sobrevive (nlink pasa de 2 a 1):"
ls -li hardlink.txt
cat hardlink.txt
echo
echo "Symlink queda roto (dangling):"
ls -li symlink.txt || true
echo "readlink sigue dando el target literal, aunque ya no exista:"
readlink symlink.txt
echo "cat symlink.txt (debe fallar):"
if cat symlink.txt 2>&1; then
    echo "(inesperado: funcionó)"
else
    echo "(esperado: no existe el target)"
fi

echo
echo "==> 6. Reparar el symlink recreando el target"
printf 'Resurreccion\n' > original.txt
echo "Ahora el symlink vuelve a funcionar sin tocarlo:"
cat symlink.txt

echo
echo "==> Done. Limpieza: rm -rf ${DEMO_DIR}"
