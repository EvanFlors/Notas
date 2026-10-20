# az-04 — Compute en Azure: VM, VMSS, App Service, Container Apps y Functions

## Identificacion

- **ID:** `az-04-compute-vm-vmss-container-apps-functions-app-service`
- **Curso:** `azure`
- **Nivel:** intermedio
- **Duracion estimada:** 5 h
- **Prerrequisitos:** `az-01` (modelo/suscripciones/RGs), `az-02` (Entra ID + RBAC + Managed Identities), `az-03` (VNet/NSG/Private Endpoints), curso **aws** `aws-04`/`aws-10`/`aws-14`, curso **docker**.

## Objetivo

Decidir con criterio el **compute correcto** para cada workload en Azure y, en particular, aprovechar **Azure Container Apps** como "serverless Kubernetes abstracto" con `scale-to-zero`, `revisions` y `traffic split` nativo. Al terminar deberias poder justificar por que un capstone HTTP vive en Container Apps y no en App Service, por que una job batch vive en Container Instances o Functions, y por que una VM sigue siendo la respuesta correcta para una carga legacy stateful.

## Alcance

Este modulo cubre:

- **Virtual Machines (VM)** y **Virtual Machine Scale Sets (VMSS)**: imagen gold, autoscaling por metrica, **Spot VMs**, **Trusted Launch**, acceso sin claves locales via **Azure Bastion** o **Azure AD login for VMs**.
- **App Service**: plan PaaS clasico para web/API, planes `B/P/I` con escaling, deployment slots con swap.
- **Azure Container Apps**: `ingress` HTTP/TCP, `revisions` activas o `single revision mode`, **traffic split** por porcentaje para canary, `scale rules` (HTTP concurrency, KEDA scalers), **Dapr** sidecar opcional, `min_replicas = 0` para scale-to-zero.
- **Container Instances (ACI)**: contenedor unico de corta duracion, util para batch o para burst desde AKS (virtual nodes).
- **Azure Functions**: triggers HTTP/Queue/Timer/EventGrid; planes Consumption, Premium y **Flex Consumption** (moderno).
- **Mapping AWS -> Azure**: `EC2 <-> VM`, `ECS/Fargate <-> Container Apps`, `Lambda <-> Functions`, `App Runner <-> App Service o Container Apps`.

Lo que **no** cubre (otros modulos):

- **AKS** completo con Workload Identity y add-ons -> `az-07`.
- Observabilidad con App Insights y Log Analytics -> `az-08`.
- OIDC Federation GitHub Actions -> Entra ID y firma de imagenes en ACR -> `az-10`.

Este modulo es mayoritariamente **conceptual + Terraform plan + Dockerfile buildable localmente + ADR**. **No** se provisiona nada en una suscripcion real. El unico *tooling* requerido es `bash`, `docker`, `terraform` (>= 1.5) y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — leccion profunda sobre el catalogo de compute, cuando elegir cada uno y los *fundamentos internos* (como corre Container Apps sobre AKS gestionado, como funciona el traffic split con revisions, por que Flex Consumption desplaza a Consumption clasico).
- **`examples/`** — ejemplos demostrativos (lectura y analisis, no ejecucion contra cloud):
  - `01-fastapi-on-container-apps/` — un `main.tf` minimo para desplegar una API FastAPI en Container Apps con ingress externo e identidad gestionada.
  - `02-canary-with-revisions/` — dos revisiones del mismo Container App con `traffic_weight` 90/10 y comando para promover.
  - `03-vm-with-aad-login/` — VM Linux con extension **AADSSHLoginForLinux** y Bastion, para login sin claves SSH locales.
- **`activities/`** — dos actividades **independientes** entre si:
  - `01-choose-compute-and-adr/` — leer tres workloads reales y escribir un **ADR** justificando la eleccion de compute para cada uno, con tabla comparativa VM / VMSS / App Service / Container Apps / Functions / ACI.
  - `02-build-and-plan-container-apps-canary/` — construir un **Dockerfile buildable localmente**, escribir un **modulo Terraform** para Container Apps con **traffic split** canary 90/10 y validar con `terraform validate` + `terraform plan` (sin cloud) + `docker build`.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre Container Apps y AKS; cuando una Function es mejor que un Container App; por que una VM sigue justificada; que es Dapr y por que lo integra Container Apps. |
| Operativa (sin cloud) | Escribir un `main.tf` con `azurerm_container_app` y dos revisiones con `traffic_weight`; construir un Dockerfile multistage para FastAPI; correr `terraform plan` offline. |
| Arquitectonica | Elegir compute para un workload dado defendiendo trade-offs cost / cold-start / portabilidad / operabilidad; disenar un canary 5%->50%->100% con rollback. |

## Criterios de evaluacion

- Dado un workload (HTTP sincronico, batch cada hora, worker a cola, VM legacy), nombrar el compute correcto y defenderlo en una frase.
- Leer un `azurerm_container_app` con dos revisiones y explicar que porcentaje de trafico va a cada una y como se promociona a 100%.
- Justificar por que `min_replicas = 0` **no** aplica a workloads latency-sensitive sin warmup.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `ADR-COMPUTE-CHOICE.md` eligiendo compute para 3 workloads (sale de la actividad `01`).
- **Dockerfile** buildable localmente + **modulo Terraform** valido (`terraform validate` OK, `terraform plan -refresh=false` ejecuta un plan "ficticio") con dos revisiones y canary 90/10 (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el modulo se desarrolla localmente:

- `terraform init -backend=false` + `terraform validate` + `terraform plan` **sin cloud** (el provider `azurerm` carga pero no autentica; el plan falla al final por falta de credenciales, lo cual es esperado y el validador lo tolera — ver `activities/02-.../tests/validate.sh`).
- `docker build` local.
- Markdown + bash.

Si en una fase posterior aplicas el Terraform contra una suscripcion real:

- **Container Apps** con `min_replicas = 0` paga **solo por request** (consumption profile). En reposo ~0 USD.
- **App Service** plan B1 ~13 USD/mes constantes.
- **VM B1s** ~8 USD/mes constantes (apagada no cobra compute pero el disco si).
- **Functions Consumption** paga por invocacion + GB-s, free tier mensual generoso.

## Siguiente modulo

-> `az-05-data-sql-postgres-cosmos-storage` — catalogo de datos Azure y mapping desde AWS.
