# Ejemplo 01 — Federated credential GitHub Actions -> Entra ID

> Lectura y analisis. Sin ejecucion. Objetivo: ser capaz de **leer** un federated credential y predecir que workflows pueden asumirlo.

## 1. Las piezas

```
+-----------------------+        OIDC id_token (JWT firmado por GitHub)
|  GitHub Actions run   | -----------------------------------------+
|  repo: acme/checkout  |                                          |
|  ref:  refs/heads/main|                                          v
+-----------------------+                              +-----------------------+
                                                       |  Entra ID (tenant X)  |
                                                       |  App registration     |
                                                       |  "gha-deployer"       |
                                                       |                       |
                                                       |  federated_credentials|
                                                       |   - subject: ...      |
                                                       |   - issuer:  ...      |
                                                       |   - audience: ...     |
                                                       +----------+------------+
                                                                  |
                                       Si token.sub == cred.subject
                                       Y   token.iss == cred.issuer
                                       Y   token.aud == cred.audience
                                                                  v
                                                       access_token (1h) con el
                                                       scope del app registration
```

## 2. El token OIDC de GitHub (ejemplo decodificado)

GitHub emite un JWT con **estos claims relevantes** (los nombres son del `payload`):

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:acme/checkout:ref:refs/heads/main",
  "aud": "api://AzureADTokenExchange",
  "repository": "acme/checkout",
  "repository_owner": "acme",
  "ref": "refs/heads/main",
  "ref_type": "branch",
  "environment": null,
  "job_workflow_ref": "acme/checkout/.github/workflows/deploy.yml@refs/heads/main",
  "actor": "alice",
  "event_name": "push",
  "iat": 1734000000,
  "exp": 1734003600
}
```

Clave: el `sub` es **determinista** segun **que** disparo el workflow:

| Caso del workflow | `sub` que llega |
|-------------------|-----------------|
| Push a `main` | `repo:acme/checkout:ref:refs/heads/main` |
| Push a `feature/x` | `repo:acme/checkout:ref:refs/heads/feature/x` |
| Tag `v1.2.3` | `repo:acme/checkout:ref:refs/tags/v1.2.3` |
| Pull request (de rama interna) | `repo:acme/checkout:pull_request` |
| Job en environment `prod` | `repo:acme/checkout:environment:prod` |

## 3. El federated credential (Terraform)

```hcl
# Fija: issuer y audience son globales de GHA + Entra ID
locals {
  gha_issuer   = "https://token.actions.githubusercontent.com"
  gha_audience = "api://AzureADTokenExchange"
}

# Variante A: solo push a main
resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.deployer.id
  display_name   = "gha-checkout-main"
  description    = "GHA main branch of checkout repo"
  audiences      = [local.gha_audience]
  issuer         = local.gha_issuer
  subject        = "repo:acme/checkout:ref:refs/heads/main"
}

# Variante B: solo environment prod (con approval requerido)
resource "azuread_application_federated_identity_credential" "env_prod" {
  application_id = azuread_application.deployer.id
  display_name   = "gha-checkout-env-prod"
  description    = "GHA environment prod of checkout repo"
  audiences      = [local.gha_audience]
  issuer         = local.gha_issuer
  subject        = "repo:acme/checkout:environment:prod"
}

