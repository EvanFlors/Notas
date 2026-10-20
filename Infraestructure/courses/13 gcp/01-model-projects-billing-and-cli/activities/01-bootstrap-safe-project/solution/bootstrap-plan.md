# Plan de bootstrap — checkout-dev (my-project-123)

## Contexto

Acme.io, startup europea de pagos, abre un project de **desarrollo** para la app `checkout`. Mapping AWS -> GCP: project ~= account, folder ~= OU. Compliance exige residencia en `europe-west1` (fallback `europe-west4`). Cloud Identity y MFA ya aplicadas; esta actividad asume ese baseline.

## Jerarquia

```
Organization acme.io
└── folders/dev
    └── my-project-123 (checkout-dev)
```

El project es la unidad de aislamiento duro. La Billing Account vive **fuera** del project y se enlaza.

## Project

- `projectId`: `my-project-123` (placeholder; en real `acme-checkout-dev-<hash4>`).
- `displayName`: `checkout-dev`.
- Parent: `folders/dev`.
- Owner inicial: grupo `platform@acme.io` (nunca un user individual).

## APIs

Set minimo habilitado por `enable-apis.sh`:

- `cloudresourcemanager.googleapis.com`
- `iam.googleapis.com`
- `iamcredentials.googleapis.com` (critico para **impersonation** y ADC sin keys)
- `serviceusage.googleapis.com`
- `cloudbilling.googleapis.com`
- `logging.googleapis.com`
- `monitoring.googleapis.com`

No se habilitan `compute`, `run`, `storage`, etc. hasta que el servicio concreto se introduce.

## Billing

- Billing Account corporativa: `billingAccounts/XXXXXX-XXXXXX-XXXXXX`.
- Enlace via `gcloud billing projects link my-project-123 --billing-account=XXXXXX-XXXXXX-XXXXXX`.
- `roles/billing.user` al grupo `platform@acme.io`.

## Budget

Ver `budget.yaml`. Resumen: 100 USD/mes, thresholds 50/90/100 CURRENT + 100 FORECASTED, notificacion a `projects/my-project-123/topics/budget-alerts` -> Cloud Function -> webhook Slack `#finops-alerts`.

## Labels

Obligatorios en project y recursos:

| Label | Value |
|-------|-------|
| `env` | `dev` |
| `app` | `checkout` |
| `owner` | `team-checkout` |
| `cost-center` | `eng-payments` |
| `data-classification` | `internal` |

```bash
gcloud projects update my-project-123 \
  --update-labels=env=dev,app=checkout,owner=team-checkout,cost-center=eng-payments,data-classification=internal
```

## Siguientes pasos

1. Cloud Identity + MFA ya aplicadas (verificar en Fase 4).
2. Crear SA `app-local-dev@my-project-123.iam.gserviceaccount.com` + dar `roles/iam.serviceAccountTokenCreator` a `developers@acme.io` para **impersonation** sin keys (iamcredentials). Se detalla en `gcp-02` y en la actividad `02` de este modulo.
3. Terraform en Fase 4: migrar `enable-apis.sh` y `budget.yaml` a modulos `project-factory` y `google_billing_budget`.
4. Habilitar `run.googleapis.com`, `artifactregistry.googleapis.com`, `secretmanager.googleapis.com` cuando se introduzca Cloud Run.
5. Project `checkout-prod` analogo bajo `folders/prod` con labels `env=prod, data-classification=regulated`.
