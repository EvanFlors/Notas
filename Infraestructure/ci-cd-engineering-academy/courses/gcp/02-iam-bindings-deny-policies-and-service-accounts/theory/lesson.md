# gcp-02 — Lección: IAM en GCP (bindings, deny policies, service accounts)

> 12 secciones. Prerrequisitos: `gcp-01`, `aws-02`, `aws-06`.

---

## 1. Por qué GCP IAM se siente "al revés" si vienes de AWS

En AWS, el modelo mental es: *"una policy JSON se adjunta a un principal (user, group, role) o — menos frecuente — a un recurso (resource policy en S3, SQS)"*. El principal **lleva consigo** su policy.

En GCP, el modelo mental es: *"una **allow policy** vive en el recurso (organization, folder, project, bucket, SA...) y lista **bindings** del tipo (role, members)"*. El recurso **tiene** una lista de quién puede qué.

Mismo problema (dar `S3 GetObject` a un equipo), dos formulaciones:

- **AWS**: creas un IAM Role o Group `BucketReaders`, le adjuntas una policy `{"Effect":"Allow","Action":"s3:GetObject","Resource":"arn:aws:s3:::acme-data/*"}`, metes a los usuarios en el group.
- **GCP**: en el bucket `acme-data` modificas su allow policy añadiendo un binding `{"role": "roles/storage.objectViewer", "members": ["group:data-readers@acme.io"]}`.

Consecuencias prácticas del cambio de locus:

1. En GCP, para auditar "quién tiene acceso al bucket X" miras **el recurso**. En AWS, miras los principals y haces reverse-lookup.
2. En GCP, para auditar "qué puede hacer Alice" iteras **la jerarquía Resource Manager** hacia abajo (porque los bindings heredan). En AWS, miras las policies que lleva el user.
3. En GCP, los **roles son nombres de bundles de permisos** curados por Google (predefined) o por ti (custom). No se "adjuntan" al principal — se **referencian** en un binding del recurso.

> Idea clave que repetiremos: en GCP, los permisos **viven en el recurso**, no en el principal. Y heredan por la jerarquía Resource Manager (Org → Folder → Project → Resource).

---

## 2. Resource Manager y herencia de bindings

La jerarquía (recordada de `gcp-01`):

```
Organization (acme.io)
├── Folder: prod
│   ├── Project: checkout-prod
│   │   ├── Bucket: checkout-prod-receipts
│   │   └── Cloud Run service: checkout-api
│   └── Project: analytics-prod
├── Folder: dev
│   └── Project: checkout-dev
└── Folder: shared
    └── Project: tools-shared
```

Un binding en **Organization** aplica a **todo**. Un binding en **Folder: prod** aplica a los dos projects de prod y a sus recursos. Un binding en **Project: checkout-prod** aplica al bucket y al Cloud Run service. Un binding en **el bucket** aplica solo al bucket.

El permiso efectivo de un principal sobre un recurso es la **unión** de todos los bindings que lo mencionan a lo largo del path hasta la raíz. En AWS pensarías "intersección" — en GCP es **unión aditiva** (y por eso las deny policies — ver sección 5 — son necesarias para quitar permisos).

**Regla operativa**: aplica el binding en el **nivel más bajo** donde tiene sentido. Un `roles/storage.objectAdmin` dado en la organización contamina 500 projects. El mismo rol en el bucket concreto afecta solo a ese bucket.

**Trampa habitual**: dar `roles/editor` a nivel de project para "que funcione rápido". Editor concede ~1800 permisos — incluyendo crear y borrar prácticamente todo salvo IAM. Es el `AdministratorAccess` disfrazado.

---

## 3. Bindings y allow policy: forma concreta

Una allow policy en GCP, representada en YAML (el formato que usa `gcloud projects get-iam-policy` con `--format=yaml`):

```yaml
bindings:
  - role: roles/storage.objectViewer
    members:
      - group:data-readers@acme.io
      - serviceAccount:report-generator@acme-prod.iam.gserviceaccount.com
  - role: roles/run.invoker
    members:
      - group:platform-eng@acme.io
    condition:
      title: only-business-hours
      description: Deny Cloud Run invocations outside business hours
      expression: request.time.getHours("Europe/Madrid") >= 8 && request.time.getHours("Europe/Madrid") < 20
etag: BwX8pQ...
version: 3
```

