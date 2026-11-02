#!/usr/bin/env bash
# patterns.sh — SOLUCION. Ver patterns.md para notas de diseño.

set -euo pipefail

REGEX_IPV4='^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$'
ENGINE_IPV4='E'

REGEX_EMAIL='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
ENGINE_EMAIL='E'

REGEX_ISODATE='^(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
ENGINE_ISODATE='E'

REGEX_UUID='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
ENGINE_UUID='E'

REGEX_BASHVAR='^[A-Za-z_][A-Za-z0-9_]*$'
ENGINE_BASHVAR='E'

REGEX_URL='^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[^ ?]*)?(\?[^ ]*)?$'
ENGINE_URL='E'

REGEX_HEXCOLOR='^(?i)#([0-9a-f]{3}|[0-9a-f]{6})$'
ENGINE_HEXCOLOR='P'
