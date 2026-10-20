# Ejercicio operativo — Supply chain segura GCP (WIF + Binauthz + Audit Sink)

> **Dimensión:** operativa (35% del examen).
> **Tiempo sugerido:** 40–50 min.
> **Entorno:** local, sin GCP real. Toda validación es **plan-only** o estática.
> **Prerrequisitos de herramientas:** `terraform ≥ 1.6`, `tflint`, `checkov`, `jq`, `yq`.

## Contexto

Eres el platform engineer de **Acme Payments**, que opera su backend en GCP. Un pentest acaba de encontrar que el pipeline de GitHub Actions usa una clave JSON de service account con `roles/editor` sobre el project de producción, pegada como secret `GCP_SA_KEY`. Debes reemplazarla por **Workload Identity Federation**, mover la admisión a **Binary Authorization** basado en cosign, y exportar los **Audit Logs** a BigQuery.

## Placeholders (NO cambiar por valores reales)

```
PROJECT_PROD      = my-org-prod-123
PROJECT_SHARED    = my-org-shared-456
PROJECT_NUMBER    = 111111111111
GITHUB_ORG        = my-github-org
GITHUB_REPO       = payments-service
DEPLOY_SA_EMAIL   = deploy@my-org-prod-123.iam.gserviceaccount.com
CLUSTER           = projects/my-org-prod-123/locations/us-central1/clusters/gke-prod
BQ_DATASET        = audit_logs
ATTESTOR          = cosign-prod-attestor
REGION            = us-central1
```

## Tareas

### OP-task-1 — Workload Identity Pool + Provider (C8)

Entrega `operative/answer/wif.tf` que cree:

1. `google_iam_workload_identity_pool "github"` en `PROJECT_SHARED`.
2. `google_iam_workload_identity_pool_provider "github_oidc"` dentro del pool:
   - `oidc.issuer_uri = "https://token.actions.githubusercontent.com"`.
   - `attribute_mapping` que mapee al menos `google.subject`, `attribute.repository`, `attribute.ref`.
   - **`attribute_condition`** que exija simultáneamente `assertion.repository == "my-github-org/payments-service"` **y** `assertion.ref == "refs/heads/main"`.

### OP-task-2 — Binding de impersonation al SA de deploy (C8)

Entrega `operative/answer/sa_binding.tf` que:

1. Otorgue `roles/iam.workloadIdentityUser` sobre `DEPLOY_SA_EMAIL` **solo** al principal:
   `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/my-github-org/payments-service`
2. Otorgue a `DEPLOY_SA_EMAIL` los roles mínimos para desplegar en Cloud Run (`roles/run.admin`, `roles/iam.serviceAccountUser` sobre el runtime SA). **Prohibido** `roles/editor` o `roles/owner`.

### OP-task-3 — Binary Authorization (C9)

Entrega `operative/answer/binauthz.tf` que:

1. Cree un `google_binary_authorization_attestor "cosign_prod"` referenciando una `google_container_analysis_note` (puede ser mock vacío con nombre `projects/PROJECT_PROD/notes/cosign-prod-attestor`).
2. Cree un `google_binary_authorization_policy` con:
   - `default_admission_rule.evaluation_mode = "REQUIRE_ATTESTATION"`.
   - `default_admission_rule.enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"`.
   - `default_admission_rule.require_attestations_by = [google_binary_authorization_attestor.cosign_prod.name]`.
   - Una `cluster_admission_rules` para el `CLUSTER` con la misma política.

**Prohibido:** `evaluation_mode = "ALWAYS_ALLOW"` o `enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"` como default sin un `# JUSTIFICATION:` en comentario (y aun así perderás puntos).

### OP-task-4 — Audit Logs sink a BigQuery (C10)

Entrega `operative/answer/audit_sink.tf` que:

