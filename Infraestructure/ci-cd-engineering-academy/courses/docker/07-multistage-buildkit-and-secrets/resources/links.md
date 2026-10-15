# Recursos — dkr-07

Documentacion oficial y lecturas complementarias para multi-stage, BuildKit y secrets de build.

## Documentacion oficial

- **Multi-stage builds** — https://docs.docker.com/build/building/multi-stage/
- **Dockerfile reference — `# syntax` directive** — https://docs.docker.com/reference/dockerfile/#syntax
- **Dockerfile reference — `COPY --from=`** — https://docs.docker.com/reference/dockerfile/#copy
- **BuildKit** — https://docs.docker.com/build/buildkit/
- **BuildKit frontend `dockerfile:1`** — https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
- **`--mount=type=cache`** — https://docs.docker.com/build/cache/optimize/#use-cache-mounts
- **`--mount=type=secret`** — https://docs.docker.com/build/building/secrets/
- **`docker build --progress`** — https://docs.docker.com/reference/cli/docker/buildx/build/#progress
- **`docker buildx`** — https://docs.docker.com/reference/cli/docker/buildx/
- **`docker history`** — https://docs.docker.com/reference/cli/docker/image/history/

## Guias y best practices

- **Dockerfile best practices** (seccion multi-stage y secrets) — https://docs.docker.com/build/building/best-practices/
- **BuildKit cache mount patterns** (apt, pip, npm, go) — https://docs.docker.com/build/cache/optimize/
- **Build secrets with GitHub Actions** — https://docs.docker.com/build/ci/github-actions/secrets/

## Tooling de diagnostico y auditoria

- **`dive`** (filesystem browser por capa) — https://github.com/wagoodman/dive
- **`hadolint`** (linter de Dockerfile) — https://github.com/hadolint/hadolint
- **Trivy** (scan de secretos y vulns) — https://github.com/aquasecurity/trivy
- **`docker-slim`** (slimming automatico) — https://github.com/slimtoolkit/slim

## Lecturas recomendadas

- Blog oficial de Docker: "Introduction to BuildKit" (buscar en docker.com/blog).
- Blog de Earthly / Depot sobre cache mounts y CI builds reproducibles.
- OWASP: "Docker Security Cheat Sheet" (seccion de secrets management).
- GitLab blog: "Container secrets with BuildKit".

## Puente con otros modulos del programa

- `dkr-11-image-optimization-and-base-image-strategy` — llevar la imagen final a < 70 MB con distroless/chainguard.
- `dkr-12-multiarch-and-reproducibility` — mismo Dockerfile para amd64 + arm64 usando `buildx`.
- `dkr-14-supply-chain-sbom-signing-provenance` — firmar la imagen multi-stage y adjuntar attestation.
- `gha-05-permissions-and-secrets` — como pasar el `${{ secrets.X }}` a `--secret id=...` desde un workflow.
