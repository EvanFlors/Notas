# REFERENCE — gcp-01-01-bootstrap-safe-project

> Una **referencia** razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

# Plan de bootstrap — `checkout-dev` (placeholder `my-project-123`)

## Contexto

Acme.io es una startup europea de pagos. Existe ya una Organization GCP (`acme.io`) con `folders/prod`, `folders/dev`, `folders/shared`, y una Billing Account corporativa `billingAccounts/XXXXXX-XXXXXX-XXXXXX`.

El equipo de `checkout` necesita un **project de desarrollo** aislado del project de produccion. En el mapping AWS -> GCP, este project equivale a una **cuenta AWS de dev**: aislamiento IAM, cuotas propias, set propio de APIs habilitadas, enlazado a una Billing Account. La diferencia con AWS es que la Billing Account **se enlaza**, no vive dentro del project.

Compliance exige residencia de datos en Europa (`europe-west1` o `europe-west4`). El equipo de Security ya aplico MFA via Cloud Identity para todos los usuarios humanos; esta actividad asume ese baseline.

## Jerarquia

```
Organization: acme.io
└── folders/dev
    └── my-project-123   (checkout-dev)   <- este project
```

Mapping conceptual:

| GCP | AWS |
|-----|-----|
| Organization `acme.io` | Organization |
| `folders/dev` | OU `Dev` |
| `my-project-123` | account `checkout-dev` |
| labels sobre recursos | tags sobre recursos |

Un project en GCP es la unidad de aislamiento duro — equivalente a una account AWS. Herencia de bindings baja desde la Org, por `folders/dev`, hasta el project.

## Project

- **`projectId`**: `my-project-123` (placeholder). En la realidad: `acme-checkout-dev-7a3f` (convencion `<org>-<app>-<env>-<hash4>`). **Inmutable** tras creacion.
- **`displayName`**: `checkout-dev` (humano, editable).
- **Parent**: `folders/dev` (ID real omitido; se resuelve en Fase 4).
- **Owner inicial** (binding `roles/resourcemanager.projectOwner`): grupo `platform@acme.io` **unicamente** (nunca un usuario individual).

## APIs

Set minimo a habilitar al crear el project (vienen de `enable-apis.sh`):

| API | Para que |
|-----|----------|
| `cloudresourcemanager.googleapis.com` | gestionar projects, folders, labels. |
| `iam.googleapis.com` | crear service accounts, roles custom. |
| `iamcredentials.googleapis.com` | **impersonation** (sin keys) — critico para ADC local. |
| `serviceusage.googleapis.com` | habilitar/deshabilitar otras APIs. |
| `cloudbilling.googleapis.com` | leer billing info del project. |
| `logging.googleapis.com` | enviar logs a Cloud Logging. |
| `monitoring.googleapis.com` | enviar metricas, dashboards, SLOs. |

**No** se habilitan `compute`, `run`, `storage`, `sqladmin`, etc. — se habilitan cuando el equipo introduce el servicio correspondiente, para mantener el blast radius minimo.

## Billing

- Billing Account corporativa: `billingAccounts/XXXXXX-XXXXXX-XXXXXX`.
- Enlace: `gcloud billing projects link my-project-123 --billing-account=XXXXXX-XXXXXX-XXXXXX`.
- Roles sobre la BA: `roles/billing.user` al grupo `platform@acme.io` (puede enlazar/desenlazar projects); `roles/billing.viewer` a `finance@acme.io`.

## Budget

Ver `budget.yaml` adjunto. Resumen:

- Scope: solo `my-project-123`.
- Amount: 100 USD/mes (`calendarPeriod: MONTH`).
- Thresholds: 50%, 90%, 100% sobre `CURRENT_SPEND` + 100% sobre `FORECASTED_SPEND`.
- Notificaciones: topic `projects/my-project-123/topics/budget-alerts` -> Cloud Function -> webhook Slack `#finops-alerts`. Emails default a `roles/billing.user` activados.

## Labels

Labels obligatorios en **cada** recurso creado en el project (y en el project mismo):

| Label | Value propuesto | Para que |
|-------|-----------------|----------|
| `env` | `dev` | agrupacion basica dev/stg/prod/sandbox. |
| `app` | `checkout` | nombre de producto. |
| `owner` | `team-checkout` | equipo responsable (grupo, no persona). |
| `cost-center` | `eng-payments` | centro contable para FinOps. |
| `data-classification` | `internal` | `public|internal|confidential|regulated`. En dev no hay datos reales de pago. |

Comando de aplicacion al project:

```bash
gcloud projects update my-project-123 \
  --update-labels=env=dev,app=checkout,owner=team-checkout,cost-center=eng-payments,data-classification=internal
```

## Siguientes pasos

1. **Cloud Identity y MFA** ya aplicados (fuera del scope). Verificar: `gcloud organizations get-iam-policy ORG_ID | grep enforcedBy`.
2. **Impersonation** para developers: crear SA `app-local-dev@my-project-123.iam.gserviceaccount.com` con roles minimos; dar `roles/iam.serviceAccountTokenCreator` sobre esa SA al grupo `developers@acme.io`. (Se detalla en `gcp-02` y en la actividad `02` de este modulo).
3. **Terraform en Fase 4**: migrar `enable-apis.sh` y `budget.yaml` a `terraform-google-modules/project-factory/google` + `google_billing_budget`. Este plan sera el input de ese modulo.
4. **Habilitacion de APIs adicionales** cuando se introduzcan servicios: `run.googleapis.com` + `artifactregistry.googleapis.com` + `secretmanager.googleapis.com` para Cloud Run; `sqladmin.googleapis.com` para Cloud SQL; etc.
5. **Project de prod** (`checkout-prod`): un plan analogo, bajo `folders/prod`, con budget distinto y labels `env=prod, data-classification=regulated`.

---

## Notas sobre placeholders

- `my-project-123` es placeholder; **no es un project real**. Nunca ejecutar los comandos de este plan contra un project real sin governance.
- `billingAccounts/XXXXXX-XXXXXX-XXXXXX` es placeholder; el ID real se resuelve en Fase 4.
- Las folder IDs reales se omiten por el mismo motivo.
