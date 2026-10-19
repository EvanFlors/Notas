# gcp-01 — Leccion: projects, billing y `gcloud`

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `aws-01`, `aws-02`.

---

## 1. Por que una jerarquia explicita y no "una cuenta grande"

En AWS la unidad de aislamiento duro es la **cuenta**. En GCP la unidad de aislamiento duro es el **project**. Son conceptos equivalentes en 80% de los razonamientos de arquitectura: un project es gratis de crear, tiene su propio IAM, su propio set de cuotas, su propio set de APIs habilitadas y se enlaza a **una** Billing Account.

La diferencia esencial contra AWS: GCP ofrece **ademas** una jerarquia **arriba** del project (Organization -> Folders -> Projects) desde el dia uno, sin servicios opcionales equivalentes a Control Tower. Esta jerarquia es el soporte sobre el que luego cuelgan **IAM bindings** (que heredan hacia abajo) y **Org Policies** (constraints, no acciones).

> **Idea clave que repetiremos:** el project es el limite de aislamiento. La jerarquia (Org/Folder) es el soporte para herencia de politicas. La Billing Account es una entidad separada que se **enlaza** a projects — no vive dentro de ellos.

---

## 2. Resource hierarchy: Organization, Folders, Projects, Resources

```
                 ┌──────────────────────────────────┐
                 │   Organization (acme.io)         │   un dominio -> una Org
                 │   root de la jerarquia           │
                 └────────────────┬─────────────────┘
                                  │
                 ┌────────────────┼────────────────┐
                 ▼                ▼                ▼
             ┌───────┐        ┌───────┐        ┌───────┐
             │ Folder│        │ Folder│        │ Folder│
             │  prod │        │  dev  │        │shared │
             └───┬───┘        └───┬───┘        └───┬───┘
                 │                │                │
                 ▼                ▼                ▼
          ┌──────────────┐ ┌──────────────┐ ┌───────────────┐
          │ Project      │ │ Project      │ │ Project       │
          │ checkout-prod│ │ checkout-dev │ │ shared-net    │
          └──────┬───────┘ └──────┬───────┘ └──────┬────────┘
                 │                │                │
                 ▼                ▼                ▼
              Recursos        Recursos         Recursos
              (buckets,       (Cloud Run,      (Shared VPC,
               Cloud SQL,      Firestore,       DNS zones,
               VPC)            Secrets)         Artifact Reg)
```

Conceptos:

- **Organization**: nodo raiz. **Una por dominio DNS** (p. ej. `acme.io`). Se crea al enlazar Cloud Identity o Google Workspace. Los IAM bindings aplicados aqui aplican a **todo** lo que cuelgue.
- **Folder**: agrupador logico. Patrones habituales: `prod/`, `dev/`, `shared/`, `sandbox/`. Soporta anidamiento. Las **Org Policies** y los **IAM bindings** se adjuntan a folders y heredan.
- **Project**: la **unidad de aislamiento** real. Tiene:
  - `projectId` (string unico global, inmutable; ej. `acme-checkout-prod-7a3f`).
  - `projectNumber` (numero unico global, inmutable, generado por GCP).
  - `displayName` (humano, cambiable).
  - IAM propia (bindings sobre el propio project y recursos que contiene).
  - Set de **APIs habilitadas** propio.
  - Cuotas propias (CPUs por region, buckets, etc.).
  - **Una** Billing Account enlazada activa.
- **Resource**: un bucket, una VM, una Cloud Function, etc. Vive **dentro de** un project.

> **Trampa habitual**: pensar que puedes "mover" un project debajo de otro folder y perder politicas. En realidad puedes mover projects entre folders (es una operacion de `gcloud projects move`), pero las politicas heredadas **cambian** al nuevo path. No hay reparent "transparente".

---

## 3. Mapping conceptual AWS <-> GCP

