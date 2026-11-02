#!/usr/bin/env bash
# Reference solution for sys-01-02-io-redirection-dojo.
# Produces every expected artifact in /tmp/dojo/.
set -euo pipefail
IFS=$'\n\t'

DOJO="${1:-/tmp/dojo}"
rm -rf "$DOJO"
mkdir -p "$DOJO"

# Ex 1 — stdout a archivo
uname -a > "$DOJO/01-stdout.txt"

# Ex 2 — stderr separado
ls /tmp /no-existe-xyz > "$DOJO/02-ok.txt" 2> "$DOJO/02-err.txt" || true

# Ex 3 — combinados POSIX
ls /tmp /no-existe-xyz > "$DOJO/03-combo.txt" 2>&1 || true

# Ex 4 — append
echo "inicio: $(date -u +%FT%TZ)" >> "$DOJO/04-log.txt"
echo "medio: evento intermedio"   >> "$DOJO/04-log.txt"
echo "fin: $(date -u +%FT%TZ)"    >> "$DOJO/04-log.txt"

# Ex 5 — here-doc SIN expansión
cat > "$DOJO/05-template.txt" <<'EOF'
# Template
usuario: $USER
home: $HOME
EOF

# Ex 6 — pipefail
set +e
(
  set -o pipefail
  false | sort | uniq
)
rc=$?
set -e
echo "$rc" > "$DOJO/06-pipeline.txt"

# Ex 7 — tee
ls /etc | head -5 | tee "$DOJO/07-tee.txt" >/dev/null

# Ex 8 — exported vs shell-only
export DOJO_VAR=exported
bash -c 'echo "DOJO_VAR=${DOJO_VAR:-UNSET}"' > "$DOJO/08-env.txt"
unset DOJO_VAR

DOJO_VAR=shellonly
bash -c 'echo "DOJO_VAR=${DOJO_VAR:-UNSET}"' > "$DOJO/08-shell.txt"
unset DOJO_VAR

echo "Artefactos generados en $DOJO:"
ls -1 "$DOJO"
