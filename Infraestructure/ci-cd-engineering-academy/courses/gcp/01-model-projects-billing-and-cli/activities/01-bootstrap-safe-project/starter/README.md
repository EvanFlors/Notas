# Starter — gcp-01-01-bootstrap-safe-project

Esta actividad es **independiente**: produces 3 archivos (Markdown + bash + YAML) en papel. **No se toca GCP real.**

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del modulo (en particular `03-budget-with-notification`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-01-bootstrap
   cd /tmp/gcp-01-bootstrap
   ```
3. Crea los tres archivos (nombres exactos):
   - `bootstrap-plan.md`
   - `enable-apis.sh`
   - `budget.yaml`
4. Dale permisos ejecutables al script:
   ```bash
   chmod +x enable-apis.sh
   ```
5. Verifica la sintaxis:
   ```bash
   bash -n enable-apis.sh
   python3 -c "import yaml, sys; yaml.safe_load(open('budget.yaml')); print('OK')"
   ```
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/01-model-projects-billing-and-cli/activities/01-bootstrap-safe-project/tests/validate.sh /tmp/gcp-01-bootstrap
   ```
7. Compara con `../solution/REFERENCE.md` y `../solution/*` para autoevaluarte.

## Esqueletos sugeridos

### `bootstrap-plan.md`

```markdown
# Plan de bootstrap — checkout-dev (my-project-123)

## Contexto
<startup acme.io, Org con folders prod/dev/shared, BA corporativa, compliance eu-*, mapping AWS->GCP>

## Jerarquia
<Org -> folders/dev -> project my-project-123; project ~= account AWS>

## Project
<projectId placeholder my-project-123; displayName; parent folder>

## APIs
<cloudresourcemanager, iam, iamcredentials, serviceusage, cloudbilling, logging, monitoring>

## Billing
<link a billingAccounts/XXXXXX-XXXXXX-XXXXXX; roles billing.user>

## Budget
<100 USD/mes, thresholds 50/90/100 CURRENT + 100 FORECASTED, Pub/Sub -> Slack>

## Labels
<env, app, owner, cost-center, data-classification; cual value tendra cada uno>

## Siguientes pasos
<Cloud Identity + MFA ya aplicada; impersonation via iamcredentials; Terraform en Fase 4>
```

### `enable-apis.sh`

```bash
#!/usr/bin/env bash
# Habilita las APIs minimas de un project GCP nuevo.
# NO ejecutar contra un project real sin governance. Usa placeholder my-project-123.
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# subsiguientes con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria eso
# como fallo espurio.

set -eu

PROJECT_ID="${PROJECT_ID:-my-project-123}"

APIS=(
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  serviceusage.googleapis.com
  cloudbilling.googleapis.com
  logging.googleapis.com
  monitoring.googleapis.com
)

echo "Enabling minimal APIs on project ${PROJECT_ID}..."
for api in "${APIS[@]}"; do
  echo "  - ${api}"
  gcloud services enable "${api}" --project="${PROJECT_ID}"
done

echo "Done. Verify with:"
echo "  gcloud services list --enabled --project=${PROJECT_ID}"
```

### `budget.yaml`

```yaml
displayName: "checkout-dev monthly budget"

budgetFilter:
  projects:
    - "projects/my-project-123"
  calendarPeriod: MONTH

amount:
  specifiedAmount:
    currencyCode: "USD"
    units: "100"

thresholdRules:
  - thresholdPercent: 0.5
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 0.9
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: FORECASTED_SPEND

notificationsRule:
  pubsubTopic: "projects/my-project-123/topics/budget-alerts"
  schemaVersion: "1.0"
  disableDefaultIamRecipients: false
```

> El validador comprueba estructura, no semantica. Comparalo con `../solution/` tras hacerlo.
