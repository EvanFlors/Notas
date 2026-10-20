#!/usr/bin/env bash
# bootstrap.sh — PLAN de arranque de la subscription playground.
# DRY-RUN only: usa `--help`, comandos de lectura (`show`, `list`) y comentarios.
# Ningún comando destructivo real se ejecuta aquí.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several `az ... | grep -q`
# patterns can produce SIGPIPE (exit 141) when grep finds a match early. pipefail
# would spuriously mark those as failures.

set -eu

# --- Placeholders (NUNCA GUIDs reales) ----------------------------------------
TENANT_ID="00000000-0000-0000-0000-000000000000"
MG_ID="11111111-1111-1111-1111-111111111111"
SUBSCRIPTION_ID="22222222-2222-2222-2222-222222222222"
RG_NAME="rg-sandbox-dev"
RG_LOGS="rg-shared-logs"
LOCATION="westeurope"
BUDGET_NAME="budget-sandbox-dev-10usd"
BUDGET_AMOUNT=10

echo "== az-01 bootstrap PLAN =="
echo "Tenant (placeholder):       ${TENANT_ID}"
echo "Management Group (ph):      ${MG_ID}"
echo "Subscription (ph):          ${SUBSCRIPTION_ID}"
echo "Resource Group:             ${RG_NAME} (${LOCATION})"
echo "Resource Group (logs):      ${RG_LOGS} (${LOCATION})"
echo "Budget:                     ${BUDGET_NAME} (${BUDGET_AMOUNT} USD/mo)"
echo

# --- 0) Pre-flight: `az` disponible -------------------------------------------
if ! command -v az >/dev/null 2>&1; then
  echo "WARN: Azure CLI 'az' no está instalada. El plan sigue siendo válido;"
  echo "      instálala antes de Fase 4: https://learn.microsoft.com/cli/azure/install-azure-cli"
else
  az --version | head -1
fi

# --- 1) Login (COMENTADO: no se autentica nada contra Entra ID aquí) ----------
# az login --tenant "${TENANT_ID}"                     # interactivo (navegador)
# az login --use-device-code --tenant "${TENANT_ID}"   # SSH-friendly
# az account set --subscription "${SUBSCRIPTION_ID}"
echo "[plan] az login / az account set — comentados (no se ejecutan)."

# --- 2) Grupo de recursos (COMENTADO + --help) --------------------------------
echo
echo "[plan] az group create --help (lectura):"
if command -v az >/dev/null 2>&1; then
  az group create --help 2>/dev/null | head -5 || true
fi
# az group create --name "${RG_NAME}" --location "${LOCATION}" \
#     --tags env=sandbox owner=platform cost-center=CC-0001 \
#            workload=playground managed-by=manual
# az group create --name "${RG_LOGS}" --location "${LOCATION}" \
#     --tags env=sandbox owner=platform cost-center=CC-0001 \
#            workload=observability managed-by=manual

# --- 3) Resource providers (COMENTADO + --help) -------------------------------
echo
echo "[plan] az provider register --help (lectura):"
if command -v az >/dev/null 2>&1; then
  az provider register --help 2>/dev/null | head -5 || true
fi
# Providers mínimos para el playground:
# for p in \
#     Microsoft.Compute \
#     Microsoft.Network \
#     Microsoft.Storage \
#     Microsoft.KeyVault \
#     Microsoft.ManagedIdentity \
#     Microsoft.OperationalInsights \
#     Microsoft.Insights \
#     Microsoft.App \
#     Microsoft.ContainerRegistry
# do
#   az provider register --namespace "$p"
# done

# --- 4) `az` CLI defaults (COMENTADO) -----------------------------------------
# az config set defaults.group="${RG_NAME}" defaults.location="${LOCATION}"
echo "[plan] az config set defaults.group/location — comentado."

# --- 5) Budget con alertas (COMENTADO + --help) -------------------------------
echo
echo "[plan] az consumption budget create --help (lectura):"
if command -v az >/dev/null 2>&1; then
  az consumption budget create --help 2>/dev/null | head -5 || true
fi
# az consumption budget create \
#     --budget-name "${BUDGET_NAME}" \
#     --amount "${BUDGET_AMOUNT}" \
#     --category Cost \
#     --time-grain Monthly \
#     --start-date "$(date -u +%Y-%m-01)" \
#     --end-date   "$(date -u -d '+1 year' +%Y-%m-01 2>/dev/null || date -u -v+1y +%Y-%m-01)" \
#     --resource-group "${RG_NAME}" \
#     --notifications @notifications.json

# --- 6) Verificación (lectura, segura) ----------------------------------------
# az account show --query "{name:name, id:id, tenant:tenantId}" -o jsonc
# az group list --query "[?location=='${LOCATION}'].{name:name, tags:tags}" -o table
# az provider list --query "[?registrationState=='Registered'].namespace" -o table

echo
echo "OK — plan completado. Ningún recurso Azure fue creado."
echo "     Para materializar en Fase 4, revisa los comentarios y aplícalos tras aprobación."