| AWS | GCP | Nota |
|-----|-----|------|
| Organization | Organization | Equivalente directo. |
| OU | Folder | Mismo rol (herencia de politicas). |
| Account | **Project** | 80% del tiempo es asi. El `projectId` juega el rol del `accountId`. |
| IAM Role (identity policy) | IAM Role (predefined/custom) + Binding | GCP separa el *rol* (set de permisos) del *binding* (role -> members en un recurso). |
| SCP (deny) | **IAM Deny Policy** + **Org Policy constraints** | Dos mecanismos distintos (ver `gcp-02`). |
| Service Control Policy (allow-list region) | **Org Policy `gcp.resourceLocations`** | GCP usa constraints declarativos. |
| Tags | **Labels** (operativo) y **Tags** (IAM-aware) | GCP tiene *labels* para FinOps y *tags* para IAM — distintos conceptos con nombres confusos. |
| Billing: la cuenta paga | **Billing Account separada** enlazada al project | **Diferencia material**: en GCP una BA paga por N projects; cambiar el pagador no requiere mover el project. |
| Enable services (implicito) | **APIs habilitadas por project** (explicito) | **Diferencia material**: en GCP debes habilitar explicitamente `compute.googleapis.com`, `run.googleapis.com`, etc. Primera vez por project. |

Dos divergencias que **conviene fijar**:

1. **Billing esta separada**. Una Billing Account es una entidad propia (`billingAccounts/01A2B3-456789-CDEF01`). Puede pagar por 1 o por 500 projects. Esto permite patrones como "una BA para toda la empresa" o "una BA por BU", desacoplados de la estructura de projects.
2. **APIs son opt-in explicito**. Cuando creas un project, el set de APIs habilitadas es minimo (Service Usage, Cloud Resource Manager, Billing). Para crear una VM necesitas antes `gcloud services enable compute.googleapis.com`. Esto es intencional: reduce el *blast radius* (una API que no esta habilitada no puede ser llamada) y controla cuotas (cada API tiene sus propios limites).

---

## 4. El Project como unidad de "una app x un entorno"

La pregunta de arranque: **¿cuantos projects necesito para mi aplicacion?** Respuesta por defecto en GCP: **uno por aplicacion por entorno**. Patron tipico:

```
Folder: prod/
├── checkout-prod       (project de la app checkout en prod)
├── analytics-prod
└── shared-net-prod     (project con la Shared VPC)

Folder: dev/
├── checkout-dev
├── analytics-dev
└── shared-net-dev

Folder: shared/
└── artifact-registry   (project de registry comun)
```

Por que uno por app por entorno:

- **Blast radius**: un `terraform destroy` equivocado en `checkout-dev` no toca `checkout-prod`.
- **IAM y cuotas aisladas**: `dev` y `prod` tienen sets de bindings distintos; un developer que puede todo en `dev` no puede nada (o solo leer) en `prod`.
- **Billing claro**: el project es la unidad natural de agrupacion en Cloud Billing export. Un project = una linea en el dashboard.
- **APIs independientes**: si una API experimental se habilita en `dev`, no entra automaticamente en `prod`.

Contrapunto (cuando **no** partirlo):

- App interna muy pequeña, con 1 persona, sin SLA: puede vivir en un project unico con `labels env=dev|prod` sobre los recursos. Pierdes aislamiento duro; ganas simplicidad.
- Spike experimental de 1 dia: puede vivir en un `sandbox-<user>` compartido.

> **Regla practica**: si la app tiene SLA, datos regulados o mas de 2 ingenieros, al menos **2 projects** (dev + prod). Stg es opcional segun madurez.

---

## 5. Billing Accounts: la cosa que paga

Una **Billing Account** (BA) es una entidad administrativa de pago. Caracteristicas:

- Tiene su propio `billingAccountId` (`XXXXXX-XXXXXX-XXXXXX`).
- Tiene **payment profile** asociado (tarjeta, invoice, orden de compra).
- Tiene su propio IAM (roles como `roles/billing.admin`, `roles/billing.user`, `roles/billing.viewer`).
- Se **enlaza** a projects via `gcloud billing projects link <PROJECT> --billing-account=<BA>`.
- Un project solo puede tener **una** BA enlazada activa. Si la desenlaza, el project queda **suspendido** (recursos existentes dejan de responder al poco tiempo).

