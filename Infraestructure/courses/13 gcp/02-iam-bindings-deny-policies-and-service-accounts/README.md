# gcp-02 — IAM: bindings, deny policies y service accounts

## Identificación

- **ID:** `gcp-02-iam-bindings-deny-policies-and-service-accounts`
- **Curso:** `gcp`
- **Nivel:** fundamentos
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gcp-01` (modelo, projects, billing, CLI), curso **aws** ≥ `aws-02`, `aws-06`.

## Objetivo

Dominar el modelo IAM de GCP: **allow policies** compuestas por **bindings `(role, members)`** adjuntas a recursos; **roles predefinidos** vs custom (y por qué los `basic` están prácticamente deprecados); **deny policies** como veto por principal; **org policies** como constraints a nivel de jerarquía; **service accounts** como principals y, sobre todo, por qué **no se emiten keys** para ellas — se **impersona** o se federa (WIF, cubierto en `gcp-10`).

Al terminar deberías poder **traducir** una policy IAM de AWS a bindings GCP equivalentes, elegir el role predefinido de menor privilegio para un caso dado, escribir una **deny policy** que vete una acción incluso si existe un allow, y describir el flujo de impersonation desde `gcloud` sin tocar una clave estática.

## Alcance

Este módulo cubre:

- **Modelo IAM GCP**: allow policy = conjunto de bindings `(role, members, condition?)` adjunto a un *resource* (organization, folder, project, resource individual). Herencia por la jerarquía Resource Manager.
- **Roles**: `basic` (Owner/Editor/Viewer — deprecados en la práctica para producción), **predefined** (`roles/storage.objectViewer`, `roles/run.invoker`, etc.), **custom** (YAML/JSON con `includedPermissions`).
- **Principals / members**: `user:`, `group:` (Google Group — patrón recomendado), `serviceAccount:`, `domain:`, `principalSet://` (para WIF).
- **IAM Deny Policies** (API `policies.googleapis.com`, relativamente moderna): vetan `deniedPrincipals` sobre `deniedPermissions`, con `exceptionPrincipals` y condiciones. Un **deny gana al allow** aunque haya bindings positivos.
- **Org Policies**: constraints declarativos aplicados a Org/Folder/Project. Los imprescindibles del baseline: `iam.disableServiceAccountKeyCreation`, `iam.automaticIamGrantsForDefaultServiceAccounts`, `compute.vmExternalIpAccess`, `storage.publicAccessPrevention`.
- **Service Accounts**: identidad para workloads. Dos modos de uso:
  - **Attached SA** (correcto): el workload corre "como" la SA (Cloud Run, GCE, GKE con Workload Identity).
  - **Impersonation** (correcto): un humano o SA fuente obtiene un token efímero de la SA destino via `roles/iam.serviceAccountTokenCreator`.
  - **SA keys** (anti-patrón): JSON de 2048 bits sin expiración, equivalentes a una credencial de larga duración. Se documentan aquí **solo** para entender por qué se bloquean con org policy.
- **Condiciones IAM**: `request.time`, `resource.name.startsWith(...)`, útiles para scoping temporal o por prefijo de recurso.

Lo que **no** cubre (se verá después):

- **Workload Identity Federation** (OIDC desde GitHub Actions / cualquier IdP a GCP sin keys) → `gcp-10`.
- **Workload Identity** (ServiceAccount K8s ↔ Google SA) para GKE → `gcp-07`.
- Baseline org-wide completo con folders + Cloud Identity → `gcp-09`.

Este módulo es **mayoritariamente conceptual + diseño + validación estructural de YAML**. **No se provisiona nada** en un project GCP real. Las dos actividades son análisis escritos y archivos YAML validados con `python3` y `bash`. **Coste real GCP: 0 USD.**

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (modelo, bindings, deny policies, SA, impersonation, org policies, condiciones, traducción desde AWS).
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-binding-vs-aws-policy/` — misma intención ("S3 bucket read-only para un equipo") en AWS (policy JSON adjunta al rol) vs GCP (binding en el bucket). Fija el cambio de locus.
  - `02-group-based-binding/` — por qué `group:platform-eng@acme.io` en lugar de `user:alice@acme.io`. Rotación de personas sin tocar policies.
  - `03-deny-policy-example/` — anatomía YAML de una deny policy que veta `storage.buckets.delete` para todos excepto un break-glass group.
  - `04-org-policy-disable-sa-keys/` — constraint `iam.disableServiceAccountKeyCreation` aplicado a un folder, por qué es el **primer** control defensivo y qué rompe (y qué no).
- **`activities/`** — dos actividades **independientes**:
  - `01-least-privilege-with-predefined-role/` — para un workload concreto, elegir el role predefinido de menor privilegio, escribir el binding YAML y una deny policy complementaria. Validar estructuralmente con `python3`.
  - `02-impersonate-service-account-from-cli/` — diseñar el flujo de impersonation de un humano hacia una SA de deployment, documentar los comandos `gcloud`, el binding `roles/iam.serviceAccountTokenCreator` y un walkthrough **explícito** sobre por qué **no** se emite una SA key. Walkthrough-only — ningún comando se ejecuta contra GCP.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre allow policy (bindings en el recurso) y una policy AWS (adjunta al principal); cómo una deny policy gana al allow; por qué una SA key es un anti-patrón. |
| Operativa (sin infra) | Elegir el role predefinido de menor privilegio para 3 casos; escribir un binding YAML y una deny policy sintácticamente válidos; documentar el flujo de impersonation con los `gcloud` necesarios. |
| Arquitectónica | Traducir una policy IAM AWS a bindings GCP; justificar `group:` vs `user:`; mapear qué controles van en org policy vs IAM policy vs deny policy. |

## Criterios de evaluación

- Dado un escenario, elige el role predefinido correcto y justifica por qué no uno `basic`.
- Lee una deny policy YAML y explica qué veta, a quién, y qué excepción tiene.
- Explica por qué un `Allow` en un binding **no** evade un deny policy que te menciona.
- Nombra tres org policies defensivas del baseline y qué protegen.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Binding YAML + deny policy YAML** mínimos y justificados en `README-INTENT.md` (actividad 01).
- **Walkthrough de impersonation** `IMPERSONATION-WALKTHROUGH.md` con comandos `gcloud`, binding `token-creator-binding.yaml` y sección explícita "por qué no SA key" (actividad 02).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto y YAML. No se requiere project GCP activo. Si en una fase posterior aplicas lo diseñado:

- **IAM bindings, deny policies, org policies**: gratis (son parte de Resource Manager).
- **Service accounts**: gratis.
- **Impersonation (`sts.googleapis.com`, `iamcredentials.googleapis.com`)**: gratis en el volumen propio de operaciones humanas.
- Solo lo que *protejas* con estos controles (buckets, Cloud Run, etc.) puede costar — y lo introduciremos en módulos posteriores.

## Siguiente módulo

→ `gcp-03-vpc-global-and-networking` — VPC global, firewall rules por SA, Shared VPC, Cloud Load Balancing.
