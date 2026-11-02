#!/usr/bin/env bash
# "Legacy": compara dos listados y procesa un payload usando archivos temporales.
# Objetivo del ejercicio: reescribir con process substitution.

set -euo pipefail
IFS=$'\n\t'

outdir="${1:-./out}"
mkdir -p "$outdir"

# Fuentes "actuales" vs "esperadas" (hardcoded para reproducibilidad)
current="alpha
beta
gamma
delta"

expected="alpha
beta
gamma
epsilon"

# --- Patrón 1: dos tmp para diff ---
tmp_a="$(mktemp -t oracle_a.XXXXXX)"
tmp_b="$(mktemp -t oracle_b.XXXXXX)"

printf '%s\n' "$current"  | sort > "$tmp_a"
printf '%s\n' "$expected" | sort > "$tmp_b"

echo "== diff actual vs esperado =="
diff "$tmp_a" "$tmp_b" || true

rm -f "$tmp_a" "$tmp_b"

# --- Patrón 2: payload a tres consumidores vía tmp intermedio ---
payload="$(printf 'line %d\n' {1..5})"

tmp_payload="$(mktemp -t payload.XXXXXX)"
tmp_gz="$(mktemp -t payload_gz.XXXXXX)"
tmp_sha="$(mktemp -t payload_sha.XXXXXX)"

printf '%s\n' "$payload"           > "$tmp_payload"
gzip -c "$tmp_payload"             > "$tmp_gz"
sha256sum < "$tmp_payload"         > "$tmp_sha"

cp "$tmp_gz"  "$outdir/payload.gz"
cp "$tmp_sha" "$outdir/payload.sha"

# Limpieza "manual" propensa a olvidos
rm -f "$tmp_payload" "$tmp_gz"
# (nos olvidamos de "$tmp_sha" a propósito — forma parte del "bug")

echo "== outputs =="
ls -1 "$outdir"
echo "== sha =="
cat "$outdir/payload.sha"
