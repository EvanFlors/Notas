#!/usr/bin/env bash
# Verifica el estado de autenticacion y ADC en la laptop de un developer.
# Comandos SOLO de lectura. Nunca crea, borra ni modifica nada en GCP.
# Patron recomendado: ADC via --impersonate-service-account (sin keys).
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# posteriores con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria esos
# como fallos espurios.

set -eu

PROJECT_ID="${PROJECT_ID:-my-project-123}"
SA_PLACEHOLDER="app-local-dev@${PROJECT_ID}.iam.gserviceaccount.com"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "WARN: gcloud no esta instalado; no se puede verificar en vivo."
  echo "      Instala el SDK: https://cloud.google.com/sdk/docs/install"
  exit 0
fi

echo "== 1. Cuentas conocidas por gcloud (user auth) =="
gcloud auth list || true

echo
echo "== 2. Configuracion activa =="
gcloud config list || true

echo
echo "== 3. ADC: intentando obtener un access token (solo lectura) =="
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "OK: ADC configurada. Las libraries cliente pueden autenticar."
else
  echo "FAIL: ADC no configurada. Patron recomendado (sin keys):"
  echo "  gcloud auth application-default login \\"
  echo "    --impersonate-service-account=${SA_PLACEHOLDER}"
fi

echo
echo "== 4. Comprobar que no hay SA key en GOOGLE_APPLICATION_CREDENTIALS =="
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  if printf '%s' "${GOOGLE_APPLICATION_CREDENTIALS}" | grep -qE '\.json$'; then
    echo "WARN: GOOGLE_APPLICATION_CREDENTIALS apunta a ${GOOGLE_APPLICATION_CREDENTIALS}"
    echo "      Si es un archivo con 'private_key', es una SA key (antipatron)."
    echo "      Migra a ADC via impersonation y 'unset GOOGLE_APPLICATION_CREDENTIALS'."
  fi
else
  echo "OK: GOOGLE_APPLICATION_CREDENTIALS no esta definida."
fi

echo
echo "Done."
