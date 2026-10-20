# Recursos — gha-14

## GitHub Actions artifact attestations

- **Doc oficial** — <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- **`actions/attest-build-provenance`** — <https://github.com/actions/attest-build-provenance>
- **`actions/attest-sbom`** — <https://github.com/actions/attest-sbom>
- **`actions/attest`** (base, raramente usada directo) — <https://github.com/actions/attest>
- **`gh attestation` CLI** — <https://cli.github.com/manual/gh_attestation>

## Sigstore

- **Documentación general** — <https://docs.sigstore.dev/>
- **Cómo funciona** (Fulcio + Rekor + CT) — <https://docs.sigstore.dev/certificate_authority/overview/>
- **Rekor** (log público) — <https://docs.sigstore.dev/logging/overview/>
- **Fulcio** (CA) — <https://docs.sigstore.dev/certificate_authority/overview/>
- **Búsqueda en Rekor público** — <https://search.sigstore.dev/>
- **The Update Framework (TUF)** usado para distribuir trusted root — <https://theupdateframework.io/>

## cosign

- **Documentación** — <https://docs.sigstore.dev/cosign/signing/overview/>
- **Repositorio** — <https://github.com/sigstore/cosign>
- **`sigstore/cosign-installer`** (action) — <https://github.com/sigstore/cosign-installer>
- **Verifying signatures** — <https://docs.sigstore.dev/cosign/verifying/verify/>
- **Keyless signing** — <https://docs.sigstore.dev/cosign/signing/overview/#keyless-signing>

## SBOM

- **CycloneDX spec** — <https://cyclonedx.org/specification/overview/>
- **SPDX spec** — <https://spdx.github.io/spdx-spec/>
- **syft** — <https://github.com/anchore/syft>
- **`anchore/sbom-action`** — <https://github.com/anchore/sbom-action>
- **grype** (consumidor de SBOM para vulnerabilidades) — <https://github.com/anchore/grype>

## SLSA

- **Especificación v1.0** — <https://slsa.dev/spec/v1.0/>
- **Build tracks (L1–L3+)** — <https://slsa.dev/spec/v1.0/levels>
- **SLSA GitHub Generator** (reusable workflows SLSA L3) — <https://github.com/slsa-framework/slsa-github-generator>

## GHCR

- **Working with the Container registry** — <https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- **OCI 1.1 referrers API** — <https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers>

## Normativa y contexto

- **Executive Order 14028** (US) — <https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/>
- **NTIA Minimum Elements for a SBOM** — <https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom>
- **CRA (Cyber Resilience Act, EU)** — contexto normativo complementario.

## Policy enforcement (fuera del módulo, referencia)

- **cosign policy controller** (K8s admission) — <https://docs.sigstore.dev/policy-controller/overview/>
- **Kyverno `verifyImages`** — <https://kyverno.io/docs/writing-policies/verify-images/>
- **Dependency-Track** (consumidor de SBOM) — <https://dependencytrack.org/>

## Lecturas recomendadas

- *"Supply chain attacks and the real risk of trusting your dependencies"* — serie Google SRE.
- *"SLSA: a common language to describe supply chain security"* — Google Security Blog.
- Postmortem público `tj-actions/changed-files` (2025) — ejemplo de por qué pinnear a SHA y verificar.
