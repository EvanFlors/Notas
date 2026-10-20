# Recursos — sec-07

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** (los links/releases cambian).

## Checkov

- Repo: `https://github.com/bridgecrewio/checkov`
- Docs: `https://www.checkov.io/`
- Custom policies (Python): `https://www.checkov.io/3.Custom%20Policies/Python%20Custom%20Policies.html`
- Custom policies (Rego/YAML): `https://www.checkov.io/3.Custom%20Policies/YAML%20Custom%20Policies.html`
- Catálogo de reglas: `https://www.checkov.io/5.Policy%20Index/all.html`
- Configuración (`.checkov.yaml`): `https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html`

## Trivy / Trivy config

- Trivy: `https://github.com/aquasecurity/trivy`
- Trivy config (misconfig): `https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/`
- Custom rules con Rego: `https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/custom/`

## tfsec

- Repo: `https://github.com/aquasecurity/tfsec` (modo mantenimiento, usa Trivy config)
- Nota de fusión con Trivy: en el README del repo.

## Alternativas

- **Terrascan** (Tenable): `https://github.com/tenable/terrascan`
- **KICS** (Checkmarx): `https://github.com/Checkmarx/kics`

## Terraform plan JSON

- Formato: `https://developer.hashicorp.com/terraform/internals/json-format`
- `terraform show -json`: `https://developer.hashicorp.com/terraform/cli/commands/show`

## Benchmarks

- **CIS Benchmarks**: `https://www.cisecurity.org/cis-benchmarks`
- **AWS Well-Architected Security Pillar**: `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html`

## Integración CI

- GitHub Code Scanning (SARIF upload): `https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning`
- Checkov GitHub Action: `https://github.com/marketplace/actions/checkov-github-action`
- Trivy GitHub Action: `https://github.com/aquasecurity/trivy-action`

## Lectura cruzada en este curso

- `sec-03` — categorías de scanning.
- `sec-05` — Trivy para SCA/container (comparte binario y cache).
- `sec-10` — Rego/Conftest en profundidad.
- `sec-11` — admission controllers (Kyverno, policy-controller).

## Checklist Fase 4

- Versión actual de Checkov (migraciones de IDs, deprecaciones).
- Estado de tfsec (sigue siendo mantenido como wrapper o se descontinuó).
- Reglas nuevas de CIS AWS y K8s publicadas en el último año.
- Compatibilidad del plan JSON format entre versiones de Terraform y OpenTofu.
