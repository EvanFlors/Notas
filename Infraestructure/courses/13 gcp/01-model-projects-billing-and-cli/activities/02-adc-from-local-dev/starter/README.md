# Starter — gcp-01-02-adc-from-local-dev

Esta actividad es **independiente**: produces 2 archivos (Markdown + bash). **No se toca GCP real.**

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-adc-vs-user-auth/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-01-adc
   cd /tmp/gcp-01-adc
   ```
3. Crea los dos archivos (nombres exactos):
   - `adc-plan.md`
   - `verify-adc.sh`
4. Hazlo ejecutable:
   ```bash
   chmod +x verify-adc.sh
   ```
5. Verifica la sintaxis:
   ```bash
   bash -n verify-adc.sh
   ```
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/01-model-projects-billing-and-cli/activities/02-adc-from-local-dev/tests/validate.sh /tmp/gcp-01-adc
   ```
7. Compara con `../solution/REFERENCE.md` y `../solution/*` para autoevaluarte.

## Esqueletos sugeridos

### `adc-plan.md`

```markdown
# Plan — ADC via impersonation para dev local (my-project-123)

## Problema
<user auth != ADC; DefaultCredentialsError; SA keys son antipatron>

## Mecanismos
<gcloud auth login vs gcloud auth application-default login; donde se guarda cada uno;
~/.config/gcloud/application_default_credentials.json;
cadena ADC en entornos GCP (metadata server / metadata.google.internal);
--impersonate-service-account; iamcredentials.googleapis.com;
roles/iam.serviceAccountTokenCreator>

## Flujo recomendado
1. gcloud auth login
2. gcloud auth application-default login --impersonate-service-account=app-local-dev@my-project-123.iam.gserviceaccount.com
3. Verificar con gcloud auth application-default print-access-token
4. Correr la app

## Chequeos
<comandos de lectura solamente; sin crear nada>

## Riesgos
<ADC con usuario = scope cloud-platform; laptop perdida; refresh token duradero>

## Antipatron
<SA keys (private_key); por que evitarlas; Org Policy iam.disableServiceAccountKeyCreation>
```

### `verify-adc.sh`

```bash
#!/usr/bin/env bash
# Verifica el estado de autenticacion y ADC en una laptop de developer.
# Comandos SOLO de lectura. Nunca crea, borra ni modifica nada en GCP.
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# posteriores con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria esos
# como fallos espurios.

set -eu

PROJECT_ID="${PROJECT_ID:-my-project-123}"
# Patron recomendado: ADC via --impersonate-service-account (sin keys).

if ! command -v gcloud >/dev/null 2>&1; then
  echo "WARN: gcloud no esta instalado; no se puede verificar en vivo."
  echo "      Instala el SDK y vuelve a correr."
  exit 0
fi

echo "== Cuentas conocidas por gcloud (user auth) =="
gcloud auth list || true

echo
echo "== Configuracion activa =="
gcloud config list || true

echo
echo "== ADC: intentando obtener un access token (sin ejecutar nada en GCP) =="
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "OK: ADC configurada. Las libraries cliente pueden autenticar."
else
  echo "FAIL: ADC no configurada. Corre:"
  echo "  gcloud auth application-default login --impersonate-service-account=app-local-dev@${PROJECT_ID}.iam.gserviceaccount.com"
fi
```

> El validador comprueba estructura, no semantica.
