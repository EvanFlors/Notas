# Recursos — aws-06-iam-advanced

## Documentación oficial AWS

- [IAM policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html) — orden canónico de evaluación con SCPs, boundary, session, resource-based.
- [Service Control Policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) — qué son, dónde se adjuntan, ejemplos.
- [Permission boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) — mecánica y casos de delegación.
- [Session policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html#policies_session) — cómo acotar en `AssumeRole`.
- [Cross-account access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) — tutorial oficial con dos cuentas.
- [Global condition context keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html) — `aws:PrincipalOrgID`, `aws:SourceAccount`, `aws:MultiFactorAuthPresent`, etc.
- [Confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html) — vulnerabilidad y mitigaciones.
- [OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) — flujo oficial GitHub ↔ AWS.
- [IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html) — external access y unused access findings.
- [Generate policy from CloudTrail](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html) — least privilege iterativo.

## Terraform

- [`aws_iam_openid_connect_provider`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) — recurso del IdP OIDC.
- [`aws_iam_role` con `assume_role_policy`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) — cómo definir la trust policy.
- [`aws_organizations_policy`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) — SCPs vía Terraform.

## Opcionales — se saltan en este módulo

Herramientas potentes para política IAM que **no** se usan aquí (añaden deps Python/Node y no son necesarias para aprender la lógica):

- [`policy_sentry`](https://github.com/salesforce/policy_sentry) — generador de policies least-privilege por action-level crud mapping.
- [`iam-policy-json-to-terraform`](https://github.com/flosell/iam-policy-json-to-terraform) — conversor JSON ↔ HCL.
- [`cfn-policy-validator`](https://github.com/awslabs/aws-cloudformation-templates/tree/main/aws-iam-policy-validator) — valida policies dentro de un stack CloudFormation.
- [Parliament](https://github.com/duo-labs/parliament) — linter de policies IAM.

Si quieres probarlas por tu cuenta, los repos están arriba. Para este módulo basta `jq`.

## Lecturas conceptuales

- [AWS Well-Architected — Security Pillar: Identity and Access Management](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/identity-and-access-management.html).
- *"Separation of duties"* — por qué el admin de la cuenta de root nunca es el que despliega.
- *"Guardrails vs grants"* — SCPs y boundaries son guardrails; identity policies son grants.
