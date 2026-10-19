# Actividad 01 — Disenar la base DevSecOps + ADR + Terraform plan-only

## 1. Identificacion

- **ID:** `az-10-01-oidc-pipeline-tf-plan-and-adr`
- **Tecnologia:** `azure`
- **Modulo:** `az-10-devsecops-oidc-defender-acr-supply-chain`
- **Dificultad:** advanced
- **Duracion estimada:** 90–110 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

Volvemos a la startup del modulo `az-09`: tenant con MGs CAF, dos workloads (`checkout` y `analytics`). Toca aterrizar el **pipeline DevSecOps**. El equipo de Platform te pide:

1. **Eliminar los `client secret` del service principal** que hoy usa el pipeline de GitHub Actions (vive como `AZURE_CREDENTIALS` en GHA secrets) y migrarlo a **OIDC federated credential**.
2. **Promover ACR a Premium** en `checkout-prod` para habilitar Private Link y content trust (dev y stg se quedan en Standard).
3. **Habilitar Defender for Cloud** plan **Containers** en las subscriptions con AKS (prod + stg).
4. **Documentar la decision** en un ADR legible por un ingeniero externo, con la base Terraform plan-only (archivos `.tf` validos, sin `terraform apply`).

**Importante**: no hay tenant Azure real. **No** se ejecuta `terraform apply` ni `init`. El entregable es **papel + HCL + un workflow YAML**. Los IDs del tenant, subscription y app son placeholders (`00000000-0000-0000-0000-000000000000`).

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Describir el flujo OIDC entre GHA y Entra ID y por que elimina el `client secret`.
- Elegir el pattern de `subject` claim mas restrictivo que cubra tu caso (ref vs environment vs job_workflow_ref).
- Escribir el bloque `azuread_application_federated_identity_credential` con los campos correctos.
- Decidir SKU de ACR por workload con criterio.
- Justificar que planes de Defender habilitar y a que coste aproximado.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (en particular §1–§5 y §9) y los tres ejemplos.
- Haber completado `az-02`, `az-07`, `az-09`.
- Herramientas: `bash`, `jq`, `python3`. Opcional: `terraform fmt` (no `init`).

**Costos**: ninguno. Todo es papel + HCL.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-10-01/terraform
mkdir -p /tmp/az-10-01/.github/workflows
cd /tmp/az-10-01
```

Puedes usar otra ruta y pasarsela al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-DEVSECOPS-SUPPLY-CHAIN.md`

Secciones obligatorias (el validador las busca):

1. `# ADR` (encabezado con la palabra "ADR").
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decision` (o `Decision` / `Decisión`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives` — al menos 2 descartadas).

Contenido minimo (el validador lo exige, grep case-insensitive):

- Menciona explicita de **OIDC**, **federated credential** y **GitHub Actions**.
- Menciona explicita de **ACR** (Azure Container Registry) con al menos un SKU (`Premium` / `Standard`).
- Menciona explicita de **Defender for Cloud** (o `Defender for Containers`).
- Menciona explicita de **cosign** (o `sigstore`).
- Decision explicita sobre el **subject claim** (`repo:owner/repo:ref:...` o `environment:...`).
- Mencion de **Entra ID** (o `Azure AD`) y de **app registration**.
- Al menos **2 alternativas descartadas** (subheadings `### Alt` / `### Alternativa` / lista numerada `1.`/`2.`).

### 5.3 Escribe los archivos Terraform plan-only

Dentro de `/tmp/az-10-01/terraform/`:

- `main.tf` — bloque `terraform { required_providers { ... } }` con `azuread` y `azurerm`.
- `oidc.tf` — contiene al menos:
  - un `resource "azuread_application" "..."`,
  - un `resource "azuread_service_principal" "..."`,
  - un `resource "azuread_application_federated_identity_credential" "..."` con **todos** estos campos literales:
    - `issuer         = "https://token.actions.githubusercontent.com"`
    - `audiences      = ["api://AzureADTokenExchange"]`
    - un `subject` que empiece por `"repo:"`.