Elementos:

- **`bindings`**: lista. Cada entry es `(role, members, condition?)`.
- **`role`**: nombre canónico (`roles/<service>.<role>`). Puede ser:
  - *Predefined* (ej. `roles/storage.objectViewer`) — el 95% de los casos.
  - *Custom* (ej. `projects/acme-prod/roles/customReportWriter`) — cuando ningún predefined encaja y necesitas un bundle propio.
  - *Basic* (ej. `roles/viewer`, `roles/editor`, `roles/owner`) — **evítalos**. Son los legacy "primitive roles" y son enormes.
- **`members`**: lista de principals, cada uno con prefijo:
  - `user:alice@acme.io` — identidad humana individual (**úsalo poco**).
  - `group:platform-eng@acme.io` — Google Group (**el patrón recomendado**).
  - `serviceAccount:workload@proj.iam.gserviceaccount.com` — una SA de GCP.
  - `domain:acme.io` — todos los usuarios del dominio (potente y peligroso).
  - `principalSet://iam.googleapis.com/projects/.../workloadIdentityPools/.../...` — WIF (cubierto en `gcp-10`).
  - `allUsers`, `allAuthenticatedUsers` — público. **Prohibido** salvo caso explícito y controlado (buckets de hosting público, imágenes).
- **`condition`**: expresión CEL (Common Expression Language). Permite scoping fino: por tiempo, por prefijo de recurso, por tags del request.
- **`etag`** / **`version`**: control de concurrencia optimista. Si lees con etag `X`, modificas y escribes, otra escritura concurrente con el mismo etag falla. **Nunca** edites policies ignorando el etag — el fallo es "last-write-wins" silencioso.

> Trampa: la lista de `members` no es un set tipado. Un typo (`group:platoform-eng@acme.io`) se acepta sin error — hasta que descubres que nadie tiene acceso.

---

## 4. Roles: predefined, custom y por qué `basic` apesta

**Predefined roles**: Google mantiene cientos. Siguen una convención:

- `roles/<service>.viewer` — lectura.
- `roles/<service>.user` — uso operativo (ej. `roles/cloudsql.client`).
- `roles/<service>.editor` — modificación.
- `roles/<service>.admin` — control total.

Ejemplos útiles:

| Caso | Role predefinido |
|------|------------------|
| App lee objetos de un bucket | `roles/storage.objectViewer` |
| App escribe objetos en un bucket | `roles/storage.objectCreator` |
| App lee **y** escribe objetos | `roles/storage.objectUser` |
| App invoca un servicio Cloud Run | `roles/run.invoker` |
| CI/CD despliega una revisión Cloud Run | `roles/run.admin` + `roles/iam.serviceAccountUser` sobre la runtime SA |
| App publica a Pub/Sub topic | `roles/pubsub.publisher` |
| App conecta a Cloud SQL vía IAM auth | `roles/cloudsql.client` + `roles/cloudsql.instanceUser` |
| Humano explora logs | `roles/logging.viewer` |

**Custom roles**: YAML/JSON con `includedPermissions`. Útiles cuando ningún predefined encaja (p. ej., "listar buckets pero no sus objetos"). Costo: tienes que **mantenerlos** cuando GCP añade permisos nuevos a un servicio.

```yaml
title: Custom Report Writer
description: Puede escribir el bucket de reports y leer los de datos
stage: GA
includedPermissions:
  - storage.objects.create
  - storage.objects.list
  - storage.buckets.get
```

**Basic roles** (`roles/owner`, `roles/editor`, `roles/viewer`):

- Son el *greatest hit* del "funciona en 2 minutos pero compromete todo en 2 años".
- `roles/editor` concede ~1800 permisos (incluyendo `iam.serviceAccounts.create`, `compute.instances.delete`, etc.).
- `roles/owner` concede *todo* **incluyendo** gestionar IAM del project. Un editor con `iam.serviceAccounts.actAs` se puede escalar a owner.
- **Regla**: nunca uses basic roles en producción. En dev/sandbox se tolera, pero bloquea `roles/owner` con org policy si puedes.

