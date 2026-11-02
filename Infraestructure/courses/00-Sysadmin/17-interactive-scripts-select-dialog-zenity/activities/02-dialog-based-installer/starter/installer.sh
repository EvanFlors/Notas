#!/usr/bin/env bash
# installer.sh — Starter. Completa los TODO para pasar tests/validate.sh.
#
# Objetivo: instalador dual-mode (flags para CI, prompts para humano) con
# dialog/whiptail cuando están y fallback a `select` cuando no.

set -euo pipefail

APP_NAME="demo-app"
DEFAULT_TARGET="/opt/demo-app"
VALID_COMPONENTS=(core cli docs examples)

usage() {
  cat <<EOF
Uso: $0 [--target DIR] [--components a,b,c] [--yes] [--non-interactive]
        [--force-fallback] [-h|--help]
EOF
}

# TODO: parsea flags en estas variables.
target=""
components_csv=""
assume_yes=0
non_interactive=0
force_fallback=0

# TODO: implementa el while/case para parsear $@.

# TODO: define is_interactive() — devuelve 0 si hay TTY en stdin y stdout,
# CI != true, y --non-interactive no está activo.

# TODO: define pick_backend() — imprime "dialog", "whiptail" o "fallback" según
# command -v y $force_fallback.

# TODO: ask_target_* ask_components_* confirm_* — una pareja por backend
# (dialog/whiptail juntos; fallback con read/select).

# TODO: do_install target components — simula pasos (10, 40, 70, 100) y
# finalmente imprime en stdout:
#   INSTALLED target=<target> components=<csv>
# para que el test lo pueda matchear.

# TODO: main que orquesta: parsea → elige backend → rellena huecos → confirma
# → instala.

echo "starter sin implementar" >&2
exit 1
