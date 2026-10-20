# Ejemplo 02 — LABEL con OCI standard annotations

Dockerfile minimo que agrega el set completo de **OCI image annotations** (`org.opencontainers.image.*`) y los parametriza desde `--build-arg` como lo haria un pipeline de CI.

## Que hay

```
.
├── Dockerfile
└── demo.sh
```

## Correr

```bash
cd examples/02-labels-oci-standard
./demo.sh
```

El script:

1. Construye la imagen pasando `GIT_SHA` y `BUILD_DATE` como build-args.
2. Inspecciona los labels y los imprime en formato JSON.
3. Verifica que estan presentes al menos los 10 campos OCI estandar recomendados.

## Lo que esta ensenando

- Como parametrizar labels desde el pipeline (git SHA, timestamp).
- Como se ven con `docker inspect --format '{{json .Config.Labels}}' <image>`.
- Por que estos labels son leidos por GHCR UI, `trivy`, `syft`, `cosign` y otros.

## Lista de annotations usadas

| Clave | Que es |
|-------|--------|
| `org.opencontainers.image.title` | Nombre humano del artefacto |
| `org.opencontainers.image.description` | Descripcion corta |
| `org.opencontainers.image.version` | Version semver del artefacto |
| `org.opencontainers.image.authors` | Mantainers |
| `org.opencontainers.image.source` | URL del repo fuente |
| `org.opencontainers.image.documentation` | URL de la doc |
| `org.opencontainers.image.licenses` | SPDX license ID |
| `org.opencontainers.image.revision` | Git SHA |
| `org.opencontainers.image.created` | ISO-8601 timestamp del build |
| `org.opencontainers.image.vendor` | Organizacion que publica |

## Limpieza

```bash
docker rmi labels-demo:latest 2>/dev/null || true
```
