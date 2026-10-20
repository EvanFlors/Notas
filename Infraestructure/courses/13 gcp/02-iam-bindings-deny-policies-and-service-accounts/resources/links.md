# Recursos — gcp-02

## Documentación oficial

### IAM core

- [IAM overview](https://cloud.google.com/iam/docs/overview) — allow policies, bindings, roles.
- [Understanding roles](https://cloud.google.com/iam/docs/understanding-roles) — basic vs predefined vs custom.
- [Predefined roles reference](https://cloud.google.com/iam/docs/understanding-roles#predefined) — índice de todos los predefined.
- [Principal identifiers](https://cloud.google.com/iam/docs/principal-identifiers) — prefijos `user:`, `group:`, `serviceAccount:`, `principalSet://`.

### Deny policies

- [Deny policies overview](https://cloud.google.com/iam/docs/deny-overview) — modelo y evaluación.
- [Create and manage deny policies](https://cloud.google.com/iam/docs/deny-access) — CLI/API.
- [Permissions supported in deny policies](https://cloud.google.com/iam/docs/deny-permissions-support) — matriz; comprueba antes de confiar un deny crítico.

### Service accounts e impersonation

- [Service accounts overview](https://cloud.google.com/iam/docs/service-account-overview).
- [Best practices for service accounts](https://cloud.google.com/iam/docs/best-practices-service-accounts) — por qué no keys.
- [Create short-lived credentials (impersonation)](https://cloud.google.com/iam/docs/create-short-lived-credentials-direct) — `generateAccessToken`.
- [`gcloud --impersonate-service-account` reference](https://cloud.google.com/sdk/gcloud/reference#--impersonate-service-account).

### Org policies

- [Organization policy constraints](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints) — catálogo completo.
- [`iam.disableServiceAccountKeyCreation`](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-service-accounts#disable_service_account_key_creation).
- [`iam.automaticIamGrantsForDefaultServiceAccounts`](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-service-accounts#disable_service_account_default_grants).

### Conditions / CEL

- [IAM Conditions overview](https://cloud.google.com/iam/docs/conditions-overview).
- [CEL language reference](https://github.com/google/cel-spec/blob/master/doc/langdef.md).

### Audit logs

- [Cloud Audit Logs overview](https://cloud.google.com/logging/docs/audit) — Admin Activity gratis, Data Access opt-in.
- [`serviceAccountDelegationInfo` schema](https://cloud.google.com/logging/docs/reference/audit/auditlog/rest/Shared.Types/AuthenticationInfo#ServiceAccountDelegationInfo).

## Lecturas complementarias

- Google: *Security best practices for IAM* — [cloud.google.com/iam/docs/using-iam-securely](https://cloud.google.com/iam/docs/using-iam-securely).
- Google: *Workload Identity Federation* (anticipo de `gcp-10`) — [cloud.google.com/iam/docs/workload-identity-federation](https://cloud.google.com/iam/docs/workload-identity-federation).

## Herramientas útiles (para fases posteriores, no requeridas aquí)

- `gcloud asset analyze-iam-policy` — simular evaluación efectiva de IAM.
- `gcloud policy-intelligence` — recomendaciones de reducción de privilegios basadas en uso real.
- Terraform providers: `google_project_iam_binding`, `google_storage_bucket_iam_binding`, `google_service_account_iam_binding`, `google_iam_deny_policy`.
