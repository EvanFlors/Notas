# Recursos — dkr-12 Multi-arch y reproducibilidad

## Documentación oficial

- Docker Buildx — `https://docs.docker.com/build/building/multi-platform/`
- Buildx drivers — `https://docs.docker.com/build/builders/drivers/`
- BuildKit OCI exporter (opciones `rewrite-timestamp`, etc.) — `https://docs.docker.com/build/exporters/oci-docker/`
- `docker buildx imagetools` — `https://docs.docker.com/reference/cli/docker/buildx/imagetools/`
- `docker manifest` — `https://docs.docker.com/reference/cli/docker/manifest/`

## OCI specs

- Image Spec (manifest, config, descriptor) — `https://github.com/opencontainers/image-spec`
- Image Index spec — `https://github.com/opencontainers/image-spec/blob/main/image-index.md`
- Distribution Spec — `https://github.com/opencontainers/distribution-spec`

## Multi-arch práctico

- `docker/setup-qemu-action` (GHA) — `https://github.com/docker/setup-qemu-action`
- `docker/setup-buildx-action` (GHA) — `https://github.com/docker/setup-buildx-action`
- `docker/build-push-action` (GHA) — `https://github.com/docker/build-push-action`
- `tonistiigi/binfmt` (QEMU en Linux puro) — `https://github.com/tonistiigi/binfmt`

## Reproducibilidad

- Reproducible Builds — `https://reproducible-builds.org/`
- `SOURCE_DATE_EPOCH` spec — `https://reproducible-builds.org/specs/source-date-epoch/`
- Reproducible container images (BuildKit) — `https://github.com/moby/buildkit/blob/master/docs/build-repro.md`
- `diffoci` — `https://github.com/reproducible-containers/diffoci`
- Chainguard `apko` (reproducible by construction) — `https://github.com/chainguard-dev/apko`

## SLSA y provenance (puente a dkr-14)

- SLSA v1.0 — `https://slsa.dev/spec/v1.0/`
- `--provenance` en BuildKit — `https://docs.docker.com/build/metadata/attestations/slsa-provenance/`
