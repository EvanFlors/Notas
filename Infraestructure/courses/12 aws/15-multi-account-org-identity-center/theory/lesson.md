# aws-15 — Lección: multi-cuenta con Organizations e Identity Center

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `aws-01`, `aws-02`, `aws-06`.

---

## 1. Por qué multi-cuenta y no una sola cuenta "bien hecha"

El error de arranque más común en AWS es montar **todo** en una sola cuenta y "separar" los entornos con prefijos de tag o nombres de VPC. Funciona hasta que:

1. Un desarrollador borra por error un bucket de producción porque el IAM policy es "flexible".
2. El límite de recursos por cuenta (p. ej. número de EIPs, de VPCs, de buckets S3) empieza a estrangular.
3. La factura es un único número y nadie sabe cuánto cuesta *dev* vs *prod*.
4. Compliance pide aislamiento duro entre workloads regulados y no regulados.

Una **cuenta AWS** es el **límite más fuerte de aislamiento** que ofrece AWS: aislamiento de IAM (los principals de una cuenta no existen en otra), de red (las VPCs no se solapan), de facturación (cada cuenta tiene su propio invoice line), y de blast-radius (un error en *dev* no toca *prod*). Multi-cuenta es, en la práctica, la unidad de blast-radius en AWS.

La contrapartida es que gestionar N cuentas a mano es inviable. De ahí nacen **AWS Organizations** (para gobernarlas) y **IAM Identity Center** (para que los humanos no tengan N logins).

> **Idea clave que repetiremos:** la cuenta es el límite duro de aislamiento. Organizations + SCPs son el **techo** (lo que ninguna cuenta puede hacer). Identity Center es la **puerta** (cómo entran los humanos).

---

## 2. AWS Organizations: management account, OUs y member accounts

**AWS Organizations** es el servicio que agrupa cuentas bajo una **management account** (antes llamada "payer"). Estructura:

```
      ┌───────────────────────────────┐
      │   Management account (payer)  │   ← NO hospeda workloads
      │   - Billing consolidado        │
      │   - Puede crear OUs y cuentas  │
      │   - Habilita servicios org-wide│
      └──────────────┬────────────────┘
                     │
             ┌───────┴────────┐
             │     Root       │   ← nodo raíz lógico
             └───────┬────────┘
         ┌───────────┼───────────┬──────────────┐
         ▼           ▼           ▼              ▼
      ┌────┐     ┌──────┐    ┌──────┐      ┌─────────┐
      │ OU │     │  OU  │    │  OU  │      │   OU    │
      │Sec │     │Sandbx│    │Workld│      │Suspended│
      └─┬──┘     └──┬───┘    └──┬───┘      └────┬────┘
        │           │           │               │
        ▼           ▼           ▼               ▼
     log-arch    sandbox-   dev / stg /     accts a dar
     audit       dev-user   prod            de baja
```

Conceptos:

- **Management account**: la cuenta que crea la organización. **Regla de oro**: no se usa para hospedar workloads. Solo para gobernanza, billing y servicios org-wide (CloudTrail trail, Config aggregator). Compromiso de IAM aquí = compromiso de **toda** la org.
- **Root**: nodo lógico raíz. No es una cuenta; es el ancestro común de todas las OUs y cuentas.
- **Organizational Unit (OU)**: carpeta que agrupa cuentas. Soporta anidamiento (OU dentro de OU). Las **SCPs** se aplican a OUs (o a cuentas individuales) y heredan hacia abajo.
- **Member account**: cualquier cuenta de la org que no es el management. Nace de dos formas:
  - **Account creation** (`CreateAccount` API): la org crea una cuenta nueva. **Preferida** en entornos modernos porque hereda el baseline desde el día cero.
  - **Invitation**: se invita a una cuenta existente a unirse. Útil para absorber una cuenta heredada; pero esa cuenta llega "sucia" y hay que normalizarla a mano.
- **Consolidated billing**: una sola factura para toda la org. Los **Reserved Instances** y **Savings Plans** se comparten (relevante para FinOps en `aws-17`).

> **Trampa habitual**: usar el management account como "sandbox de arquitecto" porque "es el primero que crearon". Si ese usuario tiene MFA mal configurado, un atacante puede comprometer la org entera.

---

## 3. Diseño de OU structure: el patrón estándar

La OU structure no es decoración: es **el eje sobre el que se cuelgan las SCPs y las asignaciones de Identity Center**. Un patrón que escala para una org pequeña o mediana (recomendado por AWS SRA — Security Reference Architecture):

