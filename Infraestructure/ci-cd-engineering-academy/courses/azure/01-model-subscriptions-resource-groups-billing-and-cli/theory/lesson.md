# az-01 — Lección: modelo Azure, Subscriptions, Resource Groups, Billing y CLI

> 10 secciones. Mayoritariamente conceptual. Prerrequisitos: `aws-01`, `aws-02`. Útil haber visto `aws-15` para contrastar con AWS Organizations.

---

## 1. Por qué Azure "tiene un nivel más" que AWS

En AWS la jerarquía operativa es relativamente plana: **Organization → Account → Resource** (con OUs como *carpetas* intermedias). La **cuenta** es a la vez el límite duro de aislamiento (IAM, red, billing) y la unidad administrativa.

En Azure la jerarquía es **más larga**:

```
Tenant (Microsoft Entra ID — identidad y gobernanza)
  └── Management Group (opcional, jerárquico, para gobierno)
        └── Subscription (unidad de facturación + límite de cuota + contenedor de recursos)
              └── Resource Group (unidad de deploy y de eliminación en cascada)
                    └── Resource (VM, Storage Account, Key Vault, VNet…)
```

Dos niveles son los **diferenciales clave** respecto a AWS:

- **Resource Group (RG)**: carpeta lógica dentro de una subscription. Un recurso **vive siempre en exactamente un RG** y hereda su region para el *metadata* del grupo. Al borrar el RG, se borran **en cascada** todos los recursos que contiene — esta es la vía estándar para limpiar un entorno dev. AWS no tiene equivalente directo (en AWS vives con tags o con cuentas separadas).
- **Management Group (MG)**: carpeta jerárquica *por encima* de la Subscription. Equivalente conceptual a una **OU** de AWS Organizations. En este módulo lo mencionamos y lo usamos "en papel"; su despliegue serio es tema de `az-09`.

> **Idea clave:** en AWS el límite duro es la **cuenta**; en Azure el límite duro de facturación/cuota es la **subscription**, pero la **unidad de operación diaria** (deploy, limpieza, agrupación por entorno) es el **Resource Group**.

---

## 2. Tenant: la raíz de identidad y gobernanza

El **tenant** es una instancia de **Microsoft Entra ID** (antes "Azure AD"). Cada organización que usa Azure tiene al menos un tenant, identificado por un **GUID**:

```
Tenant ID: 00000000-0000-0000-0000-000000000000   (placeholder didáctico)
```

El tenant es el ancla de:

- **Usuarios y grupos** (Entra ID).
- **Service principals** y **Managed Identities** (identidades de workloads — `az-02`).
- **Management Groups** y **Subscriptions** asociadas al tenant.

**Importante — tenant ≠ billing account**: la **Billing Account** vive en una entidad distinta (Microsoft Customer Agreement / Enterprise Agreement). Un tenant puede estar asociado a **varias** Billing Accounts, y una Billing Account puede pagar **varias** subscriptions. Esta separación es intencional: cambios en el modelo de compra (de PAYG a EA, por ejemplo) no implican re-crear el tenant.

> **Trampa clásica**: confundir *tenant* con *subscription* porque "entras con el mismo login". El login es Entra ID (tenant). La subscription es la carpeta de pago donde viven los recursos.

---

## 3. Management Group (MG): la OU de Azure

Un **Management Group** es una **carpeta jerárquica** por encima de las subscriptions. Permite:

- Agrupar subscriptions por departamento, por entorno o por workload.
- Aplicar **Azure Policy** y **RBAC role assignments** heredadas por todas las subscriptions descendientes.
- Mantener una vista agregada de billing / inventario.

Jerarquía posible:

```
Tenant Root Group (creado automáticamente, GUID = tenant id)
  ├── Platform MG
  │     ├── identity        (subscription)
  │     ├── management      (subscription)
  │     └── connectivity    (subscription)
  ├── Landing Zones MG
  │     ├── Corp MG
  │     │     └── workload-A-prod
  │     └── Online MG
  │           └── workload-A-dev
  └── Sandbox MG
        └── sandbox-shared
```

