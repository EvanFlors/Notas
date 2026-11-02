#!/usr/bin/env bash
# Validate: student performed sys-01-01-cli-tour correctly.
# Usage:
#   bash validate.sh [WORKDIR]
# Env overrides:
#   WORKDIR  (default /tmp/cli-tour)
#   BASHRC   (default ~/.bashrc)

set -o pipefail

WORKDIR="${1:-${WORKDIR:-/tmp/cli-tour}}"
BASHRC="${BASHRC:-$HOME/.bashrc}"
fail=0

echo "== Validating workspace at: $WORKDIR =="

if [ ! -d "$WORKDIR" ]; then
  echo "FAIL: workspace not found: $WORKDIR"
  exit 1
fi
cd "$WORKDIR"

# Jerarquía de proyectos
for d in proyectos/alpha proyectos/beta proyectos/gamma proyectos/alpha-copia; do
  if [ -d "$d" ]; then
    echo "  OK   directorio: $d"
  else
    echo "  FAIL directorio ausente: $d"
    fail=$((fail+1))
  fi
done

# Subdirectorios estándar en alpha
for sd in src tests docs; do
  if [ -d "proyectos/alpha/$sd" ]; then
    echo "  OK   proyectos/alpha/$sd"
  else
    echo "  FAIL falta: proyectos/alpha/$sd"
    fail=$((fail+1))
  fi
done

# notas-respaldo
if [ -f notas-respaldo.txt ]; then
  echo "  OK   notas-respaldo.txt"
else
  echo "  FAIL falta notas-respaldo.txt"
  fail=$((fail+1))
fi

# hardlink
if [ -f notas-hard ] && [ ! -L notas-hard ]; then
  echo "  OK   notas-hard existe como archivo regular"
else
  echo "  FAIL notas-hard ausente o es symlink"
  fail=$((fail+1))
fi

# symlink
if [ -L notas-sym ]; then
  echo "  OK   notas-sym es un symlink"
else
  echo "  FAIL notas-sym no es symlink"
  fail=$((fail+1))
fi

# bashrc checks
echo "== Validating bashrc at: $BASHRC =="
if [ ! -f "$BASHRC" ]; then
  echo "  WARN $BASHRC no existe (saltando checks de bashrc)."
else
  if bash -n "$BASHRC" 2>/dev/null; then
    echo "  OK   $BASHRC parsea sin errores de sintaxis"
  else
    echo "  FAIL $BASHRC tiene errores de sintaxis (bash -n)"
    fail=$((fail+1))
  fi

  for pat in 'HISTCONTROL' 'HISTSIZE' 'PS1='; do
    if grep -qE "$pat" "$BASHRC"; then
      echo "  OK   $BASHRC contiene $pat"
    else
      echo "  FAIL $BASHRC no contiene $pat"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