# Variante C: tags semver (si tu Entra ID soporta claims matching con comodin)
# Nota: a dia de hoy el matching es exacto string. Para tags, suele usarse
# un subject por tag o pinnear por `job_workflow_ref`.
```

## 4. Variantes de pin: tabla comparativa

| Variante | subject | Pros | Contras |
|----------|---------|------|---------|
| Por ref (branch) | `repo:o/r:ref:refs/heads/main` | Simple. | Alguien con push a main puede desplegar; no exige approval. |
| Por environment | `repo:o/r:environment:prod` | GHA environments permiten **required reviewers**, timers, protected branches. **Preferida en prod**. | Hay que configurar environment en GitHub UI. |
| Por tag | `repo:o/r:ref:refs/tags/v1.2.3` | Deploys atados a tags inmutables. | Un federated credential por tag es inviable; usa job_workflow_ref o env. |
| Por `job_workflow_ref` | `repo:o/r:job_workflow_ref:...` | Rechaza ejecucion desde workflows distintos (resiste typosquatting dentro del repo). | Mas rigido; refactor del workflow rompe la credencial. |
| Por repo (sin ref) | `repo:o/r:*` **MAL** | — | Equivale a "cualquier branch, cualquier PR, cualquier env". **No lo uses.** |

## 5. El workflow YAML que lo consume

```yaml
name: deploy-prod

on:
  push:
    branches: [main]

permissions:
  id-token: write    # imprescindible: autoriza al runner a solicitar OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: prod   # habilita el `environment:prod` del subject si usas variante B
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC, no secrets)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}       # publico (vars, no secrets)
          tenant-id: ${{ vars.AZURE_TENANT_ID }}       # publico
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}  # publico

      - run: az account show
      - run: az acr login --name acrcheckoutprod
      - run: az aks get-credentials -g rg-checkout-prod -n aks-checkout-prod --overwrite-existing
```

Los tres IDs (`client-id`, `tenant-id`, `subscription-id`) **no son secretos**: identifican la aplicacion y el tenant. El acceso lo da el OIDC token efimero, no un valor estatico. Por eso van en `vars`, no en `secrets`.

## 6. Que puede salir mal

### 6.1 Error `AADSTS70021: No matching federated identity record found`

El `sub` del token no coincide con ningun `subject` registrado. Lo mas comun:

- Olvidaste el `environment: prod` en el job (entonces `sub` NO tiene `:environment:prod`, aunque tu federated credential si lo exija).
- Pusheaste a `feat/x` y tu federated credential pinnea `refs/heads/main`.
- Confundiste `refs/heads/main` con `main` a secas.

**Diagnostico**: dentro del workflow, imprimir el token y decodificarlo:

```yaml
      - name: Debug OIDC token
        env:
          ACTIONS_ID_TOKEN_REQUEST_URL: ${{ env.ACTIONS_ID_TOKEN_REQUEST_URL }}
          ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${{ env.ACTIONS_ID_TOKEN_REQUEST_TOKEN }}
        run: |
          TOKEN=$(curl -sSL -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
                  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)
          echo "sub: $(echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq -r .sub)"
```

> **No** imprimas el token completo en logs: aunque es efimero, puede dar informacion util a un atacante durante su ventana de validez.

### 6.2 El workflow no tiene `permissions: id-token: write`

Error visible: `Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable`. Significa que GHA ni siquiera emitio token. **Fix**: anadir el bloque `permissions` a nivel job o workflow.

### 6.3 Un fork hace PR y pide el OIDC

GitHub **no** emite OIDC tokens para PRs desde forks por defecto (`pull_request_target` es la excepcion y hay que usarla con cuidado). Si **si** quieres permitirlo (p. ej. solo para jobs read-only), hazlo con `pull_request_target` + `permissions` restringidas + review manual.

## 7. Preguntas de autocomprobacion

1. ¿Por que `tenant-id` y `client-id` pueden ir en `vars` y no en `secrets`?
2. Si usas `subject = "repo:acme/checkout:ref:refs/heads/main"` y alguien crea una rama llamada `main` en un fork, ¿puede obtener token? ¿Por que no?
3. ¿Que diferencia hay entre poner el pin en `ref` vs en `environment`?
4. ¿Como forzas que **solo** un workflow concreto (`.github/workflows/deploy.yml`) pueda obtener token, aunque haya otros workflows en el repo?
5. Un developer pide "credenciales de Azure para probar un script local". ¿Como lo soluciones sin crear un client secret?
