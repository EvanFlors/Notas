# Recursos — Capstone stage 5

## GitHub Actions supply chain

- About artifact attestations. <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- `actions/attest-build-provenance`. <https://github.com/actions/attest-build-provenance>
- `gh attestation` CLI. <https://cli.github.com/manual/gh_attestation>
- Hardening Actions with OIDC. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- Pin actions by SHA (reasoning). <https://docs.github.com/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions>

## Build and push

- `docker/build-push-action`. <https://github.com/docker/build-push-action>
- `docker/metadata-action` (SemVer / sha / branch tags). <https://github.com/docker/metadata-action>
- Publishing by digest in Buildx. <https://docs.docker.com/build/ci/github-actions/multi-platform/>
- GHCR Working with the Container registry. <https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry>

## Container scanning

- Trivy GitHub Action. <https://github.com/aquasecurity/trivy-action>
- Trivy configuration file reference. <https://aquasecurity.github.io/trivy/latest/docs/references/configuration/config-file/>
- Trivy ignore-unfixed and triage. <https://aquasecurity.github.io/trivy/latest/docs/configuration/filtering/>
- Uploading SARIF to Code Scanning. <https://docs.github.com/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github>

## SBOM

- Syft project. <https://github.com/anchore/syft>
- `anchore/sbom-action`. <https://github.com/anchore/sbom-action>
- SPDX 2.3 specification. <https://spdx.github.io/spdx-spec/v2.3/>
- CycloneDX vs SPDX comparison (background). <https://anchore.com/sbom/sbom-formats-spdx-cyclonedx/>

## Sigstore / cosign

- Cosign documentation. <https://docs.sigstore.dev/cosign/signing/overview/>
- `sigstore/cosign-installer`. <https://github.com/sigstore/cosign-installer>
- Keyless signing deep dive. <https://docs.sigstore.dev/cosign/signing/overview/#keyless-signing>
- Verifying signatures and attestations. <https://docs.sigstore.dev/cosign/verifying/verify/>
- Rekor transparency log. <https://docs.sigstore.dev/rekor/overview/>
- Fulcio certificate authority. <https://docs.sigstore.dev/certificate_authority/overview/>

## SLSA

- SLSA v1.0 specification. <https://slsa.dev/spec/v1.0/>
- SLSA build provenance levels. <https://slsa.dev/spec/v1.0/levels>
- in-toto attestation framework. <https://github.com/in-toto/attestation>
- GitHub-hosted builders and SLSA Level 3. <https://slsa.dev/spec/v1.0/github-actions>

## Verification patterns

- Policy controller (admission control, out-of-scope here). <https://docs.sigstore.dev/policy-controller/overview/>
- `cosign verify` identity flags. <https://docs.sigstore.dev/cosign/verifying/verify/#verify-signatures>
