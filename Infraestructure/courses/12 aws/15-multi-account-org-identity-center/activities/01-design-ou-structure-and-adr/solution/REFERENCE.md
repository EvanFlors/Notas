# REFERENCE — aws-15-01-design-ou-structure-and-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Estructura inicial de la organización AWS

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Security + Platform y materializado con Terraform en Fase 4.

## Contexto

La startup pasa de operar en una sola cuenta "fundadora" a necesitar aislamiento real:

- **Compliance**: los datos de pago de `checkout` imponen PCI-light; los auditores exigen que los logs no puedan ser borrados por los propios equipos de la aplicación.
- **Residencia de datos**: por GDPR, todas las cargas deben vivir en Europa.
- **Blast-radius**: un `terraform apply` equivocado contra producción no debe ser posible desde la máquina de un developer, y menos aún "sin querer".
- **Billing**: Finance quiere diferenciar coste por entorno (dev vs prod) y por workload.
- **Acceso humano**: hoy los 20 miembros entran con IAM users en una cuenta compartida. Insostenible y auditable con dificultad.
- **Escala esperada**: 2 workloads hoy (`checkout`, `analytics`), estimamos 5–8 en 18 meses.

## Decisión

### 1. Estructura de OUs y cuentas

```
Root
├── Security OU                       [SCP: deny-leave-org, deny-disable-logging]
│   ├── log-archive                   (CloudTrail org trail destination, Config logs)
│   └── audit                         (GuardDuty delegated admin, SecurityHub)
│
├── Workloads OU                      [SCP: deny-leave-org, deny-regions (eu-*)]
│   ├── Workloads/Prod                [SCP extra: deny-public-s3, require-mfa-destructive]
│   │   └── checkout-prod
│   ├── Workloads/Stg
│   │   └── checkout-stg
│   └── Workloads/Dev
│       ├── checkout-dev
│       └── analytics                 (una sola cuenta — ver sección 2)
│
├── Sandbox OU                        [SCP: deny-leave-org, deny-regions, deny-expensive-instances, budget hard-cap]
│   └── sandbox-shared                (una cuenta compartida, 10 USD/mes de budget)
│
├── Tools OU                          [SCP: deny-leave-org, deny-regions]
│   └── tools                         (CI/CD runners, ECR central, artefactos)
│
├── Suspended OU                      [SCP: deny-all]
│   └── (vacía por ahora)
│
└── management-payer                  (fuera de OUs operativas; NO hospeda workloads)
```

### 2. Patrón por workload

- **`checkout`** → **"una app = N cuentas"** (`checkout-dev`, `checkout-stg`, `checkout-prod`).
  - Razón: SLA 99.9% + PCI-light. Blast-radius por entorno obligatorio. Prod con SCPs más estrictas que dev; Permission Sets `ReadOnly` por defecto en prod, con `BreakGlassProd` para emergencias.
- **`analytics`** → **"una app = una cuenta"** (solo `analytics` en `Workloads/Dev`).
  - Razón: no toca datos de pago; uso interno en horario laboral; equipo de 1 persona; aún no justifica el overhead de 3 cuentas. Se separa el día que entre en una ruta crítica de decisión de negocio.

### 3. SCPs del baseline (adjuntas por OU)

| SCP | Adjunta a | Qué hace |
|-----|-----------|----------|
| `deny-leave-organization` | Root (hereda a toda la org salvo management) | Nadie puede sacar su cuenta de la org. |
| `deny-regions` (whitelist `eu-west-1`, `eu-central-1`) | Workloads, Sandbox, Tools | Compliance Europa. Excluye servicios globales (IAM, Organizations, CloudFront, Route 53, STS). |
| `deny-disable-logging` | Security, Workloads | Protege CloudTrail/Config y el bucket central de logs. |
| `deny-public-s3-buckets` | Workloads/Prod | En prod no se publican buckets públicos. |
| `require-mfa-destructive` | Workloads/Prod | Deletes de RDS/EBS/S3 requieren MFA. |
| `deny-expensive-instance-types` | Sandbox | Sin `p*.*`, `x1.*`, `*.metal`. |
| `deny-all` | Suspended | Cuenta congelada. |

### 4. Catálogo de Permission Sets

