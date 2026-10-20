# Recursos — tf-14

A verificar en Fase 4 de ejecución (versiones y URLs pueden cambiar).

## Documentación oficial

- Terraform — Module sources (git, registry, HTTP): https://developer.hashicorp.com/terraform/language/modules/sources
- Terraform — `import` blocks: https://developer.hashicorp.com/terraform/language/import
- Terraform — Generating configuration (`-generate-config-out`): https://developer.hashicorp.com/terraform/language/import/generating-configuration
- Terraform — `moved` blocks: https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
- Terraform — `removed` blocks: https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources
- Terraform — Private Module Registry (HCP): https://developer.hashicorp.com/terraform/cloud-docs/registry
- OpenTofu — Module sources: https://opentofu.org/docs/language/modules/sources/
- OpenTofu — State encryption: https://opentofu.org/docs/language/state/encryption/

## Registries internos (opciones productivas)

- Artifactory Terraform Registry: https://jfrog.com/help/r/jfrog-artifactory-documentation/terraform-registry
- GitLab Infrastructure Registry: https://docs.gitlab.com/ee/user/packages/terraform_module_registry/
- Terraform Registry Protocol: https://developer.hashicorp.com/terraform/internals/module-registry-protocol

## Golden paths / platform engineering

- Spotify — Paved roads (origen del concepto): https://engineering.atspotify.com/
- Backstage — Software templates: https://backstage.io/docs/features/software-templates/
- Netflix — Paved paths blog posts (archivo).
- Thoughtworks Radar — Platform engineering trends: https://www.thoughtworks.com/radar

## Drift detection

- `driftctl` (deprecated, útil como lectura histórica): https://github.com/snyk/driftctl
- env0 drift detection: https://docs.env0.com/docs/drift-detection
- Spacelift drift detection: https://docs.spacelift.io/concepts/stack/drift-detection

## Policy-as-code

- OPA / Rego: https://www.openpolicyagent.org/docs/latest/
- Conftest (OPA sobre configs y plan JSON): https://www.conftest.dev/
- HashiCorp Sentinel: https://developer.hashicorp.com/sentinel

## Ejemplos de módulos "golden" comunitarios (lectura)

- terraform-aws-modules: https://github.com/terraform-aws-modules
- cloudposse: https://github.com/cloudposse
- Gruntwork infrastructure-modules (comercial, blog útil): https://docs.gruntwork.io/

## Charlas y lecturas

- "Terraform at scale" — HashiConf talks (archivo YouTube).
- "Platform engineering" — team-topologies.com (Skelton & Pais).
- Charity Majors — "The future of ops" / "Test in production" (contexto para drift y gobernanza).

## Verificación requerida (Fase 4)

- Versión estable actual de Terraform y OpenTofu, confirmación de que `import` blocks + `-generate-config-out` siguen con la UX descrita.
- Estado de `removed` en Terraform vs OpenTofu (OpenTofu admite destrucción explícita en el bloque; Terraform usa `lifecycle { destroy = true/false }`).
- Precios y features de HCP Terraform (si el ADR debe recomendar o descartarlo).
- Compatibilidad lockfile cross-tool (Terraform ↔ OpenTofu) al momento del cursado.
