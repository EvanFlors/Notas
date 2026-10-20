# Recursos — sec-05

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso: Trivy mejora rápido y las features pueden haberse estabilizado o renombrado.

## Oficiales — Trivy

- **Sitio**: `https://trivy.dev/`
- **Docs**: `https://aquasecurity.github.io/trivy/latest/`
- **Repo**: `https://github.com/aquasecurity/trivy`
- **Imagen oficial Docker**: `https://hub.docker.com/r/aquasec/trivy` — en este módulo pineamos a `aquasec/trivy:0.56.2`.
- **GitHub Action**: `https://github.com/aquasecurity/trivy-action` — pin por SHA en producción.
- **Trivy Operator**: `https://aquasecurity.github.io/trivy-operator/latest/` — docs del Operator para K8s.
- **Trivy DB (registry)**: `https://github.com/aquasecurity/trivy-db` — la DB de vulns distribuida como imagen OCI.

## Alternativas y comparables

- **Grype** (Anchore): `https://github.com/anchore/grype` — scanner SCA + container muy parecido.
- **Syft** (Anchore): `https://github.com/anchore/syft` — generación de SBOMs; relevante para `sec-08`.
- **Snyk**: `https://snyk.io/` — comercial; DB enriquecida, dashboards, comentarios en PR.
- **Clair** (RedHat): `https://github.com/quay/clair` — scanner histórico de Quay; menos activo que Trivy/Grype.
- **tfsec** (DEPRECADO como standalone, mergeado en Trivy `config`): `https://github.com/aquasecurity/tfsec`

## Severidad y priorización

- **NVD** (CVSS v3.1): `https://nvd.nist.gov/vuln`
- **EPSS** (FIRST): `https://www.first.org/epss/`
- **KEV catalog** (CISA): `https://www.cisa.gov/known-exploited-vulnerabilities-catalog`
- **GitHub Advisory Database**: `https://github.com/advisories`
- **OSV**: `https://osv.dev/`
- **GitLab Advisory DB**: `https://gitlab.com/gitlab-org/security-products/advisory-database`
- **Red Hat Security Data**: `https://access.redhat.com/security/data/`

## Base images "slim" / distroless / hardened

- **Debian slim**: `https://hub.docker.com/_/debian` → tag `slim-*`.
- **Alpine**: `https://hub.docker.com/_/alpine` — ultracompacta (`musl`), ojo con compatibilidad glibc.
- **Google distroless**: `https://github.com/GoogleContainerTools/distroless` — sin shell ni package manager.
- **Chainguard Images**: `https://images.chainguard.dev/` — imágenes hardened, zero-known-CVE objetivo, actualización continua. Nightly y versioned tags.
- **UBI** (Universal Base Image Red Hat): `https://catalog.redhat.com/software/base-images`

## SARIF y GitHub Code Scanning

- **SARIF (OASIS spec)**: `https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html`
- **GitHub Code Scanning**: `https://docs.github.com/en/code-security/code-scanning`
- **Upload action**: `https://github.com/github/codeql-action/tree/main/upload-sarif`

## Lecturas y charlas (buscar la edición más reciente)

- KubeCon talks "Trivy Operator deep dive", "Beyond CVSS: EPSS and KEV".
- Aqua blog: "Trivy at scale" (varias ediciones).
- CISA blog sobre KEV: `https://www.cisa.gov/news-events/news/transforming-vulnerability-management-landscape`
- "CVSS, EPSS, KEV: your vulnerability triage toolkit" (varios autores).

## Específicos del módulo

- `.trivyignore` reference: `https://aquasecurity.github.io/trivy/latest/docs/configuration/filtering/`
- `trivy k8s` guide: `https://aquasecurity.github.io/trivy/latest/docs/target/kubernetes/`
- `trivy sbom` guide (preview de `sec-08`): `https://aquasecurity.github.io/trivy/latest/docs/supply-chain/sbom/`

## Para el curso previo (contexto)

- `courses/devsecops/03-scanning-landscape-sast-dast-sca-iac-container-secret/` — en qué casillero cae cada herramienta.
- `courses/devsecops/01-principles-threat-modeling-and-supply-chain-overview/` — supply chain y por qué atacar la base image es un vector real (SolarWinds, log4shell, xz-utils).

## Checklist de verificación requerida en Fase 4

- Versión actual de **Trivy** (vs la `0.56.2` que pineamos en los ejemplos).
- Estado del **DB registry OCI** y si el default sigue siendo GHCR.
- Features de **Trivy Operator** en la última release (nuevos CRs, scheduler changes).
- Estado de **tfsec** standalone (en modo mantenimiento tras merge en Trivy).
- Cambios en el **GitHub Advisory Database** y su alineación con **OSV**.
- Actualización del **CISA KEV catalog** y adopción vigente.
- Comparación vigente **Trivy vs Grype vs Snyk**.
- Novedades en **Chainguard** / **distroless** y su impacto en reducción de CVEs base.
