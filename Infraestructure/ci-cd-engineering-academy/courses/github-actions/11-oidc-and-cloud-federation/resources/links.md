# Recursos — gha-11-oidc-and-cloud-federation

## Documentación oficial GitHub

- "About security hardening with OpenID Connect" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- "Configuring OpenID Connect in AWS" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- "Configuring OpenID Connect in Google Cloud Platform" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform
- "Configuring OpenID Connect in Azure" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
- "Using workflow commands to request an OIDC token" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#updating-your-actions-for-oidc

## Acciones oficiales

- `aws-actions/configure-aws-credentials` — https://github.com/aws-actions/configure-aws-credentials
- `google-github-actions/auth` — https://github.com/google-github-actions/auth
- `azure/login` — https://github.com/Azure/login

## Documentación oficial de clouds

- AWS: "Creating OpenID Connect (OIDC) identity providers" — https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html
- AWS: `sts:AssumeRoleWithWebIdentity` — https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html
- GCP: "Workload Identity Federation" — https://cloud.google.com/iam/docs/workload-identity-federation
- GCP: "Configure Workload Identity Federation with GitHub Actions" — https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions
- Azure: "Federated identity credentials in Microsoft Entra ID" — https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation
- Azure: "Configure a GitHub Actions workflow to use federated identity" — https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions

## Especificaciones

- JWT (RFC 7519) — https://datatracker.ietf.org/doc/html/rfc7519
- OpenID Connect Core 1.0 — https://openid.net/specs/openid-connect-core-1_0.html
- OIDC Discovery 1.0 — https://openid.net/specs/openid-connect-discovery-1_0.html

## Lecturas recomendadas

- "GitHub Actions OIDC: a deep dive" (Chris Wilson, Palantir blog, 2023) — https://blog.palantir.com/
- "Keyless deployment to AWS from GitHub Actions" (AWS Security Blog, 2022) — https://aws.amazon.com/blogs/security/
- "Attacking and defending GitHub Actions OIDC" (CloudSecurityForum talks, 2024) — múltiples charlas en YouTube

## Herramientas

- `gh` CLI — https://cli.github.com/ (para inspeccionar workflows y runs).
- `aws iam list-open-id-connect-providers` — AWS CLI, para auditar providers.
- `gcloud iam workload-identity-pools list` — GCP CLI.
- StepSecurity Harden-Runner — https://github.com/step-security/harden-runner (defensa en profundidad).

## Módulos relacionados en el programa

- `gh-13-03-oidc-federation-to-cloud` (curso Git/GitHub) — introducción al mismo patrón; este módulo profundiza.
- `gha-05-secrets-variables-and-environments-basics` — `permissions:` del `GITHUB_TOKEN`.
- `gha-09-environments-approvals-and-deployment-protection` — environments y gates.
- `gha-13-security-hardening` — hardening general del workflow, `pull_request_target`, `permissions:`.