```
Root
├── Security OU
│   ├── log-archive         (receptor central de CloudTrail/Config logs)
│   └── audit               (herramientas de seguridad: GuardDuty, SecurityHub)
├── Infrastructure OU       (opcional en orgs pequeñas)
│   └── network             (Transit Gateway, Route 53 Resolver — ver aws-17)
├── Workloads OU
│   ├── workload-A-dev
│   ├── workload-A-stg
│   ├── workload-A-prod
│   ├── workload-B-dev
│   └── workload-B-prod
├── Sandbox OU
│   └── sandbox-<user>      (una por desarrollador para experimentar)
└── Suspended OU            (cuentas a dar de baja, con SCP deny-all)
```

Reglas de pulgar:

- **Security OU al tope** y aislada. Las cuentas `log-archive` y `audit` reciben SCPs específicas (nadie, ni admin, puede borrar los logs).
- **Workloads por entorno** (dev/stg/prod). Esto permite SCPs distintas por entorno: p. ej. en `prod` denegar acciones destructivas sin MFA, en `dev` ser más laxo.
- **Sandbox** aislado con **budget alerts duros**. Un sandbox que arranca un `p4d.24xlarge` sin querer puede costar más que el salario del developer en una semana.
- **Suspended** con `Deny *` para cuentas en proceso de cierre (el cierre de cuentas en AWS no es inmediato).

Alternativa: **"una app = una cuenta"** (sin dev/stg/prod separados). Útil cuando el equipo es pequeño o la app es un spike interno. Pierdes aislamiento de blast-radius entre entornos, ganas simplicidad.

---

## 4. Service Control Policies (SCPs): el techo, no el suelo

Una **SCP** es una política JSON **adjuntada a un OU o a una cuenta** que **limita lo que puede hacerse en esas cuentas**. Reglas conceptuales:

1. **La SCP es un techo, no un suelo.** No concede permisos; solo los limita. Para que un principal pueda hacer `s3:PutObject`, necesita:
   - La SCP de su cuenta **debe permitirlo** (o no mencionarlo si el estilo es *allow-list*).
   - Su **identity policy** (o resource policy) **debe permitirlo explícitamente**.
   - **Ambas** condiciones son necesarias; una SCP permisiva **no** sustituye al allow en la identity policy.
2. **Un `Deny` en una SCP es inapelable.** Ninguna identity policy puede evadirlo. Esto es lo que la hace útil como guardrail.
3. **Herencia descendente**: una SCP en una OU aplica a todas las cuentas descendientes. La efectiva en una cuenta es la **intersección** de todas las SCPs desde Root hasta la cuenta.
4. **La SCP no aplica al management account.** Esta es una **consecuencia importante**: por eso el management no hospeda workloads — porque los guardrails no lo protegen.
5. **Dos estilos de SCPs**:
   - **Allow-list** (whitelist): comenzar con `Deny *` y permitir solo lo listado. Muy restrictivo; difícil de operar.
   - **Deny-list** (blacklist, el estilo por defecto de AWS): comenzar con `FullAWSAccess` heredada y añadir denies específicos. Es el patrón pragmático recomendado.

**Baseline mínimo recomendado** (lo trabajas en la actividad 02):

| SCP | Qué deniega | Por qué |
|-----|-------------|---------|
| `deny-leave-organization` | `organizations:LeaveOrganization` | Impide que una cuenta rogue salga de la org y escape del gobierno. |
| `deny-regions` | Casi todo salvo en una lista blanca de regiones | Compliance (datos deben vivir en UE), control de superficie y de costo. |
| `deny-disable-logging` | `cloudtrail:StopLogging`, `cloudtrail:Delete*`, `config:StopConfigurationRecorder`, etc. | Protege la auditoría. Sin esto, un atacante borra la evidencia. |

Otros frecuentes: `deny-root-user-actions` (prohíbe que el root user haga nada operativo), `require-mfa-for-destructive-actions`, `deny-public-s3-buckets`, `restrict-ec2-instance-types` (en sandbox).

> **Prueba mental siempre antes de aplicar una SCP**: "¿esto bloquea algo que el equipo necesita hacer legítimamente ahora mismo?". Una SCP que paraliza producción un lunes a las 09:00 es peor que no tener SCPs.

---

## 5. SCPs: anatomía JSON