- `acr.tf` — un `resource "azurerm_container_registry" "..."` con:
  - `sku = "Premium"` (o similar) para el registry de prod,
  - `admin_enabled = false`.
- `defender.tf` — al menos un `resource "azurerm_security_center_subscription_pricing" "..."` con `resource_type = "Containers"` y `tier = "Standard"`.

> **No tienes que ejecutar `terraform init` ni `apply`.** El validador solo comprueba que los archivos existen, que son texto, y que contienen los campos requeridos literalmente. Si tienes `terraform` instalado puedes usar `terraform fmt` para dejar el estilo canonico, pero no es obligatorio.

> **IDs ficticios obligatorios**: cualquier `tenant_id`, `subscription_id`, `client_id` que aparezca debe ser `00000000-0000-0000-0000-000000000000` o similar placeholder. **No** pegues IDs reales.

### 5.4 Escribe el workflow GHA

Un archivo:

```
/tmp/az-10-01/.github/workflows/build-sign-push.yml
```

Debe contener:

- `permissions:` con `id-token: write`.
- `uses: azure/login@...` (cualquier version).
- Las tres `vars` o similares para `client-id`, `tenant-id`, `subscription-id`.
- **No** debe contener `client-secret` ni `AZURE_CREDENTIALS` (si aparecen, el validador falla — el objetivo es un pipeline sin secretos).

### 5.5 Entregable

```
/tmp/az-10-01/
├── ADR-DEVSECOPS-SUPPLY-CHAIN.md
├── terraform/
│   ├── main.tf
│   ├── oidc.tf
│   ├── acr.tf
│   └── defender.tf
└── .github/
    └── workflows/
        └── build-sign-push.yml
```

## 6. Resultado esperado

- `ADR-DEVSECOPS-SUPPLY-CHAIN.md` existe y pasa las comprobaciones estructurales.
- Los 4 archivos `.tf` existen y contienen los campos requeridos.
- El workflow YAML existe, usa OIDC y **no** contiene secretos de autenticacion Azure.
- `bash tests/validate.sh /tmp/az-10-01` termina con `OK:` y exit 0.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural en verde.
- **Correctitud**: `terraform fmt` acepta los archivos (comprueba a mano si quieres; el validador no corre `terraform` por diseno — asume cero deps).
- **Reproducibilidad**: alguien en Fase 4 podria sustituir los IDs placeholder por reales, correr `terraform init && apply` y obtener la infra.
- **Mantenibilidad**: Markdown y HCL legibles, nombres consistentes.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/az-10-01
```

El validador comprueba **estructura y presencia de campos literales**, no semantica. Compara con `solution/REFERENCE.md` para autoevaluarte conceptualmente.

## 9. Preguntas de reflexion

1. ¿Por que el `client-id` de la app registration **no es un secreto** y puede ir en `vars`?
2. ¿Que pasa si tu federated credential pinnea `refs/heads/main` y alguien renombra `main` a `trunk`?
3. ¿Por que ACR Premium en `checkout-prod` y Standard en `checkout-dev` es un buen trade-off?
4. ¿Que capturarias con Defender for Containers que NO capturarias con Trivy en el pipeline?
5. En una org con 5 workloads y 3 environments cada uno (15 app registrations), ¿como escalas la gestion de federated credentials sin que explote?

## 10. Extensiones

- Anade un segundo federated credential al mismo app registration para el environment `stg`.
- Escribe `locals.tf` con `locals { allowed_subjects = [...] }` y un `for_each` para generar varios federated_credentials.
- Anade `azurerm_private_endpoint` para que ACR Premium quede sin exposicion publica (plan-only).

## 11. Limpieza

```bash
rm -rf /tmp/az-10-01
```

No hay recursos cloud que borrar — no se provisiono nada.