Dos tipos:

- **Self-serve**: pago con tarjeta de credito, factura mensual automatica. Fit para startups y pymes.
- **Invoice billing**: factura corporativa, PO, terminos de pago >30 dias. Requiere elegibilidad y aprobacion comercial.

Patrones:

- **Una BA para toda la empresa**: lo mas simple; billing export unico a BigQuery; FinOps agregado por project/label.
- **Una BA por BU/cliente**: cuando se cobran costos a clientes distintos o cuando hay compliance de separacion contable.
- **Una BA de sandbox** separada: para capar riesgo de que un experimento rogue destruya el presupuesto comun.

> **Trampa comun**: dejar la **first-created** BA (la que el fundador abrio con su tarjeta) como pagadora de la Org entera. Un dia esa persona se va, la tarjeta expira y la factura **de todo** empieza a fallar. En Fase 4 (`gcp-09`) se promueve una BA corporativa separada con `roles/billing.admin` a un grupo, no a una persona.

---

## 6. APIs habilitadas por project

En GCP, **nada esta habilitado por defecto** salvo lo minimo (Resource Manager, Service Usage, Cloud Billing). Para usar un servicio en un project, hay que habilitarlo:

```bash
# dry-run: enumerar las APIs que vamos a habilitar sin hacerlo
gcloud services list --available --filter="name:compute" --format="value(config.name)"

# habilitacion real (NO ejecutar contra un project real sin governance)
gcloud services enable compute.googleapis.com --project=my-project-123
```

APIs minimas tipicas para un project nuevo serio:

| API | Para que |
|-----|----------|
| `cloudresourcemanager.googleapis.com` | ya habilitada por defecto; gestiona projects/folders. |
| `iam.googleapis.com` | gestionar service accounts, roles custom. |
| `cloudbilling.googleapis.com` | enlazar a BA, leer billing info. |
| `serviceusage.googleapis.com` | habilitar/deshabilitar otras APIs. |
| `logging.googleapis.com` | enviar logs a Cloud Logging. |
| `monitoring.googleapis.com` | enviar metricas y SLOs. |
| `compute.googleapis.com` | solo si vas a usar GCE / VPC / LB (es la que trae *toda* la red). |
| `run.googleapis.com` | para Cloud Run. |
| `storage.googleapis.com` | para buckets GCS. |

Por que es **intencional** y no una molestia:

1. **Blast radius**: si `aiplatform.googleapis.com` no esta habilitada, un atacante con un binding permisivo no puede llamar a Vertex AI (y acumular factura).
2. **Cuotas**: cada API tiene sus propias cuotas; habilitarlas una por una fuerza a pensar en limites antes de usarlas.
3. **Audit**: `gcloud services list --enabled` es un inventario explicito de superficie.
4. **Billing**: habilitar una API no cobra; **usarla** si. Pero no hay forma de "usar accidentalmente" lo no habilitado.

> **Regla operativa**: en Fase 4, cada project se bootstrapea con Terraform y el set minimo de APIs es parte del modulo de bootstrap. Nadie habilita APIs a mano "porque hace falta ahora" en prod.

---

## 7. `gcloud` CLI: configurations, properties, componentes

`gcloud` es la CLI oficial de GCP. Tres mecanismos para gestionar contexto:

### 7.1 Configurations

Un **configuration** es un perfil con nombre que agrupa `project`, `account`, `region`, `zone` y otras propiedades. Vive en `~/.config/gcloud/configurations/`. Permite alternar entre contextos sin tocar variables de entorno.

```bash
# Listar
gcloud config configurations list

# Crear nuevo config para dev
gcloud config configurations create dev
gcloud config set project my-project-123
gcloud config set account alice@acme.io
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b

# Alternar
gcloud config configurations activate dev
gcloud config configurations activate prod

# Verificar
gcloud config list
```

