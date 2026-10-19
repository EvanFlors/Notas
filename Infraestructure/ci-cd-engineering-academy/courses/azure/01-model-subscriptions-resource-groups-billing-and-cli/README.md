# az-01 — Modelo Azure: Subscriptions, Resource Groups, Billing y CLI

## Identificación

- **ID:** `az-01-model-subscriptions-resource-groups-billing-and-cli`
- **Curso:** `azure`
- **Nivel:** fundamentos (beginner)
- **Duración estimada:** 3 h
- **Prerrequisitos:** curso **aws** ≥ `aws-01` (modelo global y billing), `aws-02` (IAM core). Útil haber hecho `aws-15` para contrastar OUs/SCPs con MGs/Policy.

## Objetivo

Interiorizar la jerarquía **Tenant → Management Group → Subscription → Resource Group → Resource**, entender por qué el **Resource Group (RG)** es el *nivel extra* respecto a AWS (unidad de deploy y de eliminación en cascada), y manejar la **`az` CLI** operativa (login, defaults, resource providers). Al terminar deberías poder diseñar — en papel — una subscription playground con RG, budget con alerta y perfil CLI listo para trabajar, sin tocar una suscripción real y sin generar un USD de coste.

## Alcance

Este módulo cubre:

- **Jerarquía Azure completa**: Tenant (Entra ID) → Management Group → Subscription → Resource Group → Resource. Qué significa cada nivel y qué se controla desde cada uno.
- **Resource Group** como *unidad lógica* de gestión y de **eliminación en cascada** (`az group delete --yes --no-wait` borra todo lo que vive dentro).
- **Subscription types**: Pay-as-you-go, Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), CSP, Dev/Test, Free. Cuándo elegir cada uno.
- **Billing separado de identidad**: una Billing Account puede pagar N subscriptions; el tenant de Entra ID no es la billing account.
- **Resource providers** (`Microsoft.ContainerService`, `Microsoft.KeyVault`, etc.) y por qué se habilitan por subscription.
- **`az` CLI** operativa: `az login`, `az account show`, `az account set`, `az config set defaults=group=... location=...`, `az provider register`.
- **`azd`** (Azure Developer CLI) para quickstarts por templates.
- **Nombres globalmente únicos**: Storage Account, Key Vault, FQDNs de App Service.
- **Budgets** con alertas (primer paso FinOps).
- **Diferencias con AWS**: tags por recurso **y** por RG (ambos útiles); el RG es un nivel que AWS no tiene.

Lo que **no** cubre (se verá en módulos posteriores):

- Identidad y RBAC fino → `az-02`.
- VNets, NSGs y Private Endpoints → `az-03`.
- Management Groups jerárquicos + Azure Policy baseline + Landing Zone → `az-09`.
- Terraform operativo (`azurerm`) sobre esta base — se referencia conceptualmente; el lab Terraform es parte de la Fase 4 del programa.

Este módulo es **mayoritariamente conceptual + ADR + validación estructural**. **No** se provisiona nada en una subscription real. Las dos actividades son análisis escritos y archivos JSON/Markdown validados estructuralmente; el único *tooling* es `bash`, `jq`, `python3` y, opcionalmente, la `az` CLI usada en modo **dry-run / `--help` / `what-if`** (nunca contra un tenant real).

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución real):
  - `01-az-login-and-defaults/` — ciclo típico de `az login`, selección de subscription, defaults de CLI.
  - `02-rg-delete-cascades/` — cómo `az group delete` borra todo lo contenido, y por qué el RG es el pivote de limpieza de entornos.
  - `03-budget-with-notifications/` — anatomía de un Budget con alertas por email/action group.
- **`activities/`** — dos actividades **independientes** entre sí:
  - `01-bootstrap-safe-subscription/` — escribir un ADR de *bootstrap* de subscription playground + guion `az` CLI anotado (dry-run).
  - `02-tagging-rg-vs-resource/` — definir estrategia de tags (RG vs recurso) + Azure Policy sketch que exige tags obligatorios.
- **`resources/links.md`** — referencias oficiales y lecturas de apoyo.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la jerarquía Tenant → MG → Sub → RG → Resource y por qué el RG es un nivel que AWS no tiene; distinguir billing account de tenant; explicar por qué los resource providers se habilitan por subscription. |
| Operativa (sin infra) | Diseñar la configuración de una subscription playground con RG + budget + CLI defaults, usando placeholders GUID; preparar un script `az` que un operador pueda revisar antes de ejecutar. |
| Arquitectónica | Elegir subscription type para un escenario (startup, enterprise, dev/test); decidir granularidad RG = un ambiente de un workload; mapear tags al nivel correcto (RG vs recurso). |

## Criterios de evaluación

- Dado un diagrama de jerarquía, identificar qué controla cada nivel (quién paga, quién gobierna, quién borra).
- Justificar por qué `az group delete` es la vía estándar para limpiar un entorno dev.
- Nombrar al menos 3 **resource providers** y explicar por qué se habilitan por subscription.
- Entregar las dos actividades con sus validadores estructurales en verde.
- Justificar "un RG = un ambiente de un workload".

## Entregables

- **ADR** `ADR-SUBSCRIPTION-BOOTSTRAP.md` + script `bootstrap.sh` (dry-run) — actividad `01`.
- Dos JSON de tags (`tags-rg.json`, `tags-resource.json`), un `tag-policy.json` (Azure Policy sketch) y un `README-INTENT.md` — actividad `02`.

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, JSON y comandos `az` ejecutados en modo `--help` / `what-if` / dry-run. **No** se requiere una subscription Azure activa. Si en Fase 4 decides materializar lo diseñado:

- **Subscription Free / Dev-Test**: viene con créditos iniciales.
- **Resource Groups, Management Groups, tags, resource providers**: gratis.
- **Budgets**: gratis.
- Los recursos que *despliegues* dentro de un RG (VM, Storage, Key Vault…) sí cobran — pero este módulo **no despliega** nada.

## Siguiente módulo

→ `az-02-entra-id-rbac-managed-identities` — identidad y autorización en Azure: Entra ID, Azure RBAC, Managed Identities.