Una SCP comparte sintaxis con una IAM policy, pero su efecto es distinto (limita, no concede). Esqueleto:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeaveOrg",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    }
  ]
}
```

Elementos:

- **`Version`**: siempre `"2012-10-17"`. No es la fecha de hoy; es la versión del *policy language*.
- **`Statement`**: lista. Puede haber uno o varios.
- **`Sid`**: identificador legible. Opcional pero recomendado por diffs/revisiones.
- **`Effect`**: `"Allow"` o `"Deny"`. En SCPs normales (deny-list), lo útil es `Deny`.
- **`Action`**: una string o array `"service:Action"`. Soporta wildcard (`"s3:*"`, `"ec2:Delete*"`).
- **`Resource`**: casi siempre `"*"` en SCPs — las SCPs razonan sobre **principals**, no sobre recursos específicos.
- **`Condition`**: la pieza más poderosa. Permite denies condicionales. Ejemplos:
  - `aws:RequestedRegion` para restringir regiones.
  - `aws:PrincipalArn` para excluir ciertos roles del deny.
  - `aws:MultiFactorAuthPresent` para exigir MFA.

Ejemplo con condición (deny de regiones salvo lista blanca y salvo servicios globales):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideAllowedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "cloudfront:*",
        "route53:*",
        "support:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["eu-west-1", "eu-central-1"]
        }
      }
    }
  ]
}
```

Dos sutilezas importantes:

1. **`NotAction` + `Deny`** significa "deniega **excepto** lo listado". Hace falta porque IAM, Organizations, CloudFront, etc. son **servicios globales** sin región — si los deniegas por `aws:RequestedRegion`, rompes la cuenta.
2. **Las condiciones usan claves globales** (`aws:*`) o específicas de servicio (`s3:*`, `ec2:*`). La documentación de IAM lista cuáles aplican en qué contexto; no todas las claves funcionan en SCPs.

---

## 6. Control Tower: la landing zone opinada

**AWS Control Tower** empaqueta las decisiones "obvias pero tediosas" de montar una org bien:

- Crea un **management account** si no existe.
- Crea una **log-archive account** (centraliza CloudTrail y Config logs).
- Crea una **audit account** (consume los logs; aquí viven herramientas de seguridad).
- Habilita **CloudTrail organization trail** (todos los eventos de todas las cuentas van al bucket central).
- Habilita **AWS Config** y agregador.
- Aplica un conjunto de **guardrails** (que son, bajo el capó, SCPs + Config rules):
  - *Preventive* (SCPs): "no se pueden desactivar logs", "no se pueden borrar snapshots de EBS", etc.
  - *Detective* (Config rules): "se detectará un bucket público", "se detectará un EBS no cifrado".
- Habilita **IAM Identity Center** con un directorio interno por defecto.
- Añade **Account Factory**: una interfaz para vendear cuentas nuevas con el baseline aplicado.

**Qué es gratis y qué no**:

- Control Tower (el servicio): **gratis**.
- **CloudTrail, Config, S3 (logs), KMS**: cuestan según uso. En una org pequeña (3–5 cuentas, poca actividad), suele estar entre **5 y 30 USD/mes**; en una org grande con muchas workloads, puede subir rápido (Config evaluations son por recurso).

**Cuándo adoptarlo y cuándo no**:

- **Sí** si estás arrancando una org y quieres el baseline en 1 día en lugar de 2 semanas.
- **No** (o con cuidado) si ya tienes una org montada a mano: Control Tower es *opinativo* y puede chocar con tu estructura existente. Hay un path de "enrollment" para cuentas pre-existentes, pero no es trivial.

**Alternativa**: montar la misma estructura con Terraform (`org-with-tf`) para tener control fino y versionado. Es más trabajo inicial, pero evita el acoplamiento al servicio Control Tower.

---

## 7. IAM Identity Center: una sola puerta para los humanos

**IAM Identity Center** (nombre nuevo de **AWS SSO**) es el servicio de **acceso humano** a múltiples cuentas de la org. Reemplaza el anti-patrón de "crear un IAM user en cada cuenta por desarrollador".

Flujo:

```
┌────────────────────┐      ┌─────────────────────┐
│   Identity source  │      │ IAM Identity Center │
│  - Interno (IdC)   │─────►│ (en management acct) │
│  - Okta            │      │                     │
│  - Entra ID (AAD)  │      │  Users + Groups     │
│  - Google Workspace│      │  Permission Sets    │
└────────────────────┘      │  Assignments        │
                            └──────────┬──────────┘
                                       │
                       ┌───────────────┼───────────────┐
                       ▼               ▼               ▼
                 ┌──────────┐   ┌───────────┐   ┌───────────┐
                 │ dev acct │   │ stg acct  │   │ prod acct │
                 │ (role    │   │ (role     │   │ (role     │
                 │ materia- │   │ materia-  │   │ materia-  │
                 │ lizado)  │   │ lizado)   │   │ lizado)   │
                 └──────────┘   └───────────┘   └───────────┘
```