Buena practica: **una configuration por project x entorno**. Nunca editar la `default` para operar; crear configs explicitos.

### 7.2 Properties

Son los pares `key = value` que viven dentro de un configuration. Las mas comunes:

| Property | Para que |
|----------|----------|
| `core/project` | project activo. |
| `core/account` | identidad activa. |
| `compute/region` | region default para `gcloud compute *`. |
| `compute/zone` | zona default. |
| `run/region` | region default para `gcloud run *`. |
| `auth/impersonate_service_account` | **todas** las llamadas se impersonan al SA indicado (patron sin keys). |

### 7.3 Componentes

`gcloud` es modular. Componentes como `kubectl`, `gke-gcloud-auth-plugin`, `beta`, `alpha` se instalan a demanda:

```bash
gcloud components list
gcloud components install gke-gcloud-auth-plugin
gcloud components update
```

> **Trampa**: hay dos formas de instalar `gcloud`: el **SDK** (archivos descomprimidos, usa `gcloud components`) y el **paquete apt/brew** (usa el gestor del sistema; `gcloud components` **no** funciona ahi — hay que instalar los componentes como paquetes separados).

---

## 8. Autenticacion: `gcloud auth login` vs ADC

Esta es **la** confusion mas comun al llegar a GCP. Dos sistemas de credenciales paralelos en la misma maquina:

### 8.1 `gcloud auth login`

Autentica al **usuario humano** contra Google y guarda un token OAuth2 refresh en `~/.config/gcloud/`. Lo usa:

- La CLI `gcloud` para sus propias llamadas (`gcloud compute instances list`).
- `kubectl` cuando el cluster esta configurado con `gke-gcloud-auth-plugin`.
- **No** lo usan las libraries cliente (Python `google-cloud-storage`, Node `@google-cloud/firestore`, Go, etc.).

```bash
gcloud auth login                 # abre browser, Google SSO
gcloud auth list                  # ver cuentas y cual esta activa
gcloud auth revoke alice@acme.io  # limpiar
```

### 8.2 `gcloud auth application-default login` (ADC)

Autentica **las libraries cliente** (SDKs). Guarda credenciales en `~/.config/gcloud/application_default_credentials.json`. Las libraries buscan credenciales en este orden (**ADC chain**):

1. Variable `GOOGLE_APPLICATION_CREDENTIALS` apuntando a un archivo JSON (key de SA o config de impersonation).
2. `~/.config/gcloud/application_default_credentials.json`.
3. Metadata server (si corres en GCE/GKE/Cloud Run/Functions: credenciales de la *attached* SA).
4. Falla con `DefaultCredentialsError`.

```bash
# Para desarrollo local:
gcloud auth application-default login

# Mejor patron: ADC con impersonation (sin crear keys)
gcloud auth application-default login \
  --impersonate-service-account=my-sa@my-project-123.iam.gserviceaccount.com

# Verificar
gcloud auth application-default print-access-token  # token efimero
```

### 8.3 Comparacion

| Mecanismo | Para que | Donde se guarda | Expira |
|-----------|----------|------------------|--------|
| `auth login` | `gcloud` CLI (humano) | `~/.config/gcloud/credentials.db` | refresh token (largo) |
| `auth application-default login` | Libraries cliente / SDKs | `~/.config/gcloud/application_default_credentials.json` | refresh token (largo) |
| **Impersonation** (`--impersonate-service-account=...`) | ambos, delegando a una SA | NO guarda keys; genera tokens efimeros via `iamcredentials.generateAccessToken` | 1 hora por token |
| **Service Account Key** (`*.json` descargada) | antipatron en 2026 | archivo plano, exportable, no rota | nunca; es un riesgo permanente |

> **Regla de oro para 2026**: **nunca** crees ni descargues una **service account key** para desarrollo local ni para pipelines. Usa ADC + impersonation (local) o **Workload Identity Federation** (CI/CD, ver `gcp-10`). Si un repo tiene un `*.json` con un `private_key`, es una **incidencia de seguridad**.

---

## 9. Labels y tags: cost allocation y gobernanza

