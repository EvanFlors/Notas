# Recursos — sec-08

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso: SLSA/Sigstore/Syft/Grype son proyectos activos y la UX cambia.

## SBOM — formatos y especificaciones

- **CycloneDX** (OWASP): `https://cyclonedx.org/`
- **CycloneDX spec**: `https://github.com/CycloneDX/specification`
- **SPDX** (Linux Foundation): `https://spdx.dev/`
- **SPDX spec**: `https://github.com/spdx/spdx-spec`
- **SPDX License List**: `https://spdx.org/licenses/`
- **PURL** (package URL spec): `https://github.com/package-url/purl-spec`

## Herramientas

- **Syft** (Anchore): `https://github.com/anchore/syft`
- **Grype** (Anchore): `https://github.com/anchore/grype`
- **Trivy** (Aqua): `https://github.com/aquasecurity/trivy` (incluye SBOM gen + vuln scan)
- **cdxgen** (CycloneDX generator): `https://github.com/CycloneDX/cdxgen`
- **Dependency-Track** (SBOM inventory): `https://dependencytrack.org/`
- **GUAC** (graph for understanding artifact composition): `https://guac.sh/`

## SLSA

- **Sitio oficial**: `https://slsa.dev/`
- **SLSA v1.0 spec**: `https://slsa.dev/spec/v1.0/`
- **Build track**: `https://slsa.dev/spec/v1.0/levels`
- **Threats and mitigations**: `https://slsa.dev/spec/v1.0/threats`
- **Provenance schema v1**: `https://slsa.dev/spec/v1.0/provenance`

## in-toto (base de provenance)

- **Sitio**: `https://in-toto.io/`
- **Attestation framework**: `https://github.com/in-toto/attestation`

## GitHub Actions — attestations nativas

- **`actions/attest-build-provenance`**: `https://github.com/actions/attest-build-provenance`
- **`actions/attest-sbom`**: `https://github.com/actions/attest-sbom`
- **`actions/attest`** (generic predicate): `https://github.com/actions/attest`
- **Artifact attestations docs**: `https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds`
- **`gh attestation verify` CLI**: `https://cli.github.com/manual/gh_attestation_verify`

## Sigstore (profundiza en sec-09)

- **Sitio oficial**: `https://www.sigstore.dev/`
- **Docs**: `https://docs.sigstore.dev/`
- **cosign**: `https://github.com/sigstore/cosign`
- **Fulcio** (CA efímera): `https://github.com/sigstore/fulcio`
- **Rekor** (transparency log): `https://github.com/sigstore/rekor`
- **Rekor search**: `https://search.sigstore.dev/`

## OCI 1.1 referrers API (base del attachment OCI)

- **OCI Image Spec 1.1 referrers**: `https://github.com/opencontainers/image-spec/blob/main/manifest.md`

## Incidentes de supply chain (contexto)

- **SolarWinds** (2020): múltiples post-mortems; buscar "SUNBURST".
- **log4shell** (2021): `https://logging.apache.org/log4j/2.x/security.html`
- **xz-utils backdoor** (2024): `https://tukaani.org/xz-backdoor/`
- **tj-actions/changed-files** (2025): buscar "tj-actions/changed-files compromise 2025".

## Lecturas recomendadas

- **US Executive Order 14028** (SBOM mandate): `https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/`
- **CISA SBOM guidance**: `https://www.cisa.gov/sbom`
- **OpenSSF Scorecard** (criterios de salud de un proyecto OSS): `https://github.com/ossf/scorecard`

## Checklist de verificación requerida en Fase 4

- Versión actual de **Syft** y **Grype** (features/catalogadores nuevos).
- Estado de **CycloneDX** (versión activa — 1.5/1.6 al momento de escribir).
- Estado de **SPDX** (2.3 vs 3.0).
- Versión y features de **`actions/attest-build-provenance`** (major vigente).
- Estado de **SLSA v1.0 Source track** (si ya se publicó).
- UX vigente de `gh attestation verify` y `cosign verify-attestation --type slsaprovenance1`.
- Estado de **Rekor v2** (si ya reemplazó al v1 original).
- Soporte OCI 1.1 referrers en los registries principales (GHCR, ECR, Artifact Registry, DockerHub).
