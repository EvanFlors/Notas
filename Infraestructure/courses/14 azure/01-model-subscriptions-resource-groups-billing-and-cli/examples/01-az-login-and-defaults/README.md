# Ejemplo 01 — `az login` y defaults de CLI

> Lectura y análisis. Los comandos están **anotados** y pensados para `--help` / inspección — **no** ejecutes nada contra un tenant real en este módulo. Objetivo: fijar el flujo típico de autenticación y de defaults de la `az` CLI.

## 1. Flujo canónico

```bash
# 1) Login interactivo (abre navegador y auténtica contra Entra ID)
az login

# 2) Alternativa SSH-friendly (sin navegador): device code
az login --use-device-code

# 3) Lista de subscriptions visibles para el principal autenticado
az account list -o table
#   Name                        CloudName    SubscriptionId                        State    IsDefault
#   --------------------------  -----------  ------------------------------------  -------  ---------
#   Playground - EvanFlores     AzureCloud   11111111-1111-1111-1111-111111111111  Enabled  True
#   Prod - checkout             AzureCloud   22222222-2222-2222-2222-222222222222  Enabled  False

# 4) Seleccionar subscription activa (todas las operaciones siguientes irán allí)
az account set --subscription "11111111-1111-1111-1111-111111111111"

# 5) Confirmación
az account show --query "{sub:name, id:id, tenant:tenantId}" -o jsonc

# 6) Defaults: ahorran -g y -l en cada comando
az config set defaults.group=rg-sandbox-dev defaults.location=westeurope

# 7) Ver qué defaults quedaron
az configure --list-defaults
```

> **Importante**: los GUIDs mostrados (`11111111-...`, `22222222-...`, `00000000-...`) son **placeholders ficticios** usados en documentación oficial de Microsoft. **No** corresponden a ningún tenant/subscription real.

## 2. Service principal (para pipelines CI/CD) — adelanto

Esto se cubre a fondo en `az-02` y `az-10`. Resumen:

```bash
# NO EJECUTAR aquí — vista previa de cómo se autentican los pipelines sin usuario humano:
# az login --service-principal \
#     -u <appId> \
#     -p <password-or-cert> \
#     --tenant <tenantId>
#
# Preferible en moderno: OIDC Federation (sin secreto) GitHub Actions -> Entra ID.
# Se ve en az-10.
```

## 3. Jerarquía que ves después del login

Tras `az login` y `az account set`, la CLI opera **dentro de una subscription**. Visualmente:

```
Entra ID Tenant (00000000-0000-0000-0000-000000000000)
│
└── Subscription activa (11111111-1111-1111-1111-111111111111)   ← `az account show`
    │
    └── Resource Group default (rg-sandbox-dev)                   ← `az config set defaults.group=...`
        │
        └── Recursos (VMs, Storage, Key Vault, …)                 ← lo que crees con `az <servicio> create`
```

## 4. Dry-run / inspección sin coste

Todos los comandos "destructivos" tienen `--help`:

```bash
az group create --help
az storage account create --help
az deployment group what-if --help    # preview de un deployment ARM/Bicep
```

Para IaC Bicep / ARM, el equivalente a `terraform plan` es:

```bash
# NO EJECUTAR en este módulo. Vista previa:
# az deployment group what-if \
#     --resource-group rg-sandbox-dev \
#     --template-file main.bicep
```

## 5. Preguntas de autocomprobación

1. ¿Qué pasa si olvidas `az account set` y lanzas `az group create`? ¿En qué subscription se crea?
2. ¿Qué diferencia hay entre `az login` y `az login --service-principal`? ¿Por qué el segundo es *peligroso* a largo plazo (secreto en disco)?
3. ¿Por qué `az config set defaults.group=...` es un "ahorro de teclado" pero también un "pie en la trampa" si olvidas qué default tienes?
4. ¿Dónde quedan guardadas las credenciales tras `az login`? (pista: `~/.azure/`).

Las respuestas prácticas se trabajan en la actividad `01-bootstrap-safe-subscription`.