### 9.1 Labels

Pares `key=value` sobre recursos (projects, buckets, VMs, Cloud Run services, etc.). Caso de uso principal: **cost allocation** y **operacion**.

```bash
gcloud projects update my-project-123 \
  --update-labels=env=dev,owner=platform,cost-center=eng,app=checkout
```

Keys y values restringidos (minusculas, numeros, `-`, `_`, max 63 char cada uno; max 64 labels por recurso).

Labels obligatorios recomendados desde el dia 1:

| Label | Para que |
|-------|----------|
| `env` | `dev|stg|prod|sandbox`. Agrupacion basica. |
| `app` | nombre de la app o producto. |
| `owner` | equipo o grupo responsable. |
| `cost-center` | centro de coste contable. |
| `data-classification` | `public|internal|confidential|regulated`. |

En **Cloud Billing export** a BigQuery, los labels aparecen como columnas y permiten `SUM(cost) GROUP BY labels.app, labels.env`.

### 9.2 Tags (diferentes de labels)

Los **Tags** de GCP (**no** confundir con labels) son objetos con `key` y `value` definidos a nivel Org, con **IAM** propio (`roles/resourcemanager.tagUser`), que se adjuntan a recursos para **evaluar condiciones** en IAM policies u Org Policies. Son el equivalente a los *AWS resource tags IAM-aware*. En este modulo solo los mencionamos; se trabajan en `gcp-02`.

> **Resumen operativo**: para FinOps y agrupacion, usa **labels**. Para condiciones IAM, usa **tags**. Nombres confusos; realidad distinta.

---

## 10. Budgets y alertas: primer control obligatorio

Un **Budget** en Cloud Billing define un monto esperado y **threshold rules** que disparan notificaciones cuando el gasto real o pronosticado cruza umbrales.

Partes:

- **Scope**: toda la BA, projects especificos, o filtros por label.
- **Amount**: fijo (`USD 100 / month`) o calculado (`last month * 1.1`).
- **Threshold rules**: lista de `(percent, basis)` donde `basis` es `CURRENT_SPEND` o `FORECASTED_SPEND`. Tipico: `50%`, `90%`, `100%` de ambos.
- **Notifications**:
  - Email a `roles/billing.admin` y `roles/billing.user` de la BA (default).
  - **Pub/Sub topic**: para automatizacion (una Cloud Function que suspende el project, envia a Slack, etc.).
  - **Monitoring notification channels** (email, SMS, Slack via webhook).

Esquema YAML (consumible por `gcloud alpha billing budgets create --billing-account=<BA> --budget-from-file=budget.yaml`):

```yaml
displayName: "checkout-dev monthly budget"
budgetFilter:
  projects:
    - "projects/my-project-123"
  calendarPeriod: MONTH
amount:
  specifiedAmount:
    currencyCode: "USD"
    units: "100"
thresholdRules:
  - thresholdPercent: 0.5
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 0.9
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: FORECASTED_SPEND
notificationsRule:
  pubsubTopic: "projects/my-project-123/topics/budget-alerts"
  schemaVersion: "1.0"
  monitoringNotificationChannels:
    - "projects/my-project-123/notificationChannels/CHANNEL_ID"
  disableDefaultIamRecipients: false
```

> **Regla de oro**: **ningun** project nuevo se abre sin un budget asociado. Un `p4d.24xlarge` equivalente en GCP (A3 con 8xH100) a 24 h cuesta **miles** de USD; un budget con alerta a 50% da margen para reaccionar.

---

## 11. Scope de los recursos: global, regional, zonal

Diferencia importante contra AWS, donde casi todo es regional o AZ-level. En GCP el *scope* varia por servicio:

