#!/usr/bin/env bash
# Bootstrap for dkr-09-02-tag-strategy-design.
# Creates $BASE/tag-strategy.md with the mandatory skeleton (placeholders).
set -euo pipefail

BASE="${1:-/tmp/dkr-09-strategy}"

rm -rf "$BASE"
mkdir -p "$BASE"

cat > "$BASE/tag-strategy.md" <<'EOF'
# Tag strategy — platform/orders-api (ADR)

<!--
Escenario: FastAPI interno, semver, GitHub + GHCR, Argo CD/GitOps, GKE Autopilot,
base python:3.12-slim, entornos dev/staging/prod, preview envs por PR, SOC 2
pide trazabilidad.

Completa cada seccion con decisiones explicitas. El validador verifica la
estructura y que las decisiones no esten vacias; no juzga el contenido.
-->

## Context

TODO: resume el escenario con tus palabras.

## Decision: immutable tags

TODO: lista exacta (ej. `vX.Y.Z`, `sha-<7>`).

## Decision: mutable tags

TODO: lista exacta (ej. `vX.Y`, `vX`, `latest`, `edge`, `pr-<N>`).

## Decision: production pin

TODO: como referencia produccion la imagen (tag? digest? ambos?). Flujo build -> deploy.

## Decision: staging and dev pin

TODO: como referencian staging y dev. Diferencias con prod.

## Decision: base image rotation

TODO: como mantienes `FROM python:3.12-slim` (pin a digest? Renovate? cadencia?).

## Decision: latest

TODO: que significa `latest` en tu estrategia (o por que no lo publicas).

## Rationale

TODO: 2-5 parrafos. Toca reproducibilidad, trazabilidad (SOC), rate-limits,
preview environments, riesgo operacional.

## Trade-offs

TODO: que pierdes con esta estrategia; que alternativas descartaste.
EOF

echo "== Bootstrap OK =="
echo "Edita: $BASE/tag-strategy.md"
echo "Valida: bash courses/docker/09-registries-tags-and-digests/activities/02-tag-strategy-design/tests/validate.sh $BASE"