Puntos clave:

- Jerarquía anidada, hasta 6 niveles de profundidad (soft limit).
- El **Tenant Root Group** siempre existe; no se puede borrar.
- Azure Policy y RBAC a nivel MG **heredan** a todas las subscriptions descendientes — por eso el patrón **CAF Landing Zone** (que verás en `az-09`) estructura los MGs como "Platform + Landing Zones + Sandbox + Decommissioned".

En este módulo no construimos la jerarquía completa. Nos basta con reconocer que **existe** y que un día tu subscription estará colgada de un MG.

---

## 4. Subscription: la unidad de billing + cuota

Una **Subscription** es, al mismo tiempo:

1. **Unidad de facturación**: su gasto va a un invoice separado.
2. **Límite de cuotas** (CPUs por region, cuentas de Storage, VNets, etc.).
3. **Contenedor de Resource Groups**: todo recurso Azure vive en una subscription (vía su RG).
4. **Scope de habilitación de resource providers** (ver §7).

Cada subscription tiene un GUID:

```
Subscription ID: 11111111-1111-1111-1111-111111111111  (placeholder)
```

### Tipos de subscription (resumen operativo)

| Tipo | Para quién | Características |
|------|------------|-----------------|
| **Free** | Prueba inicial. | Créditos de arranque, caducan en ~30 días. |
| **Pay-As-You-Go (PAYG)** | Individuos y proyectos pequeños. | Factura mensual por consumo, tarjeta de crédito. |
| **Enterprise Agreement (EA)** | Grandes empresas con contrato con Microsoft. | Descuentos por volumen, consumo contra un *commitment* anual. |
| **Microsoft Customer Agreement (MCA)** | El modelo moderno (reemplaza a EA en nuevas negociaciones). | Billing Accounts, Billing Profiles, Invoice Sections. |
| **CSP (Cloud Solution Provider)** | Comprada vía partner. | El partner factura y da soporte. |
| **Dev/Test** | Suscripciones ligadas a Visual Studio. | Precios reducidos, **sin SLA**, no apta para prod. |

> **Decisión práctica**: para experimentar sin coste, **Free + créditos iniciales** o **Dev/Test** si tu empresa paga Visual Studio. Para prod en una org pequeña, **MCA PAYG**. Para empresa seria con negociación anual, **EA/MCA Enterprise**.

### Separación billing / identidad

Una **Billing Account** (MCA/EA) puede pagar N subscriptions. Las subscriptions, a su vez, están asociadas a un tenant. Esto permite:

- Un tenant corporativo único (identidad única) pagando subscriptions de varias filiales (billing accounts distintas).
- Mover una subscription a otra Billing Account sin cambiar el tenant.

---

## 5. Resource Group (RG): la unidad que AWS no tiene

Un **Resource Group** es una **carpeta lógica** dentro de una subscription que contiene recursos. Reglas duras:

- Un recurso vive en **exactamente un RG** (no se puede estar en dos a la vez).
- El RG tiene **una region de metadata** (p. ej. `westeurope`). Esto **no obliga** a que los recursos dentro vivan en esa region — un RG en `westeurope` puede contener VMs en `northeurope`. El metadata del RG vive en esa region (relevante para disaster recovery del plano de control).
- Al borrar el RG, se borran **todos** los recursos contenidos, en cascada:

  ```bash
  # DRY-RUN / preview:
  az group delete --name rg-checkout-dev --yes --no-wait --dry-run    # (vista previa — ver az-02 para what-if)
  # Real (NO EJECUTAR en este módulo):
  # az group delete --name rg-checkout-dev --yes --no-wait
  ```

- Los **tags** del RG **no se heredan** automáticamente por los recursos — Azure Policy puede forzar herencia mediante `modify` effects (ver `az-09`).

### Granularidad: ¿cuántos RGs?

El patrón recomendado es **un RG = un ciclo de vida**:

- Un entorno de un workload (`rg-checkout-dev`, `rg-checkout-stg`, `rg-checkout-prod`).
- O un grupo funcional (`rg-shared-network`, `rg-shared-logs`).

La ventaja es operativa: para desmontar un entorno dev entero, `az group delete rg-checkout-dev` lo deja limpio en minutos. En AWS, para hacer lo mismo en una cuenta, tendrías que borrar recursos uno a uno (o usar cuentas enteras como unidad de desecho — más overhead).

### Patrón anti-RG-monster

Un error típico es un único `rg-prod` con 300 recursos de 15 workloads mezclados. Perjuicios:

- Imposible borrar nada en bloque sin romper otros workloads.
- RBAC a nivel RG se vuelve demasiado amplio o inútil.
- Tags por RG dejan de aportar información (todo es "prod").

**Regla de pulgar**: si no puedes imaginarte haciendo `az group delete` del RG sin pensarlo dos veces, el RG está mal dimensionado.

---

## 6. Nombres globalmente únicos

Algunos recursos Azure tienen **nombres DNS globales** (porque forman FQDNs públicos):

- **Storage Account**: `<name>.blob.core.windows.net` → `<name>` debe ser único en todo Azure.
- **Key Vault**: `<name>.vault.azure.net`.
- **App Service**: `<name>.azurewebsites.net`.
- **ACR (Azure Container Registry)**: `<name>.azurecr.io`.
- **Cosmos DB** (endpoint), **Azure SQL Server** (`<name>.database.windows.net`), etc.

Convenciones habituales:

```
st<workload><env><region><nnn>     # Storage: st = prefijo, nnn = sufijo numérico
kv-<workload>-<env>                # Key Vault
cr<workload><env>                  # ACR (sin guiones permitidos en ACR)
app-<workload>-<env>               # App Service
```

> **Trampa**: elegir nombres evidentes (`storageprod`, `kv-main`) suele chocar. Prefijar con la org / proyecto y sufijar numérico resuelve colisiones.

---

## 7. Resource Providers: habilitación por subscription

Un **resource provider** es el servicio que materializa recursos de una familia (`Microsoft.ContainerService` para AKS, `Microsoft.KeyVault` para Key Vault, `Microsoft.Storage` para Storage, etc.). Azure **no habilita todos por defecto** en cada subscription: hay que **registrarlos** explícitamente:

```bash
# Dry-run / inspección:
az provider list --query "[?registrationState=='Registered'].namespace" -o table
az provider show --namespace Microsoft.ContainerService --query registrationState

# Registración real (NO EJECUTAR en este módulo):
# az provider register --namespace Microsoft.ContainerService
```

Por qué este diseño:

- **Defensa en profundidad**: una subscription sin `Microsoft.ContainerService` registrado no puede ser forzada accidentalmente a crear un AKS.
- **Cuotas** y métricas: se gestionan por provider registrado.
- **Costos ocultos**: algunos providers habilitan recursos cuyos costos son fáciles de pasar por alto (p. ej. `Microsoft.OperationalInsights` crea Log Analytics workspaces que cobran por GB ingerido).

Lista mínima habitual para un workload moderno:

```
Microsoft.Compute, Microsoft.Network, Microsoft.Storage, Microsoft.KeyVault,
Microsoft.ContainerService, Microsoft.ContainerRegistry,
Microsoft.OperationalInsights, Microsoft.Insights, Microsoft.ManagedIdentity
```

---

## 8. `az` CLI operativa: login, defaults, perfiles

La `az` CLI es la vía oficial para operar Azure desde terminal. Flujo típico:

