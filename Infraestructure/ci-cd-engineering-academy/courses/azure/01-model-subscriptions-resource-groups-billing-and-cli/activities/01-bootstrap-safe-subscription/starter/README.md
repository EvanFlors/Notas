# Starter — az-01-01-bootstrap-safe-subscription

Esta actividad es **independiente**: no hay código Azure que correr. Tu entregable es un ADR Markdown + un script bash **anotado** (dry-run / `--help`).

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-01-bootstrap
   cd /tmp/az-01-bootstrap
   ```
3. Crea `ADR-SUBSCRIPTION-BOOTSTRAP.md` con las 6 secciones ADR y el contenido mínimo (ver `../README.md` §5.2).
4. Crea `bootstrap.sh` con `chmod +x bootstrap.sh`.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/01-model-subscriptions-resource-groups-billing-and-cli/activities/01-bootstrap-safe-subscription/tests/validate.sh /tmp/az-01-bootstrap
   ```
6. Compara con `../solution/REFERENCE.md` y `../solution/bootstrap.sh`.

> **Nunca ejecutes `bootstrap.sh` contra una subscription real durante este módulo.** Está pensado como *plan*, no como *apply*.

## Esqueletos útiles

### ADR

```markdown
# ADR 001 — Bootstrap de la subscription playground

## Estado
Propuesto

## Contexto
<por qué, qué constraints: compliance Europa, startup 20p, sin coste inicial>

## Decisión

### 1. Jerarquía Azure

```text
Microsoft Entra ID Tenant (00000000-0000-0000-0000-000000000000)
└── Management Group: Sandbox MG (11111111-1111-1111-1111-111111111111)
    └── Subscription: Playground (22222222-2222-2222-2222-222222222222, type Dev/Test)
        ├── Resource Group: rg-sandbox-dev   (westeurope)
        └── Resource Group: rg-shared-logs   (westeurope)
```

### 2. Subscription type
...

### 3. Resource providers a registrar
- Microsoft.Compute
- Microsoft.Storage
- Microsoft.KeyVault

### 4. Budget
...

### 5. `az` CLI defaults
...

## Consecuencias
### Positivas
...
### Negativas
...

## Alternativas descartadas
### Alt A: una sola Subscription PAYG sin MG
- Por qué no: ...
### Alt B: cuenta Free (en lugar de Dev/Test)
- Por qué no: ...
```

### `bootstrap.sh` esqueleto

```bash
#!/usr/bin/env bash
# Bootstrap plan for az-01 playground. DRY-RUN only.
# Note: we deliberately do NOT enable `set -o pipefail` because many `az ... | grep -q`
# patterns can produce SIGPIPE (exit 141) when grep finds a match early.
set -eu

TENANT_ID="00000000-0000-0000-0000-000000000000"
SUBSCRIPTION_ID="22222222-2222-2222-2222-222222222222"
RG_NAME="rg-sandbox-dev"
LOCATION="westeurope"

echo "This script is a PLAN. It uses --help and comments, nothing destructive runs."

# az login --tenant "$TENANT_ID"                             # NO EJECUTAR
# az account set --subscription "$SUBSCRIPTION_ID"           # NO EJECUTAR

az --version
az group create --help | head -20
az provider register --help | head -10
az consumption budget create --help | head -10
# az config set defaults.group="$RG_NAME" defaults.location="$LOCATION"   # NO EJECUTAR

echo "OK — plan ejecutado sin tocar Azure."
```
