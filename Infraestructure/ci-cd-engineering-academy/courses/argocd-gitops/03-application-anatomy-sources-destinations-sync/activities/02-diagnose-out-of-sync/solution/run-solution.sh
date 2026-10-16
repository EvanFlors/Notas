#!/usr/bin/env bash
# Reference solution for argo-03-02-diagnose-out-of-sync.
# Rebuilds the scenarios and applies the minimal correct fix to each.
# Not meant to be a student aid during the activity.
#
# Note: no `set -o pipefail` by project convention; grep -q and sed don't need it.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${1:-/tmp/argo-03-02}"
STARTER="$HERE/../starter/build-scenarios.sh"

if [ ! -f "$STARTER" ]; then
  echo "FAIL: starter script not found at $STARTER"
  exit 1
fi

bash "$STARTER" "$BASE"

############################################
# FIX Scenario A: pin targetRevision to a reviewed tag
############################################
A="$BASE/scenario-a/application.yaml"
sed -i.bak 's|targetRevision: HEAD|targetRevision: v1.4.2|' "$A"
rm -f "$A.bak"

# And align the "desired" rendering to that pinned tag (so diff would go away).
sed -i.bak 's|ghcr.io/acme/capstone-api:next|ghcr.io/acme/capstone-api:v1.4.2|' "$BASE/scenario-a/desired-in-git.yaml"
rm -f "$BASE/scenario-a/desired-in-git.yaml.bak"

cat > "$BASE/scenario-a/report.md" <<'MD'
# Report — Scenario A

## Causa raíz (una línea)
`targetRevision: HEAD` siguió el cambio administrativo de default branch del repo (de main a develop), introduciendo manifests no revisados en producción.

## Corrección mínima aplicada
- Cambiado `targetRevision: HEAD` por `targetRevision: v1.4.2` (tag inmutable y revisado).
- Promoción futura a prod se hará explícitamente bumpando el tag en Git.

## Riesgo si no se corrige
Cualquier reorganización administrativa del repo (branch default, rename) puede desplegar código no revisado a producción sin que nadie se entere.
MD

############################################
# FIX Scenario B: add ignoreDifferences + RespectIgnoreDifferences=true
############################################
B="$BASE/scenario-b/application.yaml"
# Append RespectIgnoreDifferences=true inside the existing syncOptions list and
# add the ignoreDifferences block at the bottom of spec.
awk '
  /^      - ServerSideApply=true$/ {
    print
    print "      - RespectIgnoreDifferences=true"
    next
  }
  { print }
' "$B" > "$B.tmp" && mv "$B.tmp" "$B"

cat >> "$B" <<'YAML'
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: capstone-api
      jsonPointers:
        - /spec/replicas
YAML

cat > "$BASE/scenario-b/report.md" <<'MD'
# Report — Scenario B

## Causa raíz (una línea)
El HPA escribe `/spec/replicas` del Deployment y el Application no lo contempla; con `selfHeal: true` Argo CD lo revierte en cada reconcile loop.

## Corrección mínima aplicada
- Añadido `ignoreDifferences` sobre `/spec/replicas` del Deployment `capstone-api`.
- Añadido `RespectIgnoreDifferences=true` en `syncOptions` (si no, el ignore solo aplica al diff, no al apply).

## Riesgo si no se corrige
Pingpong continuo entre HPA (sube) y Argo CD (baja), tirando pods cada 3 min, impactando latencia y aumentando el blast radius de incidentes operativos.
MD

############################################
# FIX Scenario C: promote the manual change to Git (team agreed)
############################################
C_DESIRED="$BASE/scenario-c/desired-in-git.yaml"
sed -i.bak 's|value: info|value: debug|' "$C_DESIRED"
rm -f "$C_DESIRED.bak"

cat > "$BASE/scenario-c/report.md" <<'MD'
# Report — Scenario C

## Causa raíz (una línea)
Un `kubectl set env` manual durante un incidente dejó el cluster divergente del repo; el equipo acordó que el cambio es correcto y debe quedarse.

## Decisión: promover a Git o revertir en cluster
Promover a Git: el equipo acordó que `LOG_LEVEL=debug` es el nuevo default en stg; revertir perdería valor operacional y crearía repetición del incidente.

## Corrección mínima aplicada
- Editado `envs/stg/worker/deployment.yaml` para `LOG_LEVEL: debug` (promoción del cambio ad-hoc a Git), vía PR con CODEOWNERS del equipo stg.

## Riesgo si no se corrige
El próximo "Sync" en stg (manual o auto si cambia la política) revertiría `LOG_LEVEL=info` sin aviso, repitiendo el incidente que motivó el cambio original.
MD

echo "Solution applied to $BASE"
bash "$HERE/../tests/validate.sh" "$BASE"
