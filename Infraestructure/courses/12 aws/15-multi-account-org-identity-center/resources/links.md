# Recursos — aws-15

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing pueden cambiar).

## Oficiales (AWS)

- **AWS Organizations User Guide**: `https://docs.aws.amazon.com/organizations/latest/userguide/`
- **Service Control Policies (SCPs)**: `https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html`
- **AWS Control Tower User Guide**: `https://docs.aws.amazon.com/controltower/latest/userguide/`
- **AWS IAM Identity Center User Guide**: `https://docs.aws.amazon.com/singlesignon/latest/userguide/`
- **AWS Security Reference Architecture (SRA)**: `https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/`
- **AWS Multi-Account Strategy whitepaper**: `https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/`

## SCPs: ejemplos oficiales

- **SCP example policies**: `https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html`
- **IAM policy evaluation logic**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html`
- **Global condition keys** (`aws:RequestedRegion`, `aws:PrincipalArn`, `aws:MultiFactorAuthPresent`): `https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html`

## IAM Identity Center

- **Permission sets**: `https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html`
- **External IdP integration (SAML)**: `https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html`
- **SCIM provisioning (Okta/Entra ID)**: `https://docs.aws.amazon.com/singlesignon/latest/userguide/scim-profile-saml.html`
- **AWS CLI sso**: `https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html`

## Control Tower

- **Guardrails reference**: `https://docs.aws.amazon.com/controltower/latest/userguide/guardrails.html`
- **Pricing (gratis el servicio; cobran los subyacentes)**: `https://aws.amazon.com/controltower/pricing/`

## Terraform / IaC

- **terraform-aws-modules/organization/aws** (comunidad): `https://registry.terraform.io/modules/terraform-aws-modules/organization/aws/latest`
- **AWS Landing Zone Accelerator**: `https://aws.amazon.com/solutions/implementations/landing-zone-accelerator-on-aws/`

## Lecturas y charlas

- re:Invent — "SEC201", "SEC309" (multi-account strategy, Control Tower). Buscar la edición más reciente en YouTube.
- Blog: "Best practices for AWS Organizations" (AWS Security Blog, varias ediciones por año).
- Blog: "Design principles for AWS multi-account strategy" (varias ediciones).

## Para el curso previo (contexto)

- Si no completaste `aws-06`, al menos lee:
  - IAM policy evaluation logic (link arriba).
  - Trust policies y `sts:AssumeRole`.

## Checklist de verificación requerida en Fase 4

- Nombre actual del servicio (**IAM Identity Center** reemplazó a **AWS SSO**; verificar que no haya habido un re-naming posterior).
- Pricing actual de Control Tower (los servicios subyacentes).
- Si Account Factory soporta ya *customization* nativo (sin solution externa).
- Si SCPs soportan ya nuevas condition keys relevantes (`aws:PrincipalOrgID`, `aws:ResourceOrgID`).
- Estado del *delegated administrator* para GuardDuty / SecurityHub / Config (ha ido ampliándose).
