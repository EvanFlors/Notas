# gl-06 — Recursos

## Documentación oficial

- GitLab Runner — Executors overview: https://docs.gitlab.com/runner/executors/
- GitLab Runner on Kubernetes (chart): https://docs.gitlab.com/runner/install/kubernetes/
- Helm chart `gitlab/gitlab-runner`: https://docs.gitlab.com/runner/install/kubernetes_helm_chart_configuration/
- Fleeting (autoscaler): https://docs.gitlab.com/runner/runner_autoscale/
- Fleeting plugin AWS: https://gitlab.com/gitlab-org/fleeting/plugins/aws
- Docker-in-Docker (DinD): https://docs.gitlab.com/ci/docker/using_docker_build/
- Kaniko: https://docs.gitlab.com/ci/docker/using_kaniko/
- Authentication tokens (modernos): https://docs.gitlab.com/ci/runners/new_creation_workflow/
- ID Tokens / OIDC: https://docs.gitlab.com/ci/secrets/id_token_authentication/
- OIDC a AWS: https://docs.gitlab.com/ci/cloud_services/aws/
- Protected environments: https://docs.gitlab.com/ci/environments/protected_environments/

## AWS

- IAM OIDC identity providers: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html
- `AssumeRoleWithWebIdentity`: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html

## Lecturas complementarias

- "Why not DinD" — discusión histórica del issue de Jérôme Petazzoni: https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
- GitLab blog — authentication tokens migration: https://about.gitlab.com/blog/2023/07/11/runner-registration-tokens-support-will-be-deprecated/

## Interno al curso

- `../../03-variables-and-secrets-protected-and-masked/theory/lesson.md` — base de ID Tokens y Vault.
- `../../02-gitlab-ci-yml-pipelines-runners/theory/lesson.md` — anatomía básica del runner.
- `../../../aws/15-multi-account-org-identity-center/theory/lesson.md` — cross-account roles y trust policies (patrón espejo al OIDC desde GitLab).
