# Recursos — sec-01

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia.

## DevSecOps (visión general)

- OWASP DevSecOps Guideline: `https://owasp.org/www-project-devsecops-guideline/`
- NIST Secure Software Development Framework (SSDF): `https://csrc.nist.gov/Projects/ssdf`
- CNCF Security TAG: `https://github.com/cncf/tag-security`

## Threat modeling y STRIDE

- Microsoft Threat Modeling (orígenes de STRIDE): `https://learn.microsoft.com/azure/security/develop/threat-modeling-tool`
- Threat Modeling Manifesto: `https://www.threatmodelingmanifesto.org/`
- OWASP Threat Modeling: `https://owasp.org/www-community/Threat_Modeling`
- *Threat Modeling: Designing for Security* — Adam Shostack (libro de referencia).
- *Threats* — Adam Shostack (libro reciente, 2024, enfoque práctico).

## Data flow diagrams y trust boundaries

- OWASP: Threat modeling process → `https://owasp.org/www-community/Threat_Modeling_Process`
- Shostack & Associates — plantillas y guías: `https://shostack.org/resources/threat-modeling`

## Supply chain — incidentes de referencia

- **SolarWinds (2020)**: CISA write-up — `https://www.cisa.gov/news-events/alerts/2020/12/13/active-exploitation-solarwinds-software`.
- **log4shell (CVE-2021-44228)**: `https://nvd.nist.gov/vuln/detail/CVE-2021-44228` y `https://logging.apache.org/log4j/2.x/security.html`.
- **xz-utils backdoor (CVE-2024-3094)**: `https://nvd.nist.gov/vuln/detail/CVE-2024-3094` y análisis técnico de Andres Freund.
- **tj-actions/changed-files (2025)**: análisis en blogs de seguridad (Chainguard, StepSecurity).

## SLSA

- Sitio oficial: `https://slsa.dev/`
- Spec v1.0: `https://slsa.dev/spec/v1.0/`
- Build track niveles: `https://slsa.dev/spec/v1.0/levels`
- `actions/attest-build-provenance`: `https://github.com/actions/attest-build-provenance`
- `slsa-framework/slsa-github-generator`: `https://github.com/slsa-framework/slsa-github-generator`

## SBOM

- CycloneDX: `https://cyclonedx.org/`
- SPDX: `https://spdx.dev/`
- Syft (generador SBOM): `https://github.com/anchore/syft`
- NTIA — SBOM minimum elements: `https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom`

## in-toto y attestations

- in-toto: `https://in-toto.io/`
- Attestation spec: `https://github.com/in-toto/attestation`

## OpenSSF (ecosistema)

- OpenSSF: `https://openssf.org/`
- Scorecard: `https://github.com/ossf/scorecard`
- Allstar: `https://github.com/ossf/allstar`

## Lecturas y charlas

- "Securing the Software Supply Chain" — SLSA community talks (ver canal CNCF YouTube).
- Google SRE Book — capítulo sobre risk analysis (contexto general de defense-in-depth).
- Honeycomb / Chainguard / Datadog — blogs regulares sobre incidentes y mitigaciones.

## Para los módulos siguientes

- `sec-02` — Secrets: Vault, Doppler, GitHub OIDC federation.
- `sec-03` — Scanning landscape: Trivy, Semgrep, CodeQL, Checkov, gitleaks.
- `sec-08` — SBOM + SLSA en práctica.
- `sec-09` — cosign + Sigstore (Fulcio, Rekor).

## Checklist de verificación requerida en Fase 4

- Estado actual de **SLSA v1.0** (si hay v1.1 o cambios).
- Estado de **profiling** en OTel (si se cita cruzadamente).
- Vigencia de `actions/attest-build-provenance` (versión mayor).
- Casos nuevos de supply chain publicados en el último año.
