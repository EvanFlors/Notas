# Recursos — dkr-06

Documentacion oficial y lecturas complementarias.

## Documentacion oficial

- **Dockerfile reference** — https://docs.docker.com/reference/dockerfile/
- **Dockerfile best practices** — https://docs.docker.com/build/building/best-practices/
- **BuildKit** — https://docs.docker.com/build/buildkit/
- **BuildKit cache mounts** — https://docs.docker.com/build/cache/optimize/#use-cache-mounts
- **`COPY` vs `ADD`** — https://docs.docker.com/reference/dockerfile/#add
- **`HEALTHCHECK`** — https://docs.docker.com/reference/dockerfile/#healthcheck

## OCI standard annotations

- **OCI image spec — annotations** — https://github.com/opencontainers/image-spec/blob/main/annotations.md
- **GHCR y OCI labels** — https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#labelling-container-images

## Tooling de diagnostico

- **dive** (filesystem browser por capa) — https://github.com/wagoodman/dive
- **`docker history --no-trunc`** (ver ARGs, comandos exactos) — https://docs.docker.com/reference/cli/docker/image/history/
- **`docker build --progress=plain`** (debug de cache hits) — https://docs.docker.com/reference/cli/docker/buildx/build/#progress

## Lecturas recomendadas

- *Dockerfile linter* **hadolint** — https://github.com/hadolint/hadolint (reglas que capturan muchos anti-patrones de esta leccion).
- Chainguard — *"The myth of alpine for Python"* (contexto para `dkr-11`).
- Blog de Docker sobre BuildKit cache mounts (buscar: "Docker build cache optimization 2023").

## Checklist de verificacion en Fase 4

- Sintaxis vigente de `# syntax=docker/dockerfile:1.x`.
- Estado actual de `ADD --checksum=` (BuildKit >= 1.5) y `ADD --keep-git-dir=` para repos git.
- Default de BuildKit en Docker Engine actual (habilitado por default desde la version X).
