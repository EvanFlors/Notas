# Recursos — aws-01

Referencias oficiales y lecturas de apoyo. **Verificar vigencia en Fase 4** del curso (los precios y features cambian seguido).

## Oficiales AWS

- **Global infrastructure (regiones y AZs)**: `https://aws.amazon.com/about-aws/global-infrastructure/`
- **Regions and AZs — docs**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html`
- **ARN format**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html`
- **AWS Service Endpoints (lista por servicio y región)**: `https://docs.aws.amazon.com/general/latest/gr/aws-service-information.html`
- **Signature Version 4 (SigV4)**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv.html`
- **AWS CLI v2 — install**: `https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html`
- **AWS CLI — configuration precedence**: `https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html`
- **IAM Identity Center (SSO) overview**: `https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html`
- **`aws sts get-caller-identity` reference**: `https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html`
- **Account root user — best practices**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#create-iam-users`

## Billing / Free Tier / costos

- **AWS Free Tier**: `https://aws.amazon.com/free/`
- **AWS Pricing**: `https://aws.amazon.com/pricing/`
- **AWS Pricing Calculator**: `https://calculator.aws`
- **AWS Budgets — docs**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/budgets-managing-costs.html`
- **AWS Cost Explorer — docs**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-what-is.html`
- **Billing & Cost Management — IAM access**: `https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/control-access-billing.html`
- **Precio de NAT Gateway (el gran villano)**: `https://aws.amazon.com/vpc/pricing/`

## Herramientas sin coste

- **LocalStack**: `https://docs.localstack.cloud/overview/`
- **LocalStack community image**: `https://hub.docker.com/r/localstack/localstack`
- **Terraform AWS provider — `aws_budgets_budget`**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget`
- **Terraform AWS provider — `aws_sns_topic`**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic`

## Seguridad inicial

- **MFA en root — paso a paso**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html`
- **CloudTrail — primer trail (gratis para management events)**: `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-tutorial.html`
- **IAM Access Analyzer**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html`

## Lecturas recomendadas (no oficiales)

- Corey Quinn — *Last Week in AWS* (blog/newsletter de ironía-pero-informada sobre AWS, especialmente billing): `https://www.lastweekinaws.com/`
- *AWS Cost Optimization* (whitepaper AWS): buscar en `aws.amazon.com/whitepapers`.
- *How to budget AWS from day one* — buscar artículos recientes de la comunidad.

## Checklist operativo (recordatorio)

Si tienes acceso a una cuenta real (ajena a este módulo), aplica el runbook del §9 de la lección en este orden exacto:

1. MFA en root.
2. Borrar access keys de root.
3. Habilitar IAM access to billing.
4. Crear budget con alerta por email.
5. Crear admin humano no-root (idealmente vía Identity Center).
6. Cerrar sesión de root.
7. Activar CloudTrail.
