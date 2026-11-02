#!/usr/bin/env bash
# Reescritura con process substitution: 0 archivos temporales, 0 limpieza manual.

set -euo pipefail
IFS=$'\n\t'

outdir="${1:-./out}"
mkdir -p "$outdir"

current="alpha
beta
gamma
delta"

expected="alpha
beta
gamma
epsilon"

# --- Patrón 1: diff directo entre dos process substitutions ---
echo "== diff actual vs esperado =="
diff <(printf '%s\n' "$current"  | sort) \
     <(printf '%s\n' "$expected" | sort) || true

# --- Patrón 2: payload a dos sinks en paralelo con tee + >() ---
# Nota: para que la salida final sea estable, calculamos sha sobre el payload
# idéntico al original (sha256sum sin filename produce "<hash>  -").
printf 'line %d\n' 1 2 3 4 5 \
  | tee >(gzip > "$outdir/payload.gz") \
        >(sha256sum > "$outdir/payload.sha") \
  > /dev/null

# Esperar a que los coprocesos de >(...) terminen antes de leer sus outputs.
# Bash lo hace implícitamente al cerrar el pipeline, pero wait es defensivo.
wait 2>/dev/null || true

echo "== outputs =="
ls -1 "$outdir"
echo "== sha =="
cat "$outdir/payload.sha"