| Nombre | Políticas | Session | Asignado a |
|--------|-----------|---------|------------|
| `AdministratorAccess` | AWS managed | 1h | `group=platform` en `Workloads/Dev`, Sandbox, Tools. |
| `PowerUserAccess` | AWS managed + inline (no `iam:*Write*`) | 4h | `group=developers` en `Workloads/Dev`, Workloads/Stg. |
| `ReadOnlyAccess` | AWS managed | 8h | `group=developers` en `Workloads/Prod`; `group=qa` en toda `Workloads/*`. |
| `BillingReadOnly` | `AWSBillingReadOnlyAccess` | 8h | `group=finance` en management (vía billing dashboards). |
| `SecurityAuditor` | `SecurityAudit` + lectura CloudTrail/Config | 8h | `group=security` en `audit`, `log-archive`, y read-only en Workloads/*. |
| `BreakGlassProd` | `AdministratorAccess` + Condition MFA + alert | 1h | `group=breakglass` (2 personas) en `checkout-prod`. Cada uso dispara alert a Slack. |

### 5. Acceso humano: IAM Identity Center

- **Identity source**: directorio interno de IdC en Fase 3 (arranque rápido). **Migración a Entra ID (Azure AD)** vía SAML + SCIM en Fase 4 (ya aprobado por IT corporativo).
- **Assignments por OU, no por cuenta** siempre que sea posible. Añadir una cuenta nueva a una OU basta para que los developers tengan acceso según su grupo.
- **Sin IAM users humanos en ninguna cuenta**. Los únicos IAM users permitidos son *service users* de integraciones heredadas, documentados y con rotación.

### 6. Cross-account para pipelines

- CI/CD vive en la cuenta `tools` (OU `Tools`).
- OIDC GitHub Actions → rol en `tools` (`ToolsCIRole`).
- `tools` asume `DeployerFromTools` en cada cuenta de workload (`checkout-dev`, `-stg`, `-prod`).
- Trust policies de `DeployerFromTools` pinnean al rol de `tools` + ExternalId. Esto se detalla en `aws-16`.

### 7. Diagrama de responsabilidades por cuenta

```
management-payer   → billing + Organizations + IdC. Cero workloads.
log-archive        → recibe logs. Nadie opera aquí (ReadOnly auditores).
audit              → consola de GuardDuty/SecurityHub. Security team.
checkout-prod      → la app crítica. ReadOnly por defecto; BreakGlass en emergencias.
checkout-stg       → clon de prod para QA. Developers con PowerUser.
checkout-dev       → desarrollo. Developers con PowerUser.
analytics          → pipeline Spark + dashboards internos.
tools              → CI/CD, ECR, artefactos.
sandbox-shared     → experimentación barata con budget hard-cap.
```

## Consecuencias

### Positivas

- Blast-radius de `prod` queda aislado de `dev` y de otras workloads.
- Baseline aplicado desde el día cero mediante SCPs; nuevas cuentas en Workloads heredan guardrails sin trabajo manual.
- Un solo login (IdC) para 20 personas × 7+ cuentas = fin del infierno de IAM users.
- Billing por cuenta → Finance puede ver gasto por entorno/workload sin tags adicionales.
- Preparados para `aws-16` (OIDC) y `aws-17` (landing zone extendida) sin re-estructurar.

### Negativas

- 7 cuentas desde el día uno: más superficie administrativa que una sola cuenta.
- SCPs mal escritas pueden paralizar un entorno. **Mitigación**: probar SCPs primero en Sandbox OU; monitorear denies en CloudTrail los primeros 7 días tras cambios.
- Migración del estado actual (1 cuenta) a 7 cuentas requiere mover recursos (no se "mueven" cuentas en AWS; se re-crean). **Mitigación**: migración en 2 fases por workload, con doble-escritura temporal.
- Finance y Security deben aprender a navegar entre cuentas. **Mitigación**: la UI de IdC lo hace razonablemente llevadero.

## Alternativas descartadas

### Alternativa A: una sola cuenta "bien organizada"

- Separar por VPCs y por tags, con IAM policies estrictas.
- **Por qué no**: no da aislamiento duro de IAM; el blast-radius sigue siendo la cuenta entera; billing por entorno requiere tags obligatorios perfectamente aplicados (no realistas en una startup); un error de policy "abre" todo a todos.

### Alternativa B: una cuenta por entorno, no por workload

- `dev-shared`, `stg-shared`, `prod-shared` con todas las workloads dentro.
- **Por qué no**: pierde el aislamiento entre workloads; un bug en `analytics-prod` que haga `delete *` puede tocar recursos de `checkout-prod`. Billing por workload exige tags disciplinados.

### Alternativa C: AWS Control Tower directamente

- Lo evaluamos. Pros: baseline en 1 día. Contras: es opinativo y la customización fuera de su scope añade complejidad; nuestros constraints (Europa + PCI-light) requieren SCPs específicas que preferimos controlar via Terraform. **Decisión diferida**: re-evaluamos adoptarlo cuando lleguemos a 15+ cuentas.

### Alternativa D: "una app = una cuenta" también para `checkout`

- Rechazada: la app crítica necesita entornos aislados para probar cambios sin tocar prod. Lo revisitamos para `analytics` cuando crezca.

---

## Nota sobre IDs

Todos los IDs de cuenta son placeholders ficticios en el diagrama. En Fase 4, los IDs reales se generarán al crear las cuentas y se registrarán en un `accounts.yaml` versionado, no en este ADR.