---

## 5. IAM Deny Policies: el veto que gana al allow

Hasta hace poco, GCP IAM no tenía un equivalente directo de las SCPs de AWS. Si una SA tenía `roles/editor` heredado de una org binding, no había forma elegante de **quitarle** `storage.buckets.delete` para un bucket concreto — tenías que refactorizar los allows.

**IAM Deny Policies** (GA desde 2022) resuelven esto. Formato YAML:

```yaml
name: policies/cloudresourcemanager.googleapis.com%2Fprojects%2Fcheckout-prod/denypolicies/no-bucket-delete
displayName: Prohibir borrar buckets excepto break-glass
rules:
  - description: Veto storage.buckets.delete para todos excepto el grupo break-glass
    denyRule:
      deniedPrincipals:
        - principalSet://goog/public:all
      exceptionPrincipals:
        - principalSet://goog/group/break-glass-storage@acme.io
      deniedPermissions:
        - storage.googleapis.com/buckets.delete
      denialCondition:
        title: always
        expression: "true"
```

Semántica importante:

1. **`deniedPermissions`** usan nombres totalmente cualificados (`<servicio>.googleapis.com/<permiso>`), **no** nombres cortos (`storage.buckets.delete`). Es un error clásico.
2. **`deniedPrincipals: principalSet://goog/public:all`** significa *todo* principal (equivale a "aplica a cualquiera").
3. **`exceptionPrincipals`** son los que se **escapan** del deny. Patrón break-glass: deniegas universalmente, exceptúas al grupo de emergencia (con 2–3 personas, con MFA, y con alerta cuando lo usan).
4. **Un deny gana aunque exista un allow.** Si un principal tiene `roles/storage.admin` (que incluye `storage.buckets.delete`) y una deny policy lo veta, no puede borrar buckets. Punto.
5. **`denialCondition`** es CEL — igual que en bindings. Útil para denies condicionales ("deniega salvo que el request venga de dentro del VPC X", "deniega salvo entre horario laboral").

Dónde se aplican las deny policies: a **recursos de Resource Manager** — organization, folder, project. **No** a recursos "hoja" (buckets individuales, SAs individuales) — para granularidad fina usas condiciones en el binding o un custom role.

**Comparativa mental AWS ↔ GCP**:

| AWS | GCP |
|-----|-----|
| SCP a nivel de OU | Deny policy a nivel de folder |
| SCP con `NotAction` + `Condition RequestedRegion` | Deny policy con `denialCondition` CEL + `exceptionPrincipals` |
| SCP se evalúa junto a identity policy, un deny gana | Deny policy se evalúa junto a allow bindings, un deny gana |

Diferencia principal: en AWS la SCP afecta a **todos los principals de la cuenta**; en GCP la deny policy se dirige a **principals específicos** (lista explícita, con excepciones también explícitas). Es un modelo más "cirujano", menos "techo general".

---

## 6. Service Accounts: el principal no-humano

Una **service account (SA)** es una identidad propiedad de GCP (vive dentro de un project) usada por workloads para autenticarse ante APIs. Dos tipos:

- **User-managed SAs**: las creas tú con un propósito concreto (`checkout-api-runtime@acme-prod.iam.gserviceaccount.com`). **Patrón recomendado** — una SA por workload.
- **Default SAs**: Google crea una automáticamente para Compute Engine, App Engine, Cloud Build. Vienen con **`roles/editor` por defecto** en el project. Esto es **grotesco** y debes:
  1. Aplicar el org policy `iam.automaticIamGrantsForDefaultServiceAccounts=False` **antes** de usar nada.
  2. O remover el binding `roles/editor` manualmente en projects nuevos.
  3. Mejor: no usar las default SAs — crea una user-managed por workload.

La SA tiene un **email** (`<name>@<project>.iam.gserviceaccount.com`), que la identifica como `member` en bindings de **otros** recursos. Y tiene **sus propios bindings IAM** — un allow policy sobre la SA que dice quién puede *impersonar* o *actAs* esta SA.

