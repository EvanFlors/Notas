# Starter — sec-05-02-reduce-cves-by-base-swap

Esta actividad es **independiente**. No hay plantilla: los artefactos los creas siguiendo `../README.md`.

## Pasos resumidos

1. Lee `../README.md`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-05-base-swap
   cd /tmp/sec-05-base-swap
   ```
3. Crea `app.py` + `Dockerfile.v1` + `Dockerfile.v2` + `Dockerfile.v3` según el README.
4. (Opcional, requiere `docker`+`jq`) construye las imágenes, escanea con `aquasec/trivy:0.56.2`, genera `scan-v{1,2,3}.json` y `counts.csv`.
5. Escribe `COUNTS.md` con la tabla y el porcentaje de reducción.
6. Escribe `ADR.md` con el formato Michael Nygard (Estado, Contexto, Decisión, Alternativas, Consecuencias).
7. Valida:
   ```bash
   bash <ruta-repo>/courses/devsecops/05-sca-container-scanning-with-trivy/activities/02-reduce-cves-by-base-swap/tests/validate.sh /tmp/sec-05-base-swap
   ```
8. Compara con `../solution/REFERENCE.md`.

> **Importante**: si no tienes `docker` o `jq`, el validador SKIP los checks ejecutables. Los documentos (`COUNTS.md`, `ADR.md`, Dockerfiles) deben existir con la estructura mínima.
