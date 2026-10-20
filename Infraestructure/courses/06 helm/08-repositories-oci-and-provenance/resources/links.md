# Recursos — helm-08

## Helm — repositories y OCI

- **Topics: Chart Repositories (HTTP)** — <https://helm.sh/docs/topics/chart_repository/>
- **Topics: Registries (OCI)** — <https://helm.sh/docs/topics/registries/>
- **`helm push`** — <https://helm.sh/docs/helm/helm_push/>
- **`helm pull`** — <https://helm.sh/docs/helm/helm_pull/>
- **`helm registry login`** — <https://helm.sh/docs/helm/helm_registry_login/>
- **`helm package`** (`--sign`, `--key`, `--keyring`) — <https://helm.sh/docs/helm/helm_package/>
- **`helm verify`** — <https://helm.sh/docs/helm/helm_verify/>
- **Provenance and integrity** — <https://helm.sh/docs/topics/provenance/>
- **Semantic Versioning spec** — <https://semver.org/>

## cosign / Sigstore

- **cosign documentation** — <https://docs.sigstore.dev/cosign/overview/>
- **cosign signing (keyless + key-based)** — <https://docs.sigstore.dev/cosign/signing/overview/>
- **cosign verifying** — <https://docs.sigstore.dev/cosign/verifying/verify/>
- **Fulcio (certificate authority)** — <https://docs.sigstore.dev/certificate_authority/overview/>
- **Rekor (transparency log)** — <https://docs.sigstore.dev/logging/overview/>
- **`cosign-installer` GitHub Action** — <https://github.com/sigstore/cosign-installer>
- **GHA OIDC + Sigstore guide** — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>

## OCI Distribution + artefactos

- **OCI Distribution Spec** — <https://github.com/opencontainers/distribution-spec>
- **OCI Image Spec (media types)** — <https://github.com/opencontainers/image-spec>
- **`oras` (manage arbitrary OCI artifacts)** — <https://oras.land/>
- **`crane` (image/artifact tooling)** — <https://github.com/google/go-containerregistry/tree/main/cmd/crane>

## Registries

- **GitHub Container Registry (GHCR) docs** — <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- **Docker Hub rate limits** — <https://docs.docker.com/docker-hub/download-rate-limit/>
- **Harbor** (self-hosted) — <https://goharbor.io/>
- **Zot** (OCI-only self-hosted) — <https://zotregistry.dev/>

## Artifact Hub

- **Artifact Hub** — <https://artifacthub.io/>
- **Repository metadata (`artifacthub-repo.yml`)** — <https://artifacthub.io/docs/topics/repositories/helm-charts/>
- **Chart signing display** — Artifact Hub muestra firmas cosign automáticamente cuando `cosign verify` resuelve contra Rekor.

## Admission / policy (contexto para después)

- **Cosign Policy Controller** — <https://docs.sigstore.dev/policy-controller/overview/>
- **Kyverno image verification** — <https://kyverno.io/policies/?policytypes=verifyImages>

## Air-gap patterns

- **Chart mirroring con `oras cp`** — <https://oras.land/docs/commands/oras_cp>
- **Helm chart "with charts/" (bundled deps)** — ver `theory/lesson.md` §10.

## Nota de verificación

Última revisión: 2026-10. Dominios oficiales (`helm.sh`, `sigstore.dev`, `opencontainers.org`, `github.com`, `artifacthub.io`). Revisar vigencia al rodar el módulo.
