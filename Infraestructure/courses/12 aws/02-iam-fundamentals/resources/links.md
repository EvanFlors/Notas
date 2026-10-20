# Recursos — aws-02-iam-fundamentals

Documentación oficial priorizada. En AWS, la documentación oficial envejece bien; prefierela a blogs.

## Documentación oficial

- **IAM User Guide — Policies and permissions**: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html
- **Policy JSON reference** (todos los elementos): https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html
- **Policy evaluation logic** (orden exacto): https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html
- **AWS STS API reference**: https://docs.aws.amazon.com/STS/latest/APIReference/welcome.html
- **IAM policy variables**: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html
- **IAM best practices**: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

## OIDC / federación

- **Create an OIDC identity provider**: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html
- **GitHub Actions → AWS via OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

## IAM Identity Center (SSO)

- **IAM Identity Center user guide**: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html
- **CLI con SSO (`aws sso login`)**: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html

## Herramientas de validación

- **`aws iam simulate-principal-policy`**: https://docs.aws.amazon.com/cli/latest/reference/iam/simulate-principal-policy.html
- **IAM Access Analyzer — policy generation**: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html
- **Policy Simulator (consola)**: https://policysim.aws.amazon.com/

## Lecturas que ahorran dolor

- *AWS IAM gotchas* — colección (comunidad): https://github.com/toniblyx/my-arsenal-of-aws-security-tools
- *The IAM evaluation flowchart* (imagen canónica, dentro de la doc oficial de evaluation logic).

## Siguiente nivel (ya en otros módulos)

- SCPs y permission boundaries → `aws-06-iam-advanced`.
- KMS key policies → `aws-09-kms-secrets-manager-parameter-store`.
- IRSA / Pod Identity → `aws-11-eks-in-depth`.
