#!/usr/bin/env bash
# patterns.sh — rellena las 7 regex. Debes anclarlas con ^...$ en la propia
# regex (el validador NO las ancla por ti).
#
# Reglas:
#   - ENGINE_X='E' invoca con `grep -E`.
#   - ENGINE_X='P' invoca con `grep -P`.
#
# El validador imprime cuantos positivos aceptas y cuantos negativos
# rechazas por cada clase.

set -euo pipefail

# 1) IPv4 (0-255 por octeto)
REGEX_IPV4=''
ENGINE_IPV4='E'

# 2) Email pragmatico
REGEX_EMAIL=''
ENGINE_EMAIL='E'

# 3) ISO date YYYY-MM-DD (1900-2099)
REGEX_ISODATE=''
ENGINE_ISODATE='E'

# 4) UUID v1-v5 canonico
REGEX_UUID=''
ENGINE_UUID='E'

# 5) Nombre de variable bash
REGEX_BASHVAR=''
ENGINE_BASHVAR='E'

# 6) URL http(s)
REGEX_URL=''
ENGINE_URL='E'

# 7) Color CSS hex (#rgb o #rrggbb), case-insensitive
REGEX_HEXCOLOR=''
ENGINE_HEXCOLOR='P'
