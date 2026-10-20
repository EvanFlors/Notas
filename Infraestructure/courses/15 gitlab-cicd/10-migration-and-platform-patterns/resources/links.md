# Recursos — gl-10

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (releases mensuales de GitLab el 22; nombres/paths pueden cambiar).

## Oficiales (GitLab)

- **`.gitlab-ci.yml` reference**: `https://docs.gitlab.com/ee/ci/yaml/`
- **CI/CD Components**: `https://docs.gitlab.com/ee/ci/components/`
- **CI/CD Catalog**: `https://docs.gitlab.com/ee/ci/components/#cicd-catalog`
- **ID Tokens (OIDC)**: `https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html`
- **OIDC federation to AWS**: `https://docs.gitlab.com/ee/ci/cloud_services/aws/`
- **OIDC federation to GCP**: `https://docs.gitlab.com/ee/ci/cloud_services/google_cloud/`
- **OIDC federation to Azure**: `https://docs.gitlab.com/ee/ci/cloud_services/azure/`
- **Runners (chart K8s)**: `https://docs.gitlab.com/runner/install/kubernetes.html`
- **Fleeting autoscaler**: `https://docs.gitlab.com/runner/fleet_scaling/fleeting.html`
- **Compliance frameworks**: `https://docs.gitlab.com/ee/user/group/compliance_frameworks.html`
- **Protected environments**: `https://docs.gitlab.com/ee/ci/environments/protected_environments.html`
- **Prometheus exporter**: `https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_exporter.html`

## GitHub Actions (para el mapping)

- **Workflow syntax**: `https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions`
- **OIDC with cloud providers**: `https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
- **Reusable workflows**: `https://docs.github.com/actions/using-workflows/reusing-workflows`
- **Composite actions**: `https://docs.github.com/actions/creating-actions/creating-a-composite-action`

## Migración

- **GitLab Importers (desde GitHub/BitBucket/Jenkins)**: `https://docs.gitlab.com/ee/user/project/import/`
- **Guía oficial GitLab: moving from Jenkins**: `https://docs.gitlab.com/ee/ci/migration/jenkins.html`
- **Guía oficial GitLab: moving from GitHub Actions**: `https://docs.gitlab.com/ee/ci/migration/github_actions.html`

## Argo CD (para la frontera CI↔CD)

- **Argo CD docs**: `https://argo-cd.readthedocs.io/`
- **GitOps principles**: `https://opengitops.dev/`

## Lecturas sobre operar como plataforma

- "Team Topologies" (Skelton & Pais) — para el modelo *platform team as a product team*.
- CNCF Platforms White Paper: `https://tag-app-delivery.cncf.io/whitepapers/platforms/`
- GitLab Handbook — sección CI/CD de la propia GitLab operando en GitLab.

## Checklist de verificación requerida en Fase 4

- Versión actual de GitLab (releases cada mes 22) y features Premium/Ultimate gated vigentes.
- Estado y madurez del **CI/CD Catalog** público.
- Estado de **Fleeting** autoscaler por plugin (AWS/GCP/Azure).
- Documentación vigente de **ID Tokens / OIDC** desde GitLab a AWS/GCP/Azure/Vault (claims disponibles y recomendaciones de pinning por `project_path`, `ref`, `environment`).
- Comparativa de pricing GHA vs GitLab vigente (minutos, planes, storage).
- Límite actual de **nested includes** y cualquier cambio en `include:component:` vs `include:remote:`.
- Guías oficiales de migración desde Jenkins y desde GitHub Actions (los paths y herramientas evolucionan).
