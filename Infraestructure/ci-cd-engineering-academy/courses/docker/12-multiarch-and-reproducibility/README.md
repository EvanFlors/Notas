# dkr-12 — Multi-arch y reproducibilidad

## Identificación

- **ID:** `dkr-12-multiarch-and-reproducibility`
- **Curso:** `docker`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `dkr-07-multistage-buildkit-and-secrets`, `dkr-09-registries-tags-and-digests`.

## Objetivo

Construir imágenes **multi-plataforma** (`linux/amd64`, `linux/arm64`) con `docker buildx` y acercarse a **builds reproducibles** (dos builds consecutivos → mismo digest) mediante pins por digest, lockfiles y `SOURCE_DATE_EPOCH`.

## Alcance

Este módulo cubre:

- `docker buildx`: builder, drivers (`docker`, `docker-container`, `kubernetes`, `remote`).
- `--platform linux/amd64,linux/arm64` y cómo el `docker-container` driver habilita el *push* como un único **manifest index** (OCI image index).
- Emulación con **QEMU** (`tonistiigi/binfmt --install all`) vs **cross-compilation nativa** vs **native runners por arch**.
- Inspección: `docker buildx imagetools inspect`, `docker manifest inspect`.
- Reproducibilidad: fuentes de no-determinismo típicas (timestamps, orden de archivos, metadatos de red, versiones flotantes), `SOURCE_DATE_EPOCH`, `rewrite-timestamp=true`, `--provenance=false`, pins de base por `@sha256:…`, lockfiles de deps.

Lo que **no** cubre (se verá después):

- Firma y attestations (SBOM, SLSA Provenance) → `dkr-14`.
- Hardening del runtime → `dkr-13`.
- Publicar desde GitHub Actions con `docker/setup-qemu-action` y `docker/build-push-action` → curso `github-actions`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — tres ejemplos demostrativos:
  - `01-buildx-multiarch/` — crear un builder `docker-container`, instalar QEMU y construir una imagen para dos plataformas.
  - `02-manifest-index-inspection/` — inspeccionar el *manifest index* y las imágenes mono-arch que apunta.
  - `03-lockfile-and-base-digest/` — pin de base por digest + lockfile + `SOURCE_DATE_EPOCH` → mismo digest en dos builds.
- **`activities/`** — dos actividades:
  - `01-publish-amd64-arm64/` (guided-lab, dual-mode `local|live`) — publicar `app:v1` para `linux/amd64` y `linux/arm64`.
  - `02-make-build-reproducible/` (independent) — hacer que dos builds consecutivos produzcan el **mismo** digest.
- **`resources/links.md`** — referencias verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es un *manifest index* y por qué `docker pull` sobre un tag multi-arch "sabe" qué variante bajar. Enumerar al menos cinco fuentes de no-reproducibilidad en un build Docker típico. |
| Operativa | Crear un builder `docker-container`, instalar QEMU en el host, construir+publicar una imagen multi-arch, inspeccionar el índice con `imagetools`. Hacer que dos builds consecutivos del mismo Dockerfile produzcan el mismo digest. |
| Arquitectónica | Elegir entre QEMU, cross-compilation nativa, y native runners por arch para un pipeline dado, justificando el trade-off entre tiempo de build, costo y complejidad operativa. |

## Entregables

- Imagen `app:v1` publicada con un **manifest index** que apunta a variantes `linux/amd64` y `linux/arm64`.
- Dockerfile y procedimiento documentado para que dos builds consecutivos del mismo input produzcan el **mismo** image digest.

## Criterios de evaluación

- `docker buildx imagetools inspect <ref>` muestra ambas plataformas.
- Dos corridas consecutivas de `docker buildx build --provenance=false --output type=oci,dest=out.tar,rewrite-timestamp=true` producen tarballs con el mismo `sha256sum`.
- Capacidad de **diagnosticar** una fuente de no-reproducibilidad dada (timestamp de `RUN date`, `FROM python:3-slim` sin digest, `apt-get update` sin pin, etc.) y proponer la corrección mínima.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-buildx-multiarch/` (crear builder + QEMU + build dual).
3. Reproduce `examples/02-manifest-index-inspection/` para ver qué publicaste.
4. Reproduce `examples/03-lockfile-and-base-digest/` como baseline de reproducibilidad.
5. Haz `activities/01-publish-amd64-arm64/` (MODE=local por default; MODE=live si tienes GHCR).
6. Haz `activities/02-make-build-reproducible/` (independent; sin pistas directas).
7. Responde las preguntas de evaluación al final de `theory/lesson.md`.

## Siguiente

→ `dkr-13-runtime-security-and-hardening`.
