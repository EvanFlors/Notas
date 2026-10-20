#!/usr/bin/env bash
# Crea el directorio de trabajo con esqueletos vacios.
set -eu
BASE="${BASE_DIR:-/tmp/otel13-act02}"
mkdir -p "$BASE"

if [ ! -f "$BASE/SLO.md" ]; then
cat > "$BASE/SLO.md" <<'EOF'
# SLOs del pipeline OTel

> Reemplaza este contenido. Mantén los titulos exactos de las 5 secciones.

## SLIs

- (lista tus SLIs; cada uno con nombre, pregunta y metrica otelcol_*)

## SLOs

- (lista tus SLOs; cada uno cuantificado con ventana)

## Error Budget

- (calcula el budget mensual)

## Alertas

- (describe tus alertas; apunta a alerts.yaml)

## Playbook

- (que hacer cuando dispara cada alerta)
EOF
fi

if [ ! -f "$BASE/alerts.yaml" ]; then
cat > "$BASE/alerts.yaml" <<'EOF'
# Prometheus alerting rules para el pipeline OTel. Reemplazar.
groups:
  - name: otel-pipeline-slo
    rules: []
EOF
fi

echo "Esqueletos listos en $BASE/"
echo "Edita $BASE/SLO.md y $BASE/alerts.yaml. Luego ejecuta tests/validate.sh."
