#!/usr/bin/env bash
# Prepara un directorio ./photos simulado con nombres y mtimes heterogéneos.
# Uso: setup.sh [DIR]
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-/tmp/sys16-photos}"

rm -rf "$DIR"
mkdir -p "$DIR"

# JPEG mínimo válido (header + EOI). No importa el contenido para esta actividad.
# Creamos archivos vacíos pequeños — los tests sólo miran nombres.
make_photo() {
  local name=$1 ts=$2
  : > "$DIR/$name"
  # Fijamos mtime usando touch -t YYYYMMDDhhmm.ss (portable BSD+GNU)
  touch -t "$ts" "$DIR/$name"
}

# ts formato: YYYYMMDDhhmm.ss
make_photo "DSCN0001.JPG"              "202408151423.01"
make_photo "DSCN0002.JPG"              "202408151423.02"
make_photo "20240816_091500.jpg"       "202408160915.00"
make_photo "IMG-20240816-WA0001.jpeg"  "202408161030.17"
make_photo "foto perro.jpg"            "202408170801.45"
make_photo "foto con  dos espacios.JPEG" "202408170802.00"
make_photo "IMG_20240818_120000.jpg"   "202408181200.00"   # ya tiene el patrón canónico
make_photo "colisión-1.jpg"            "202408181200.00"   # colisiona con el anterior

# Baseline de conteo
find "$DIR" -maxdepth 1 -mindepth 1 -type f | wc -l | awk '{printf "fotos creadas: %s\n", $1}'
echo "Directorio listo: $DIR"