| Scope | Ejemplo | Comportamiento |
|-------|---------|----------------|
| **Global** | `networks` (VPC), `firewall rules`, `global IPs`, `global LBs`, `ingress`, `GCS bucket names` | Un unico namespace; nombres unicos a nivel mundial (buckets) o a nivel project (VPC). |
| **Regional** | `subnetworks`, `Cloud Run services`, `Cloud SQL`, `GCS buckets` (ubicacion), `regional LBs`, `KMS keyrings` | Ligados a una region (`europe-west1`). Alta disponibilidad por AZ dentro de la region. |
| **Zonal** | `Compute Engine instances` (sin MIG regional), `persistent disks` zonales | Ligados a una zona (`europe-west1-b`). Fallo de zona = recurso caido. |

**Consecuencias**:

- Los **nombres de GCS buckets son globales**: `acme-logs` lo tomo alguien en 2015, elegir `acme-logs-prod-eu-west1-7a3f`.
- Las **VPC son globales** con subnets regionales (**gcp-03**): una VPC puede abarcar multiples regiones y las subnets de distintas regiones son alcanzables entre si sin peering.
- Las **Compute Engine zonales** por default: para alta disponibilidad usar **Managed Instance Groups regionales**.

---

## 12. Fundamentos internos (lo que suele doler en produccion)

Cinco cosas que **no se intuyen** y conviene fijar:

1. **El `projectId` es inmutable**. Una vez creado, nunca lo puedes cambiar. Si eliges `my-poc-123` y luego la cosa se vuelve prod, lo arrastras siempre. Convencion recomendada: `<org>-<app>-<env>-<hash4>`, p. ej. `acme-checkout-prod-7a3f`.
2. **Un project borrado tarda 30 dias en liberarse**. El `projectId` queda reservado. Util porque permite recuperar (`gcloud projects undelete`), pero mata el habito de "borro y recreo con el mismo nombre".
3. **Enable de una API es asincrono y a veces lento (1-3 min)**. Scripts de bootstrap que ejecutan `enable` + `use` inmediatamente despues fallan con `SERVICE_DISABLED` si no esperan.
4. **El metadata server tiene credenciales**. En GCE/GKE/Cloud Run/Functions, cualquier codigo que corra ahi puede leer credenciales de la SA attached llamando a `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token` con header `Metadata-Flavor: Google`. Este es el mecanismo normal y correcto; pero significa que **toda la seguridad depende de que la SA attached tenga roles minimos**.
5. **ADC en una maquina de developer tiene scope `cloud-platform`** (todo). Si pierdes la laptop o la comprometes, el atacante tiene credenciales validas por el refresh token (6 meses tipicos). Mitigacion: ADC via impersonation + `gcloud auth application-default revoke` + revocacion del grant OAuth desde `myaccount.google.com`.

---

## 13. Alternativas y que llevarse

### Alternativas al stack "Org + Folders + Projects + Billing + gcloud"

- **Terraform desde el dia 1**: en lugar de `gcloud` imperativo, modulo `terraform-google-modules/project-factory/google` para bootstrapear projects con APIs + billing + labels + budget en un solo apply. Recomendado para Fase 4.
- **Config Connector / Config Controller**: APIs declarativas sobre K8s para gestionar recursos GCP. Para orgs grandes que ya operan GitOps.
- **Project per workload** (y no per entorno) en orgs pequeñas: valido como transicion, no como estado final.

### Que llevarse en una frase

> En GCP el **project** es la unidad de aislamiento (equivalente a una account AWS). La **Organization** y los **Folders** dan la jerarquia donde heredan IAM bindings y Org Policies. La **Billing Account** es una entidad **separada** que se **enlaza** a projects — una BA paga por N projects. Las **APIs se habilitan explicitamente** por project (reduce blast radius). `gcloud` ofrece **configurations** para alternar contexto, y distingue **`auth login`** (user, para la CLI) de **`application-default login`** (ADC, para las libraries). El patron moderno es **impersonation** sin keys. Y **ningun project se abre sin budget con alerta**.

### Que sigue

- `gcp-02` — IAM: bindings role->member, roles predefinidos/custom, deny policies, service accounts, impersonation detallada.
- `gcp-03` — VPC global y networking.
- `gcp-09` — Org, Folders, Cloud Identity y Org Policies para produccion.