**Dos planos distintos que confundir cuesta caro**:

1. "¿Qué puede hacer **esta SA** en GCP?" → bindings en los recursos **que mencionan a esta SA como member**.
2. "¿Quién puede **actuar como esta SA**?" → bindings sobre **la SA misma** (que es un recurso), típicamente `roles/iam.serviceAccountUser` o `roles/iam.serviceAccountTokenCreator`.

---

## 7. SA keys: el anti-patrón que todavía existe

Una **service account key** es un par JSON/P12 descargable que contiene credenciales de larga duración (clave privada RSA 2048, sin fecha de expiración por defecto). Con ese JSON, cualquiera que lo tenga **se autentica como la SA**, desde cualquier parte del mundo, hasta que la clave se revoque explícitamente.

Por qué es un anti-patrón:

1. **No expira.** A diferencia de un token OAuth2 (1 hora) o una credencial STS (hasta 12 h), una SA key sigue siendo válida hasta que la borras. Un JSON filtrado en un repo o en un backup antiguo es una puerta abierta durante años.
2. **No rota sola.** Hay que gestionar la rotación con tooling propio (crear key nueva, redistribuir, borrar la vieja). Casi nadie lo hace bien.
3. **No se auditan sus usos con suficiente granularidad** (sabes qué hizo la SA, no desde dónde se usó la key concreta — hay `keyId` en los audit logs, pero correlacionarlo con "qué equipo tenía ese JSON" es manual).
4. **Un empleado que se va con la key en su laptop es un incident.** Sin la key física, no te enteras.

Alternativas correctas (**ninguna** usa keys):

- **Attached SA** para workloads en GCP (Cloud Run, GCE, GKE con Workload Identity).
- **Impersonation** para humanos y pipelines dentro de GCP (ver sección 8).
- **Workload Identity Federation (WIF)** para pipelines/cargas **fuera** de GCP: GitHub Actions, GitLab CI, AWS, cualquier IdP OIDC. Mapea claims a una SA sin keys (cubierto en `gcp-10`).

Control defensivo baseline: aplica **`constraints/iam.disableServiceAccountKeyCreation`** como org policy en el folder/organization. Deniega `iam.serviceAccountKeys.create`, lo que fuerza al equipo a usar impersonation o WIF.

> En este módulo documentamos SA keys **solo** para explicar por qué se bloquean. No hay actividad que las emita.

---

## 8. Impersonation: el patrón moderno

**Impersonation** es: un principal fuente (humano o SA) obtiene un **access token efímero** (hasta 12 h, por defecto 1 h) para actuar como **otra SA destino**, sin manejar jamás la clave de la destino. El permiso que lo habilita:

- **`roles/iam.serviceAccountTokenCreator`** adjuntado al principal fuente **sobre la SA destino** (no sobre el project).

Esto es un binding **en la SA destino misma**:

```yaml
# Bindings DEL recurso "sa://deployer@acme-prod.iam.gserviceaccount.com"
bindings:
  - role: roles/iam.serviceAccountTokenCreator
    members:
      - group:platform-eng@acme.io
```

Flujo desde la CLI (humano hace deploy a prod sin tener permisos directos en prod):

```
1. alice ejecuta `gcloud auth login` (OAuth, MFA)
   → obtiene credenciales de user:alice@acme.io
2. alice (via membresía en group:platform-eng@acme.io) tiene
   roles/iam.serviceAccountTokenCreator sobre deployer@acme-prod...
3. alice ejecuta:
     gcloud run deploy checkout-api \
       --image=europe-west1-docker.pkg.dev/.../checkout:v42 \
       --impersonate-service-account=deployer@acme-prod.iam.gserviceaccount.com
4. gcloud llama a iamcredentials.googleapis.com:generateAccessToken
   con la identidad de alice y como `name` la SA destino.
5. iamcredentials devuelve un access token efímero para la SA destino.
6. gcloud usa ese token para la llamada a Cloud Run API.
   → la acción se registra en audit logs como:
     authenticationInfo.principalEmail = deployer@acme-prod.iam.gserviceaccount.com
     authenticationInfo.serviceAccountDelegationInfo[0].firstPartyPrincipal.principalEmail = alice@acme.io
   (es decir: sabes que fue alice **impersonando** a deployer)
```