Piezas:

- **Identity source**: dónde viven los usuarios. Opciones:
  - **Interno** (directorio propio de IdC). Fácil para arrancar; mal si la empresa ya tiene IdP corporativo.
  - **Externo vía SAML/SCIM**: Okta, Microsoft Entra ID (Azure AD), Google Workspace, otros IdPs SAML 2.0. Lo deseable en una organización mediana/grande.
- **Permission Set**: una **plantilla de permisos** definida en IdC. Puede ser:
  - *AWS managed* (`AdministratorAccess`, `ReadOnlyAccess`, `Billing`...).
  - *Customer managed* (JSON de IAM policy).
  - *Mixed* (combinación).
- **Assignment**: la tupla `(principal, permission set, account)`. Ejemplo: `(group=platform, PS=AdministratorAccess, account=workload-A-prod)`.
- **Materialización**: cuando IdC aplica un assignment, **crea un IAM role en la cuenta destino** cuyo nombre deriva del Permission Set (`AWSReservedSSO_<PS>_<hash>`). El usuario asume ese rol al hacer login. **No es un user en la cuenta**; es un **rol asumido vía federación SAML**.

Ventajas sobre IAM users clásicos:

- Un solo login (SSO) para todas las cuentas.
- Rotación centralizada (cambias el permission set en IdC, se refleja en todas las cuentas asignadas).
- Sin credenciales de larga duración (`aws configure sso` genera credenciales temporales STS, 1h-12h).
- Auditoría centralizada: cada acceso aparece en CloudTrail de la cuenta destino **y** en los logs de IdC.

**Trampa**: pensar que un Permission Set es un rol. Es una **plantilla**; el rol real se crea por cuenta. Si borras el Permission Set, se borran todos los roles materializados.

---

## 8. Permission Sets: catálogo recomendado

En una org pequeña, un catálogo mínimo:

| Permission Set | Políticas base | Audiencia |
|----------------|----------------|-----------|
| `AdministratorAccess` | `AdministratorAccess` AWS managed | Platform/SRE, solo en cuentas de dev y audit. |
| `PowerUserAccess` | `PowerUserAccess` + custom (sin IAM write) | Developers en dev/stg. |
| `ReadOnlyAccess` | `ReadOnlyAccess` AWS managed | Developers en prod, QA en todas. |
| `BillingReadOnly` | `AWSBillingReadOnlyAccess` | Finance. |
| `SecurityAuditor` | `SecurityAudit` + CloudTrail/Config read | Equipo de seguridad en audit account. |
| `BreakGlass` | `AdministratorAccess` + condición MFA + alerta | Acceso de emergencia en prod. Asigna a un grupo con 2 personas; cada uso dispara un alert. |

**Trade-off clave**: granularidad vs mantenibilidad. Tener 40 permission sets distintos para 40 roles es ingobernable; tener 2 (admin / readonly) deja a los developers con demasiado o demasiado poco. Un punto dulce habitual: 6–10 permission sets, versionados en Git si usas Terraform/CloudFormation.

**Patrón de assignment por OU, no por cuenta**: IdC soporta asignar un permission set a una **OU entera**. Así, cuando creas una cuenta nueva en la OU `Workloads/dev`, el grupo `developers` ya tiene `PowerUserAccess` sin tocar nada. Reduce drift.

---

## 9. Cross-account roles: pipelines y humanos "jump"

Más allá de IdC, hay dos patrones de **cross-account access** importantes:

### 9.1 Pipelines (CI/CD) hacia múltiples cuentas

Un pipeline en GitHub Actions (o un runner en una cuenta de *tools*) necesita desplegar a `dev`, `stg`, `prod`. El antipatrón: dar al pipeline una AWS access key con `AdministratorAccess` en las tres cuentas.

Patrón correcto:

1. El pipeline se autentica contra una cuenta de *tools* (vía OIDC, idealmente — ver `aws-16`).
2. En *tools* asume un rol que **solo** tiene `sts:AssumeRole` sobre los roles de deployment en las cuentas destino.
3. Cada cuenta destino tiene un **deployment role** (`DeployerFromTools`) con una **trust policy** que permite `sts:AssumeRole` **solo** desde el rol de *tools* y, opcionalmente, con condiciones (ExternalId, source IP, tags).

```
┌─────────────┐  OIDC   ┌───────────────┐  AssumeRole  ┌──────────────┐
│  GitHub     │────────►│  tools acct   │─────────────►│  dev acct    │
│  Actions    │         │  ToolsRole    │              │  DeployerFrom│
└─────────────┘         └───────┬───────┘              │  Tools       │
                                │                      └──────────────┘
                                │
                                └──────────────────────► stg, prod …
```

