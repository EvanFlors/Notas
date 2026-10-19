# Recursos — jk-08

Referencias oficiales. **Verificar en Fase 4** (versiones, pricing, nombres de productos cambian).

## Jenkins oficial

- **Jenkins LTS release notes**: `https://www.jenkins.io/changelog-stable/`
- **Jenkins Handbook — Managing Jenkins**: `https://www.jenkins.io/doc/book/managing/`
- **High Availability (JEP / discussion)**: `https://www.jenkins.io/doc/book/system-administration/high-availability/`
- **Backups** (handbook): `https://www.jenkins.io/doc/book/system-administration/backing-up/`
- **Jenkins Security Advisories**: `https://www.jenkins.io/security/advisories/`
- **Jenkins Prometheus plugin**: `https://plugins.jenkins.io/prometheus/`
- **Metrics plugin**: `https://plugins.jenkins.io/metrics/`
- **JCasC plugin**: `https://plugins.jenkins.io/configuration-as-code/`

## CloudBees (comercial)

- **CloudBees CI product page**: `https://www.cloudbees.com/products/cloudbees-ci`
- **CloudBees CI HA docs**: `https://docs.cloudbees.com/docs/cloudbees-ci/latest/traditional-admin-guide/high-availability`

## Kubernetes + Jenkins

- **Jenkins Operator (OSS)**: `https://jenkinsci.github.io/kubernetes-operator/`
- **Velero (backup K8s)**: `https://velero.io/docs/`
- **Kubernetes plugin for Jenkins**: `https://plugins.jenkins.io/kubernetes/`

## Targets de migración

- **GitHub Actions — reusable workflows**: `https://docs.github.com/en/actions/sharing-automations/reusing-workflows`
- **GitHub Actions — OIDC to AWS**: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services`
- **GitLab CI/CD Components**: `https://docs.gitlab.com/ee/ci/components/`
- **GitLab OIDC (`CI_JOB_JWT_V2`)**: `https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html`
- **Argo Workflows**: `https://argo-workflows.readthedocs.io/`
- **Tekton Pipelines**: `https://tekton.dev/docs/`

## Dual-run y testing de pipelines

- **JenkinsPipelineUnit** (unit test de Jenkinsfiles): `https://github.com/jenkinsci/JenkinsPipelineUnit`
- **act** (correr workflows GHA localmente): `https://github.com/nektos/act`
- **reproducible builds**: `https://reproducible-builds.org/`

## OIDC federation (clave para apagar `withCredentials`)

- **AWS — IAM OIDC provider for GitHub**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html`
- **GCP — Workload Identity Federation**: `https://cloud.google.com/iam/docs/workload-identity-federation`
- **Azure — Federated credentials para GitHub**: `https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation`

## Lecturas y charlas

- Jenkins World / DevOps World — talks de operar Jenkins a escala. Buscar la edición más reciente en YouTube.
- Blog: "Migrating from Jenkins to GitHub Actions" (GitHub blog, varias ediciones).
- Blog: "Jenkins at scale" posts de Netflix, LinkedIn, Target engineering.

## Para los cursos previos (contexto)

- Si no completaste `jk-04`, al menos lee: Shared Libraries overview en el handbook de Jenkins.
- Si no completaste `jk-07`, al menos lee: Jenkins hardening checklist.

## Checklist de verificación requerida en Fase 4

- Última LTS publicada y su changelog (en `jenkins.io/changelog-stable/`).
- Estado comercial de **CloudBees CI** (nombre y pricing suelen cambiar — CloudBees reorganiza su catálogo cada ~18 meses).
- Si **Jenkins Operator** sigue mantenido (ha habido periodos de poca actividad).
- Si GHA ha publicado novedades en reusable workflows u OIDC claim scoping.
- Si GitLab CI/CD Components dejaron ya el estado beta.
- Si **Argo Workflows** se mantiene como estándar de facto para K8s-native (vs **Tekton** o alternativas emergentes).