Mismo patrón para SAs encadenadas (SA fuente → SA destino): un CI runner con una SA `ci-runner@tools.iam.gserviceaccount.com` impersona `deployer@acme-prod.iam.gserviceaccount.com`.

**Ventajas sobre SA keys**:

- Credenciales efímeras (1 h por defecto, hasta 12 h).
- No hay nada que rotar.
- Auditoría clara (humano + SA destino, ambos registrados).
- Revocación inmediata: quita a Alice del group → al siguiente token-refresh, no puede impersonar más.

**Primos útiles**:

- `roles/iam.serviceAccountUser` — permite "usar" una SA (p. ej. **adjuntarla** a un recurso al crearlo: `gcloud compute instances create --service-account=...`). Distinto de `tokenCreator` (que emite tokens). Ambos a menudo coexisten.
- `generateIdToken` — para OIDC tokens firmados por la SA, útil para Cloud Run service-to-service.

---

## 9. Org Policies: el baseline que impide pies-en-mano

**Org Policies** (servicio `orgpolicy.googleapis.com`) son **constraints** (no listas de acciones) aplicadas a Org/Folder/Project. Dos tipos:

- **Boolean constraints**: on/off. Ej.: `constraints/iam.disableServiceAccountKeyCreation` (bloquea `serviceAccountKeys.create`).
- **List constraints**: allow-list o deny-list de valores. Ej.: `constraints/compute.vmExternalIpAccess` (lista de VMs permitidas con IP externa; en modo deny-all queda vacía).

Baseline mínimo para `gcp-02` (lo trabajas conceptualmente aquí; se automatiza en `gcp-09`):

| Constraint | Qué hace | Por qué va primero |
|------------|----------|--------------------|
| `iam.disableServiceAccountKeyCreation` | Bloquea `iam.serviceAccountKeys.create`. | Elimina el anti-patrón de SA keys desde el día 1. |
| `iam.automaticIamGrantsForDefaultServiceAccounts` (set to False) | Impide que Compute/App Engine default SAs reciban `roles/editor` automáticamente. | La default SA con `editor` es el agujero `#1` en projects nuevos. |
| `compute.vmExternalIpAccess` (deny-all por defecto) | Bloquea IPs externas en VMs. | Fuerza a usar Cloud NAT / LBs — mejor postura de red. |
| `storage.publicAccessPrevention` | Impide `allUsers` / `allAuthenticatedUsers` en buckets. | Elimina buckets públicos accidentales. |
| `iam.allowedPolicyMemberDomains` | Lista blanca de dominios para `members:` en bindings. | Impide dar acceso a `user:someone@gmail.com` por accidente. |

Diferencia conceptual con AWS: una SCP AWS deniega **acciones**; una org policy GCP restringe **configuraciones del recurso** o **patrones de IAM**. Son complementarias a las deny policies, no sustitutivas:

- Deny policy: "esta persona no puede hacer esta acción".
- Org policy: "este recurso no puede estar configurado así" o "este tipo de binding no se puede crear".

---

## 10. Condiciones IAM (CEL)

Las **conditions** en bindings y deny policies usan **CEL** (Common Expression Language). Operan sobre:

- `request.time` — timestamp del request.
- `resource.name` — nombre canónico del recurso (`projects/_/buckets/acme-prod-logs/objects/foo`).
- `resource.type` — tipo del recurso.
- `request.auth.claims` — para WIF, los claims del token OIDC original.

Ejemplos:

```yaml
# Acceso solo durante horas laborales
condition:
  title: business-hours-only
  expression: |
    request.time.getHours("Europe/Madrid") >= 8 &&
    request.time.getHours("Europe/Madrid") < 20

# Acceso solo a objetos de un prefijo
condition:
  title: only-reports-prefix
  expression: |
    resource.name.startsWith("projects/_/buckets/acme-prod-data/objects/reports/")

# Acceso temporal con fecha de expiración
condition:
  title: expires-2026-12-31
  expression: |
    request.time < timestamp("2026-12-31T23:59:59Z")
```

