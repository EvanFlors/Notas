# gcp-01 — Modelo de projects, billing y `gcloud`

## Identificacion

- **ID:** `gcp-01-model-projects-billing-and-cli`
- **Curso:** `gcp`
- **Nivel:** fundamentos
- **Duracion estimada:** 3 h
- **Prerrequisitos:** `aws-01` (modelo global, billing), `aws-02` (IAM core). Se asume conocimiento equivalente del lado AWS; aqui se practica **transferencia + divergencias**.

## Objetivo

Interiorizar la jerarquia **Organization -> Folders -> Projects -> Resources** de GCP, el modelo de **Billing Accounts separadas** que se enlazan a projects, y manejarse con `gcloud` desde el primer dia (configurations, auth, ADC). Al terminar deberias poder bootstrapear un **project nuevo seguro** (APIs minimas habilitadas, budget con alerta, MFA en las identidades) y entender por que un project es la unidad correcta de aislamiento "una app x un entorno".

## Alcance

Este modulo cubre:

- **Resource hierarchy**: Organization (uno por dominio) -> Folders (agrupadores) -> Projects (unidad de aislamiento) -> Resources. Equivalencias y divergencias contra AWS Organizations/OUs/Accounts.
- **Project** como unidad **barata** de aislamiento: cuotas propias, IAM propia, set de APIs habilitadas propio, enlazado a **una** Billing Account.
- **Billing Account**: entidad separada del project. Una BA puede pagar por N projects; un project solo puede estar enlazado a una BA activa.
- **APIs habilitadas por project**: `gcloud services enable`. Modelo intencional (reduce *blast radius*, controla cuotas).
- **`gcloud` CLI**: `configurations` (perfiles con project+region+zone+account), `properties`, componentes.
- **Autenticacion**: `gcloud auth login` (identidad del usuario para `gcloud`) vs `gcloud auth application-default login` (**ADC** — credenciales que leen las libraries cliente). Patron recomendado: **impersonation** de service accounts en lugar de keys.
- **Labels** como mecanismo de **cost allocation** (y de agrupacion operativa). Equivalente conceptual de AWS tags.
- **Budgets + alertas** como primer control obligatorio al abrir un project nuevo.
- **Divergencias con AWS**: scope de los recursos (global/regional/zonal); nombres **globales** en algunos servicios (buckets GCS); no hay regions como "cuentas de proveedor"; una **account AWS ~= un project GCP** para la mayoria de los razonamientos.

Lo que **no** cubre (se vera despues):

- IAM detallado (bindings, roles, deny policies, service accounts) -> `gcp-02`.
- VPC y red -> `gcp-03`.
- Multi-project + Cloud Identity + org policies -> `gcp-09`.

Este modulo es **mayoritariamente conceptual + planificacion escrita + linting local**. **No** se provisiona nada en GCP real. Las dos actividades producen artefactos de texto (plan Markdown + script shell + YAML de budget) validados estructuralmente. El unico *tooling* es `bash`, `jq`, `python3`, un editor y, opcionalmente, `gcloud` instalado en modo *dry-run* (`--help`, `--format`, nunca `--project <real>`).

## Materiales

- **`theory/lesson.md`** — leccion profunda (12 secciones).
- **`examples/`** — ejemplos demostrativos (lectura y analisis, sin ejecucion contra GCP real):
  - `01-gcloud-configurations/` — como usar `gcloud config configurations` para alternar entre contextos (project/region/account) sin pisar variables de entorno.
  - `02-adc-vs-user-auth/` — diferencia entre `gcloud auth login` (user) y `gcloud auth application-default login` (ADC); por que las SDKs leen ADC y no la identidad del CLI.
  - `03-budget-with-notification/` — anatomia de un **Budget** en Cloud Billing: amount, threshold rules, notification channel (Pub/Sub o email).
- **`activities/`** — dos actividades **independientes**:
  - `01-bootstrap-safe-project/` — escribir un **plan de bootstrap** (Markdown) + `enable-apis.sh` + `budget.yaml` para abrir un project de forma segura. Todo en papel; placeholder `my-project-123`.
  - `02-adc-from-local-dev/` — escribir un **plan ADC** (Markdown) + `verify-adc.sh` que explica como un developer configura ADC con **impersonation** (sin keys) para que las libraries cliente autentiquen desde su maquina.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar la jerarquia Org/Folder/Project/Resource; por que un project es la unidad de "una app x un entorno"; diferencia user auth vs ADC; mapping AWS account <-> GCP project. |
| Operativa (sin infra) | Diseñar el plan de bootstrap de un project seguro; escribir el `gcloud services enable` minimo; definir un budget YAML con alertas; configurar ADC via impersonation en papel. |
| Arquitectonica | Decidir cuando partir una app en N projects (por entorno) vs uno solo; justificar labels obligatorios desde el dia uno; justificar por que las keys de service accounts se evitan. |

## Criterios de evaluacion

- Dado un escenario (app nueva, 2 entornos), nombrar los projects, la Billing Account y las APIs minimas.
- Explicar la diferencia practica entre `gcloud auth login` y `gcloud auth application-default login` y cuando cada una.
- Leer un `budget.yaml` y predecir que alertas disparara.
- Nombrar al menos 3 **labels** obligatorios y por que (cost allocation, env, owner).
- Entregar las dos actividades con sus validadores en verde.

## Entregables

- **`bootstrap-plan.md`** + **`enable-apis.sh`** + **`budget.yaml`** (actividad `01`).
- **`adc-plan.md`** + **`verify-adc.sh`** (actividad `02`).

## Costos

**Ninguno.** Todo el modulo se desarrolla **localmente** contra archivos de texto. **No se crea ningun project real** ni se enlaza ninguna Billing Account real. Si en Fase 4 decides provisionar lo diseñado:

- **Crear un project**: gratis.
- **Enlazar a una Billing Account**: gratis.
- **Habilitar APIs**: gratis per se; pero los **recursos** que crees despues cobran segun uso.
- **Budget + notifications**: gratis.
- **gcloud CLI** y **ADC**: gratis.

**Regla de oro de este modulo**: cualquier comando `gcloud` que aparezca debe ejecutarse en modo *dry-run* (con `--help`, `--format`, `--log-http`) o contra un project placeholder (`my-project-123`) que **no existe**. No crear projects reales desde esta actividad: eso se hace en Fase 4 con governance aplicada.

## Siguiente modulo

-> `gcp-02-iam-bindings-deny-policies-and-service-accounts` — IAM en GCP: bindings role->member, roles predefinidos/custom, deny policies, service accounts e impersonation.
