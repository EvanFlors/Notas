# Recursos — gh-13

## Documentación oficial de GitHub

### Firma de commits
- About commit signature verification. <https://docs.github.com/authentication/managing-commit-signature-verification/about-commit-signature-verification>
- Signing commits (SSH, GPG, S/MIME). <https://docs.github.com/authentication/managing-commit-signature-verification/signing-commits>
- Telling Git about your signing key. <https://docs.github.com/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key>

### Secret scanning + push protection
- About secret scanning. <https://docs.github.com/code-security/secret-scanning/introduction/about-secret-scanning>
- Push protection for repositories. <https://docs.github.com/code-security/secret-scanning/push-protection-for-repositories-and-organizations>
- Secret scanning REST API. <https://docs.github.com/rest/secret-scanning/secret-scanning>

### Dependabot
- About Dependabot. <https://docs.github.com/code-security/dependabot>
- Configuration options for `dependabot.yml`. <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file>
- Grouping Dependabot updates. <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file#groups>

### Code scanning / CodeQL
- Setting up code scanning. <https://docs.github.com/code-security/code-scanning>
- CodeQL action. <https://github.com/github/codeql-action>

### Private vulnerability reporting
- Configuring PVR. <https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability>

### SBOM y dependency graph
- About the dependency graph. <https://docs.github.com/code-security/supply-chain-security/understanding-your-software-supply-chain/about-the-dependency-graph>
- Export SBOM via API. <https://docs.github.com/rest/dependency-graph/sboms>

### Attestations / SLSA provenance
- Using artifact attestations. <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- `actions/attest-build-provenance`. <https://github.com/actions/attest-build-provenance>
- `gh attestation` CLI. <https://cli.github.com/manual/gh_attestation>

### OIDC a cloud providers
- About security hardening with OIDC. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- OIDC with AWS. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services>
- OIDC with Azure. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure>
- OIDC with GCP. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform>
- `aws-actions/configure-aws-credentials`. <https://github.com/aws-actions/configure-aws-credentials>

### Audit log
- Reviewing the audit log. <https://docs.github.com/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization>
- Streaming audit logs. <https://docs.github.com/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/streaming-the-audit-log-for-your-enterprise>

## Especificaciones y estándares

- **SLSA v1.0**. <https://slsa.dev/spec/v1.0/>
- **in-toto Attestation Framework**. <https://github.com/in-toto/attestation>
- **Sigstore** project. <https://www.sigstore.dev/>
- **Rekor** transparency log. <https://docs.sigstore.dev/logging/overview/>
- **Fulcio** CA. <https://docs.sigstore.dev/certificate_authority/overview/>
- **OpenID Connect** core. <https://openid.net/specs/openid-connect-core-1_0.html>
- **SPDX** SBOM spec. <https://spdx.dev/>
- **CycloneDX** SBOM spec. <https://cyclonedx.org/>

## Herramientas

- **gitleaks** (secret scanner, pre-commit o CI). <https://github.com/gitleaks/gitleaks>
- **trufflehog** (secret scanner con validadores vivos). <https://github.com/trufflesecurity/trufflehog>
- **gitsign** (Sigstore-based commit signing, keyless con OIDC). <https://github.com/sigstore/gitsign>
- **cosign** (firma de contenedores/artefactos OCI). <https://github.com/sigstore/cosign>
- **pre-commit** framework. <https://pre-commit.com/>
- **anchore/sbom-action** (generar SBOM en Actions). <https://github.com/anchore/sbom-action>

## Lecturas de referencia

- *Securing the Software Supply Chain* (CISA/NSA guidance). <https://media.defense.gov/2022/Sep/01/2003068942/-1/-1/0/ESF_SECURING_THE_SOFTWARE_SUPPLY_CHAIN_DEVELOPERS.PDF>
- *Executive Order 14028* (US, software supply chain security context). <https://www.federalregister.gov/documents/2021/05/17/2021-10460/improving-the-nations-cybersecurity>
- *The State of the Octoverse: Security* (GitHub, informes anuales). <https://octoverse.github.com/>
- Chainguard / Datadog / Snyk blogs on supply chain incidents.

## Para auditar repos de otros

- `gh api /repos/OWNER/REPO` — todo el objeto repo.
- `gh api /repos/OWNER/REPO/dependabot/alerts`
- `gh api /repos/OWNER/REPO/secret-scanning/alerts`
- `gh api /repos/OWNER/REPO/code-scanning/alerts`
- `gh api /repos/OWNER/REPO/actions/secrets` (list, no reveal)
- `gh api /repos/OWNER/REPO/rulesets`
- `gh ruleset list`, `gh ruleset view <id>`