1. Cree un `google_bigquery_dataset "audit_logs"` en `PROJECT_SHARED`, `location = "US"`, `default_table_expiration_ms = 7776000000` (90 días).
2. Cree un `google_logging_project_sink "audit_to_bq"` en `PROJECT_PROD`:
   - `destination = "bigquery.googleapis.com/projects/my-org-shared-456/datasets/audit_logs"`.
   - `filter = "logName:\"cloudaudit.googleapis.com/activity\" OR logName:\"cloudaudit.googleapis.com/system_event\""`.
   - `unique_writer_identity = true`.
   - `exclusions` para excluir ruido tipo `protoPayload.methodName="k8s.io/events"`.
3. Otorgue a la `writer_identity` del sink el rol `roles/bigquery.dataEditor` sobre el dataset.

## Materiales de inicio

`operative/starter/` contiene:

- `versions.tf` con providers pinned.
- `variables.tf` con las variables tipadas (ya definidas; no las renombres).
- `locals.tf` con los IDs placeholder.
- `main.tf` vacío con un comentario de ejemplo.
- `.tflint.hcl` y `.checkov.yaml` preconfigurados.
- `validate.sh` que corre la validación completa.

Copia `operative/starter/` a `operative/answer/` y trabaja ahí.

## Validación

Desde `operative/answer/`:

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan.binary -var-file=../starter/example.tfvars
terraform show -json tfplan.binary > tfplan.json

# Checks automáticos
tflint --config=../starter/.tflint.hcl
checkov -d . --config-file ../starter/.checkov.yaml --quiet

# Aserciones específicas (deben imprimir "OK")
jq -e '
  .planned_values.root_module.resources[]
  | select(.type == "google_iam_workload_identity_pool_provider")
  | .values.attribute_condition
  | test("assertion.repository ==") and test("assertion.ref ==")
' tfplan.json && echo "OK: WIF condition doble"

jq -e '
  .planned_values.root_module.resources[]
  | select(.type == "google_binary_authorization_policy")
  | .values.default_admission_rule[0].evaluation_mode == "REQUIRE_ATTESTATION"
' tfplan.json && echo "OK: Binauthz REQUIRE_ATTESTATION"

jq -e '
  .planned_values.root_module.resources[]
  | select(.type == "google_project_iam_member")
  | .values.role
  | test("roles/(owner|editor)$") | not
' tfplan.json && echo "OK: sin roles basic"
```

`operative/starter/validate.sh` encapsula lo anterior.

## Rúbrica

Ver `EXAM.md` §5.2.

## Guía de corrección (instructor)

### Solución de referencia (sketch — NO entregar al alumno)

```hcl
# wif.tf
resource "google_iam_workload_identity_pool" "github" {
  project                   = local.project_shared
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  project                            = local.project_shared
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = ["https://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/github/providers/github-oidc"]
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  attribute_condition = <<-EOT
    assertion.repository == "my-github-org/payments-service" &&
    assertion.ref == "refs/heads/main"
  EOT
}
```

### Errores comunes y puntaje

| Error | Descuento |
|-------|-----------|
| `attribute_condition` omitido | invalida OP-task-1 (red flag) |
| Condition solo sobre `repository_owner` | −60% de OP-task-1 (red flag) |
| `roles/editor` o `roles/owner` a la SA | invalida OP-task-2 (red flag) |
| Binauthz policy sin `cluster_admission_rules` | −30% de OP-task-3 |
| Sink sin `unique_writer_identity = true` | −20% de OP-task-4 |
| Sink sin binding `bigquery.dataEditor` a la `writer_identity` | −20% de OP-task-4 |
| Hardcodear PROJECT_NUMBER en vez de usar `local.project_number` | −10% total |

### Red flags críticos (invalidan el ejercicio)

- Archivo `*.json` con `"type": "service_account"` en el entregable.
- Secret real (`GCP_SA_KEY`, access token GitHub, etc.).
- `terraform apply` ejecutado (hay `.terraform/terraform.tfstate` con resources reales).
- `evaluation_mode = "ALWAYS_ALLOW"` como default sin ADR.