**Limitaciones a recordar**:

- No todas las APIs soportan conditions al 100%. Algunas condiciones silenciosamente no se evalúan en ciertos servicios legacy.
- Las conditions **no reemplazan** una granularidad fina de recursos — son una capa adicional, no la primera.
- Debugging de conditions es duro: si una condition expression tiene un typo, el binding **nunca** concede permiso y no hay un error claro.

---

## 11. Traducir una policy AWS a GCP: el ejercicio mental

Dada esta policy AWS (adjunta a un IAM role usado por una Lambda):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::acme-prod-data",
        "arn:aws:s3:::acme-prod-data/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:eu-west-1:*:acme-prod-events"
    }
  ]
}
```

Traducción a GCP (dado un workload equivalente en Cloud Run con SA `checkout-api@acme-prod.iam.gserviceaccount.com` leyendo del bucket `acme-prod-data` y publicando a Pub/Sub topic `acme-prod-events`):

**Binding 1** — en el bucket `acme-prod-data`:

```yaml
bindings:
  - role: roles/storage.objectViewer
    members:
      - serviceAccount:checkout-api@acme-prod.iam.gserviceaccount.com
```

**Binding 2** — en el topic Pub/Sub `projects/acme-prod/topics/acme-prod-events`:

```yaml
bindings:
  - role: roles/pubsub.publisher
    members:
      - serviceAccount:checkout-api@acme-prod.iam.gserviceaccount.com
```

Observaciones:

1. En AWS, **una** policy cubre dos recursos. En GCP, **dos** bindings — uno por recurso. Es más verboso pero más explícito.
2. En AWS, el rol de la Lambda tiene la policy. En GCP, la **SA** del Cloud Run service es el `member` de bindings en recursos remotos.
3. El rol GCP (`storage.objectViewer`) incluye *más* permisos atómicos que `s3:GetObject` solo (p. ej. `storage.objects.get`, `storage.objects.list`). Si quieres **solo** `get` y no `list`, necesitas un custom role o `roles/storage.legacyBucketReader` + ajustes.
4. En AWS, puedes limitar por región con `aws:RequestedRegion`. En GCP, el bucket **vive** en una región — el constraint es la ubicación del recurso, no del request.

---

## 12. Fundamentos internos y qué llevarse

### Qué suele doler en producción

1. **Allow aditivo + jerarquía profunda** = permisos que nadie recuerda haber concedido. `gcloud asset analyze-iam-policy` es tu amigo para auditar efectivos.
2. **Default SAs con `editor`** son el "unlocked door" más común. Aplica `iam.automaticIamGrantsForDefaultServiceAccounts=False` antes de crear nada.
3. **Deny policies** son potentes pero no se aplican a cualquier recurso — organiza tu control por folder/project.
4. **Conditions con typo** fallan en silencio. Prueba cada condition en staging antes de ponerla en prod.
5. **SA keys olvidadas** en projects viejos. `gcloud iam service-accounts keys list --iam-account=...` para auditar; `constraints/iam.disableServiceAccountKeyCreation` para prevenir nuevas.

### Qué llevarse en una frase

> En GCP IAM, el permiso **vive en el recurso** (allow policy con bindings), **hereda hacia abajo** por la jerarquía Resource Manager, y se **limita** con deny policies (veto por principal) y org policies (constraints sobre configuraciones). Las **service accounts** son el principal correcto para workloads; se **impersonan** o se **federan** — **nunca** se usan sus keys.

### Qué sigue

- `gcp-03` — VPC global, firewall rules que **referencian SAs** (algo que AWS no tiene — SGs refieren a lo que esté en la subnet, no al principal).
- `gcp-07` — Workload Identity en GKE (ServiceAccount K8s ↔ Google SA sin keys).
- `gcp-09` — org baseline completo con folders y Cloud Identity.
- `gcp-10` — Workload Identity Federation desde GitHub Actions / cualquier IdP, cerrando el círculo "pipelines sin keys".
