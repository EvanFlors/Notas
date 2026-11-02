#!/usr/bin/env bash
# Caso 3: SIN `pipefail`, el exit del pipeline es el del último comando.
# Un fallo en el medio del pipeline se traga.
# Fíjate que este script NO activa `pipefail` (solo `-eu`), a propósito.
set -eu
IFS=$'\n\t'

# `false` falla, pero `true` tiene éxito y es el último → exit code del pipeline: 0.
false | true

echo "continué: pipeline reportó éxito a pesar del fallo intermedio"
exit 0
