# Recursos — dkr-14

## SBOM

- **syft** — <https://github.com/anchore/syft>
- **CycloneDX spec** — <https://cyclonedx.org/specification/overview/>
- **SPDX spec** — <https://spdx.github.io/spdx-spec/>
- **NTIA Minimum Elements for a SBOM** — <https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom>
- **Dependency-Track** (consumidor de SBOM) — <https://dependencytrack.org/>

## Scanning

- **Trivy** docs — <https://aquasecurity.github.io/trivy/>
- **Trivy repo** — <https://github.com/aquasecurity/trivy>
- **grype** — <https://github.com/anchore/grype>
- **CVE DB NVD** — <https://nvd.nist.gov/>
- **GHSA (GitHub Security Advisories)** — <https://github.com/advisories>

## Sigstore / cosign

- **cosign** docs — <https://docs.sigstore.dev/cosign/signing/overview/>
- **cosign repo** — <https://github.com/sigstore/cosign>
- **sigstore/cosign-installer** (action) — <https://github.com/sigstore/cosign-installer>
- **Fulcio** (CA de certificados efímeros) — <https://docs.sigstore.dev/certificate_authority/overview/>
- **Rekor** (log append-only público) — <https://docs.sigstore.dev/logging/overview/>
- **Búsqueda en Rekor público** — <https://search.sigstore.dev/>
- **Keyless signing walkthrough** — <https://docs.sigstore.dev/cosign/signing/overview/#keyless-signing>
- **cosign attestations** — <https://docs.sigstore.dev/cosign/signing/attestations/>

## SLSA

- **SLSA v1.0 spec** — <https://slsa.dev/spec/v1.0/>
- **SLSA build tracks (L1–L3+)** — <https://slsa.dev/spec/v1.0/levels>
- **SLSA Provenance predicate v1** — <https://slsa.dev/spec/v1.0/provenance>
- **SLSA GitHub Generator** (reusable workflows SLSA L3) — <https://github.com/slsa-framework/slsa-github-generator>

## OCI y registries

- **OCI image-spec** — <https://github.com/opencontainers/image-spec>
- **OCI distribution-spec** (incluye referrers API 1.1) — <https://github.com/opencontainers/distribution-spec>
- **GHCR docs** — <https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- **registry:2** image — <https://hub.docker.com/_/registry>

## GitHub artifact attestations (puente con `gha-14`)

- **`actions/attest-build-provenance`** — <https://github.com/actions/attest-build-provenance>
- **`actions/attest-sbom`** — <https://github.com/actions/attest-sbom>
- **`gh attestation` CLI** — <https://cli.github.com/manual/gh_attestation>

## Policy enforcement (introducción — se profundiza en D8/D9)

- **sigstore policy-controller** (K8s admission) — <https://docs.sigstore.dev/policy-controller/overview/>
- **Kyverno `verifyImages`** — <https://kyverno.io/docs/writing-policies/verify-images/>
- **OPA Gatekeeper** — <https://open-policy-agent.github.io/gatekeeper/>

## Normativa

- **US Executive Order 14028** — <https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/>
- **EU Cyber Resilience Act (CRA)** — contexto normativo complementario (buscar texto consolidado 2024/2025).

## Lecturas recomendadas

- *"Supply chain attacks and the real risk of trusting your dependencies"* — Google SRE.
- *"SLSA: a common language to describe supply chain security"* — Google Security Blog.
- Postmortem `tj-actions/changed-files` (2025) — por qué pinnear a SHA y verificar.
- Chainguard: *"Why we built distroless+signed-by-default images"*.
