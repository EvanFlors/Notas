# Recursos — gl-07

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas y nombres cambian; GitLab publica release cada mes 22).

## Oficiales (GitLab)

- **Environments and deployments**: `https://docs.gitlab.com/ee/ci/environments/`
- **Review Apps**: `https://docs.gitlab.com/ee/ci/review_apps/`
- **Protected environments**: `https://docs.gitlab.com/ee/ci/environments/protected_environments.html`
- **Deployment approvals**: `https://docs.gitlab.com/ee/ci/environments/deployment_approvals.html`
- **`environment:` keyword reference**: `https://docs.gitlab.com/ee/ci/yaml/#environment`
- **`auto_stop_in` reference**: `https://docs.gitlab.com/ee/ci/yaml/#environmentauto_stop_in`
- **Predefined CI/CD variables (`CI_MERGE_REQUEST_IID` etc)**: `https://docs.gitlab.com/ee/ci/variables/predefined_variables.html`

## GitLab Agent for Kubernetes

- **Agent overview**: `https://docs.gitlab.com/ee/user/clusters/agent/`
- **Install the agent (Helm)**: `https://docs.gitlab.com/ee/user/clusters/agent/install/`
- **GitOps mode**: `https://docs.gitlab.com/ee/user/clusters/agent/gitops.html`
- **CI/CD tunnel**: `https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html`

## Blue/green, canary y progressive delivery

- **Blog: Blue-green deployments with GitLab**: `https://about.gitlab.com/blog/2019/02/13/sast-feature-blue-green-deployments/`
- **Progressive delivery con feature flags (GitLab)**: `https://docs.gitlab.com/ee/operations/feature_flags.html`
- **Argo Rollouts** (si quieres canary serio por fuera): `https://argoproj.github.io/argo-rollouts/`
- **Flagger**: `https://docs.flagger.app/`

## Comparativa con GitHub Actions

- **GHA Environments**: `https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment`
- **Required reviewers (GHA)**: `https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers`

## Lecturas

- **Patterns for Managing Source Code Branches — Martin Fowler** (contexto Review Apps en TBD).
- **Google SRE Workbook — "Canarying releases"** (criterios para progressive delivery).
- Charlas de **GitLab Commit** / **GitLab Unfiltered** (YouTube) buscando "Review Apps", "GitLab Agent", "Deployment approvals" por año.
