#!/usr/bin/env bash
# Reference solution for k8s-06-02-cronjob-flaky-fix.
# Note: we deliberately do NOT enable `set -o pipefail`. kubectl pipelines
# with `grep -q` can SIGPIPE (exit 141) when grep matches early; pipefail
# would promote that to a failure.

set -eu

WORK="/tmp/k8s-06-02"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$WORK"

kubectl apply -f "$HERE/cronjob-fixed.yaml"

cat > "$WORK/diagnostico.md" <<'EOF'
# Diagnóstico

- Síntoma: múltiples Pods del CronJob corriendo simultáneamente a los pocos
  minutos de aplicar el manifest original.
- Causa raíz: `concurrencyPolicy: Allow` (default) + comando que tarda ~90 s
  en un cron que dispara cada 60 s. El controller crea un nuevo Job cada
  minuto sin importar si el anterior sigue vivo.
- Opciones de fix:
    - `Forbid`: si el anterior sigue activo, se **salta** la ejecución.
      Preferible para limpiezas idempotentes donde "la última foto" no es
      especial.
    - `Replace`: mata al anterior y arranca el nuevo. Preferible cuando lo
      importante es *el estado más reciente* (p. ej. sincronizar desde una
      API externa).
- Fix aplicado: `concurrencyPolicy: Forbid` + `startingDeadlineSeconds: 30`
  para que, si el scheduler se atrasa, no acumulemos ejecuciones.
EOF

echo "SETUP OK; corre tests/validate.sh ahora, ANTES de limpiar."
