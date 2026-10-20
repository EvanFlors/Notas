# Recursos — aws-16-devsecops-on-aws

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso: precios, disponibilidad regional y estados cambian.

## OIDC GitHub Actions → AWS

- GitHub docs — About security hardening with OpenID Connect: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
- GitHub docs — Configuring OpenID Connect in AWS: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services`
- AWS blog — Use IAM roles to connect GitHub Actions to actions in AWS: `https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/`
- Action oficial `aws-actions/configure-aws-credentials`: `https://github.com/aws-actions/configure-aws-credentials`
- IAM — `AssumeRoleWithWebIdentity`: `https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html`
- IAM — Creating OIDC identity providers: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html`

## IRSA y Pod Identity (EKS)

- IRSA — docs oficiales: `https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html`
- Pod Identity — docs oficiales: `https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html`
- Comparativa IRSA vs Pod Identity (AWS blog): `https://aws.amazon.com/blogs/containers/amazon-eks-pod-identity-a-new-way-for-applications-on-eks-to-obtain-iam-credentials/`
- EKS addon `eks-pod-identity-agent`: `https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html`

## Secrets Manager y rotación

- AWS Secrets Manager — Rotate secrets: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html`
- Lambda rotators oficiales (RDS): `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets-rds.html`
- Modelo de los 4 pasos (`createSecret`, `setSecret`, `testSecret`, `finishSecret`): `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_how.html`
- Pricing: `https://aws.amazon.com/secrets-manager/pricing/`

## ECR y scanning

- ECR — Image scanning: `https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html`
- ECR — Enhanced scanning (Inspector v2): `https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-enhanced.html`
- Amazon Inspector v2: `https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html`
- Pricing ECR: `https://aws.amazon.com/ecr/pricing/`
- Pricing Inspector: `https://aws.amazon.com/inspector/pricing/`

## GuardDuty, Config, Security Hub, Macie, Access Analyzer

- GuardDuty: `https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html`
- GuardDuty — Finding types: `https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html`
- Config: `https://docs.aws.amazon.com/config/latest/developerguide/WhatIsConfig.html`
- Config — Conformance packs: `https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html`
- Security Hub: `https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html`
- Macie: `https://docs.aws.amazon.com/macie/latest/user/what-is-macie.html`
- IAM Access Analyzer: `https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html`
- Pricing GuardDuty: `https://aws.amazon.com/guardduty/pricing/`
- Pricing Config: `https://aws.amazon.com/config/pricing/`
- Pricing Security Hub: `https://aws.amazon.com/security-hub/pricing/`

## Cosign, sigstore, admission

- Cosign (sigstore): `https://docs.sigstore.dev/cosign/overview/`
- Keyless signing: `https://docs.sigstore.dev/cosign/signing/overview/`
- Rekor (transparency log): `https://docs.sigstore.dev/rekor/overview/`
- sigstore `policy-controller`: `https://docs.sigstore.dev/policy-controller/overview/`
- Kyverno — verify images: `https://kyverno.io/policies/?policytypes=verifyImages`

## AWS Security Reference Architecture (SRA)

- SRA — página oficial: `https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/welcome.html`
- SRA — repo de ejemplos: `https://github.com/aws-samples/aws-security-reference-architecture-examples`

## WAF

- AWS WAF: `https://docs.aws.amazon.com/waf/latest/developerguide/what-is-aws-waf.html`
- Managed rules (OWASP, bot control): `https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html`

## Herramientas locales (actividades)

- Terraform: `https://developer.hashicorp.com/terraform/install`
- Checkov (análisis estático HCL): `https://www.checkov.io/`
- Trivy (scan de imágenes y HCL): `https://aquasecurity.github.io/trivy/`
- `aws-vault` (para no almacenar credenciales en `~/.aws/credentials`): `https://github.com/99designs/aws-vault`

## Checklist Fase 4

- Pricing y matriz regional de **Inspector v2 enhanced scanning**.
- Pricing y matriz regional de **GuardDuty** (fuentes activas por región).
- Estado y matriz regional de **EKS Pod Identity**.
- `aws-actions/configure-aws-credentials` versión mayor vigente (v4 al momento de escribir).
- Soporte de **keyless cosign** en pipelines públicos (OIDC + Rekor están GA, pero conviene revalidar).