Ventajas:

- Sin keys humanas.
- El scope del pipeline se controla **centralmente** en los trust policies de los deployment roles.
- Fácil de rotar (borrar la federación OIDC y rehacerla).

### 9.2 Jump para humanos

Un patrón heredado (previo a IdC): una cuenta de *jump* con usuarios IAM, y roles en cada cuenta destino asumibles desde allí. **Hoy, IdC lo reemplaza casi siempre.** Lo mantienes solo si tienes integraciones heredadas que no soportan SAML/OIDC.

---

## 10. Patrones "una app = una cuenta" vs "una app = N cuentas"

### 10.1 Una app = una cuenta

- Un solo blast-radius por app. Si la app explota, no afecta a otras.
- Billing claro (una cuenta = una línea en el invoice).
- Pero: no hay separación dev/stg/prod a nivel de cuenta; separas por VPC o por tag. Un deploy a prod rompiendo dev por un bug compartido es posible.
- Útil para apps **pequeñas**, **internas** o **spikes**.

### 10.2 Una app = N cuentas (dev / stg / prod)

- Blast-radius por entorno, no solo por app. Un `terraform apply` equivocado en *dev* no toca *prod* ni por accidente.
- SCPs distintas por entorno: *dev* laxa, *prod* estricta.
- Permission Sets distintos: `PowerUser` en dev, `ReadOnly` en prod (excepto deploy role).
- Pero: 3× cuentas por app, más overhead administrativo. Si tienes 20 apps, son 60 cuentas.
- **Patrón estándar para producción crítica.**

### 10.3 Híbrido

En orgs maduras, se mezclan: apps críticas tienen dev/stg/prod; apps internas comparten una cuenta "internal-tools". La OU structure refleja esto con `Workloads/critical` y `Workloads/internal`.

---

## 11. Fundamentos internos (lo que suele doler en producción)

Cuatro cosas que **no se intuyen** y conviene fijar:

1. **El management account no está protegido por sus propias SCPs.** Si lo pones a hospedar workloads, los guardrails no aplican. Un compromise aquí = compromise de la org entera. Regla operativa: **nadie opera cosas en el management, excepto gobernanza.**
2. **Las SCPs no evalúan hasta que un principal intenta algo.** No hay "la SCP niega al momento de aplicarse"; si ya había recursos creados antes de la SCP, siguen existiendo. Las SCPs son controles **sobre acciones futuras**, no sobre estado existente.
3. **Un Permission Set en IdC genera un IAM role por cuenta asignada.** Si el permission set se llama `PowerUser`, el rol en la cuenta será `AWSReservedSSO_PowerUser_<hash>`. No puedes editarlo directamente — todas las ediciones se hacen en el permission set en IdC, que **re-provisiona** el rol. Editar el rol a mano causa drift que IdC sobrescribe en el siguiente *provision*.
4. **Control Tower aplica guardrails como SCPs reales.** Puedes verlas (y leerlas) con `aws organizations list-policies`. Si quieres añadir custom-SCPs, hazlo **fuera** del scope de Control Tower (en OUs propias) para no interferir con sus políticas gestionadas.

---

## 12. Alternativas y qué llevarse

### Alternativas al stack "Organizations + Control Tower + IdC"

- **Terraform puro** (sin Control Tower): más trabajo inicial, más control. Patrón si quieres evitar lock-in a Control Tower o si tu organización ya tiene su propia opinión sobre OUs y guardrails.
- **IdP primero, IdC después**: si tu organización ya usa Okta/Entra ID como fuente única de identidad, integrarlo con IdC es la vía natural; usar el directorio interno de IdC es un paso que suele saltarse.
- **AWS Organizations sin IdC**: posible pero inferior. Usar IAM roles cross-account con SAML federation directa al IdP corporativo. Más piezas que mantener a mano.

### Qué llevarse en una frase

> Una cuenta es el límite duro de aislamiento en AWS. **Organizations + SCPs** definen el techo (lo que **ninguna** cuenta puede hacer). **IAM Identity Center** define la puerta (cómo entran los humanos). **Control Tower** empaqueta el baseline opinado. **Cross-account roles** son el pegamento para pipelines y acceso heredado. Diseñar la OU structure al principio evita migraciones dolorosas después.

### Qué sigue

- `aws-16` — aterriza DevSecOps sobre esta base: OIDC GHA → AWS, Inspector, GuardDuty, cosign/EKS admission.
- `aws-17` — extiende la landing zone con red central (Transit Gateway), FinOps y DR.
