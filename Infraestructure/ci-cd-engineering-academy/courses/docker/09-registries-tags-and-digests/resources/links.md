# Recursos — `dkr-09-registries-tags-and-digests`

> Verificar fecha de consulta. Docker, GHCR y las clouds suelen reorganizar sus docs.

## Especificaciones

- **OCI distribution-spec** — API HTTP de un registry (push/pull/mounts/manifests). <https://github.com/opencontainers/distribution-spec>
- **OCI image-spec** — manifest, config, layers, image index (multi-arch). <https://github.com/opencontainers/image-spec>

## Registries

- **Docker Hub rate limits** — anónimos vs autenticados vs Pro/Team. <https://docs.docker.com/docker-hub/download-rate-limit/>
- **GHCR — Working with the Container registry** — login, visibility, auth desde Actions. <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- **Amazon ECR private registry** — IAM, encryption, lifecycle, Pull Through Cache. <https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html>
- **ECR Public** — alternativa pública gratis sin rate-limit anónimo severo. <https://docs.aws.amazon.com/AmazonECR/latest/public/public-registries.html>
- **Artifact Registry (GCP)** — remote repos / replicación / Workload Identity. <https://cloud.google.com/artifact-registry/docs/overview>
- **Harbor** — registry self-hosted CNCF (RBAC, replication, Trivy, retention). <https://goharbor.io/docs/>
- **registry:2** (imagen oficial de referencia, útil para dev local). <https://hub.docker.com/_/registry>

## CLI de Docker — comandos relevantes

- `docker login` <https://docs.docker.com/engine/reference/commandline/login/>
- `docker tag` <https://docs.docker.com/engine/reference/commandline/tag/>
- `docker push` <https://docs.docker.com/engine/reference/commandline/push/>
- `docker pull` <https://docs.docker.com/engine/reference/commandline/pull/>
- `docker inspect` (`RepoDigests`) <https://docs.docker.com/engine/reference/commandline/inspect/>
- `docker image prune` <https://docs.docker.com/engine/reference/commandline/image_prune/>
- `docker system df` <https://docs.docker.com/engine/reference/commandline/system_df/>

## Herramientas de ecosistema

- **crane** (go-containerregistry) — manipular imágenes y registries sin daemon. <https://github.com/google/go-containerregistry/tree/main/cmd/crane>
- **skopeo** — copiar y firmar imágenes entre registries. <https://github.com/containers/skopeo>
- **docker/metadata-action** — generador de tags+labels para GHA. <https://github.com/docker/metadata-action>
- **docker/build-push-action** — build + push en un step. <https://github.com/docker/build-push-action>
- **docker/login-action** — login a registries desde GHA. <https://github.com/docker/login-action>
- **Renovate** — PRs automáticos cuando cambia el digest pinneado de una base. <https://docs.renovatebot.com/docker/>

## Para producción

- **Chainguard Images** — bases pinnables por digest, con rebuilds diarios y bajo CVE. <https://images.chainguard.dev/>
- **Google distroless** — bases sin shell/pkg manager. <https://github.com/GoogleContainerTools/distroless>
- **cosign** — firmar imágenes y verificar (ver `dkr-14`). <https://docs.sigstore.dev/cosign/overview/>
- **Trivy** — escaneo de vulnerabilidades (imágenes y configs). <https://aquasecurity.github.io/trivy/>

## En este curso

- Prerrequisito: `dkr-03-images-dockerfile-basics`.
- Siguiente módulo del nivel: `dkr-10-internals-namespaces-cgroups-overlayfs`.
- Para multi-arch y manifest lists: `dkr-12-multiarch-and-reproducibility`.
- Para hardening de runtime: `dkr-13-runtime-security-and-hardening`.
- Para supply chain (SBOM, firma, provenance): `dkr-14-supply-chain-sbom-signing-provenance`.
- Para publicar desde GitHub Actions: cursos `github-actions` (`gha-05` secrets/permissions, `gha-13` publishing).