```bash
# 1. Login interactivo (abre navegador):
az login

# 2. Login no-interactivo (CI/CD) con service principal — se ve en az-10:
# az login --service-principal -u <appId> -p <secret> --tenant <tenantId>

# 3. Login con device code (SSH sin navegador):
az login --use-device-code

# 4. Ver subscriptions a las que tengo acceso:
az account list -o table

# 5. Seleccionar subscription activa:
az account set --subscription "11111111-1111-1111-1111-111111111111"

# 6. Verificar:
az account show -o table

# 7. Fijar defaults (ahorra -g y -l en cada comando):
az config set defaults.group=rg-sandbox-dev defaults.location=westeurope

# 8. Help / dry-run para cualquier comando:
az group create --name rg-x --location westeurope --help     # ayuda
az deployment group what-if ...                              # dry-run para ARM/Bicep
```

### `azd` (Azure Developer CLI)

`azd` es un *wrapper* orientado a developers que levanta un template completo (código + IaC Bicep/Terraform + pipelines) con `azd up`. Útil para quickstarts; no reemplaza a `az` para operación de infraestructura.

---

## 9. Budgets: el primer paso FinOps

Un **Budget** es un recurso Azure que monitoriza gasto y dispara **alertas** cuando se cruzan umbrales. Scope posible: Billing Account, MG, Subscription, Resource Group.

Anatomía:

```json
{
  "amount": 10,
  "timeGrain": "Monthly",
  "category": "Cost",
  "notifications": {
    "actual_80pct": {
      "enabled": true,
      "operator": "GreaterThan",
      "threshold": 80,
      "thresholdType": "Actual",
      "contactEmails": ["finops@example.com"]
    },
    "forecast_100pct": {
      "enabled": true,
      "operator": "GreaterThan",
      "threshold": 100,
      "thresholdType": "Forecasted",
      "contactEmails": ["finops@example.com"]
    }
  }
}
```

Puntos a interiorizar:

- Budgets **alertan**, **no bloquean** gasto. Para bloquear se usan **Azure Policy** `deny` effects o cuentas Dev/Test con tope duro.
- `Actual` dispara cuando el gasto ya ocurrió; `Forecasted` cuando el modelo predice que ocurrirá.
- Un **Action Group** puede enganchar email, SMS, webhook, Logic App, Function.
- Scope **Resource Group** es muy útil para sandboxes individuales con tope visible.

---

## 10. Tags: en RG y en recurso

Azure permite tags **tanto en el RG como en cada recurso**. Esto es diferente de AWS, donde los tags viven en los recursos (y los "grupos" son solo filtros). En Azure:

- Tags en el **RG**: útiles para intención del grupo (`owner`, `env`, `cost-center`, `workload`).
- Tags en el **recurso**: útiles para intención del recurso individual (`component`, `data-classification`, `backup-policy`).
- **No heredan** por defecto. Si quieres que todos los recursos del RG lleven `env=prod`, lo fuerzas con **Azure Policy** `append` o `modify`.

Convenciones comunes:

```json
{
  "env": "prod | stg | dev | sandbox",
  "owner": "team-slug-or-email",
  "cost-center": "CC-1234",
  "workload": "checkout | analytics | ...",
  "managed-by": "terraform | manual | azd"
}
```

> **Diferencia con AWS**: en AWS el patrón habitual es "tags obligatorios aplicados por SCPs/condiciones + reporting por Cost Explorer". En Azure, usar **ambos niveles** (RG + recurso) es la práctica recomendada; Azure Policy fuerza el baseline.

---

## Resumen operativo

| Nivel | Qué controla | Comando típico (dry-run / help) |
|-------|--------------|---------------------------------|
| Tenant | Identidad, root de MGs | `az account tenant list -o table` |
| Management Group | Policy + RBAC heredadas | `az account management-group list --help` |
| Subscription | Billing + cuota + providers | `az account set --subscription <id>` |
| Resource Group | Deploy + eliminación en cascada | `az group create --help` |
| Resource | La cosa concreta | `az resource list --help` |

El punto que debes dejar grabado para entrar en `az-02`: **la subscription es tu límite de billing + cuota; el RG es tu límite operativo diario**. Todo lo que verás después (RBAC, Policy, Key Vault, Managed Identity, Container Apps) se razona sobre esa jerarquía.
