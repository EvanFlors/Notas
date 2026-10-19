# ADR 001 — Estructura inicial de la organización GCP (REFERENCIA)

> Documento de referencia para autoevaluar la actividad `gcp-09-01-design-folder-structure-and-adr`. **Léelo DESPUÉS** de haber escrito el tuyo. Hay muchas respuestas "correctas"; esta es una.

## Estado

Aceptado — Fase 1 (2026-10). Esperado reemplazo por ADR 002 cuando se incorpore GKE Autopilot (Fase 3) o un décimo workload.

## Contexto

La organización tiene 25 personas y dos workloads reales (`checkout` y `analytics`). Hoy opera en un único project con `roles/editor` repartido como `editor viewer`, lo que es insostenible por tres razones:

1. **Blast radius sin límite**: un error de IAM compromete todo el gasto y los datos.
2. **Compliance** exige residencia de datos en Europa y auditoría demostrable del acceso a `checkout` (PCI-light).
3. **Finance** no puede atribuir costes porque todo es una sola línea de billing.

Constraints:

- Toda carga debe vivir en **Europa**: `europe-west1` (Bélgica) y `europe-west4` (Países Bajos).
- No se compra Google Workspace; se usa **Cloud Identity Free** sobre el dominio corporativo verificado.
- Una **Billing Account corporativa** única paga todos los projects (atribución por labels + export BigQuery).
- Developers deben poder experimentar sin arrancar nada caro.

## Decisión

### 1. Jerarquía Organization → Folders → Projects

```text
Organization: ejemplo.com                        [Org Policies baseline: 4 constraints]
│
├── Folder: Security                             [+ iam.disableServiceAccountKeyCreation enforce fuerte]
│   ├── Project: logging-prod                    ← sinks Cloud Logging a BigQuery + GCS (retención 400 d)
│   └── Project: security-audit                  ← Security Command Center Standard, consumidor de logs
│
├── Folder: Shared                               [+ compute.restrictSharedVpcHostProjects]
│   ├── Project: shared-vpc-host                 ← Shared VPC host, firewall rules, Cloud DNS zone
│   ├── Project: artifact-registry-corp          ← Artifact Registry corporativo (docker, python)
│   └── Project: tools-shared                    ← runners CI/CD, Terraform state bucket, Cloud Build
│
├── Folder: Workloads
│   │
│   ├── Folder: Workloads/Prod                   [+ compute.requireOsLogin, sql.restrictPublicIp,
│   │   │                                           VPC-SC perimeter 'prod_data_perimeter']
│   │   ├── Project: checkout-prod               ← Cloud Run checkout-api + Cloud SQL + Secret Manager
│   │   └── Project: analytics-prod              ← BigQuery dataset + dashboards productivos
│   │
│   ├── Folder: Workloads/Stg
│   │   └── Project: checkout-stg                ← mismo stack que prod, datos sintéticos
│   │
│   └── Folder: Workloads/Dev                    [+ budget alerts 50 EUR/mes/project]
│       ├── Project: checkout-dev
│       └── Project: analytics-dev
│
├── Folder: Sandbox                              [+ budget hard cap 20 EUR/mes, denyAll external IP]
│   └── Project: sandbox-shared                  ← experimentación personal, un project para toda la empresa
│
└── Project: org-admin                           ← fuera de folders operativos
                                                 ← Terraform de bootstrap, Essential Contacts,
                                                 ← futuros WIF pools (gcp-10)
```

### 2. Patrón por workload

- **`checkout` → tres projects (`checkout-dev`, `checkout-stg`, `checkout-prod`)**.
  - **Por qué**: datos regulados (PCI-light), SLA 99.9%, equipo de 5 que necesita aislamiento duro entre ambientes para no romper prod con un error de IaC o un `terraform apply` en el workspace equivocado. Permite aplicar `prod_data_perimeter` (VPC-SC) solo a prod.
- **`analytics` → un único project `analytics-dev` por ahora, con roadmap a dos (`-dev`/`-prod`) cuando aparezcan dashboards publicados a negocio**.
  - **Por qué**: no toca datos de pago, un data engineer, consumo intermitente. El coste de 3 projects (3 VPCs, 3 datasets, 3 budgets) no justifica el aislamiento. Se adopta `analytics-prod` cuando aparezca el primer dashboard productivo con SLA.

### 3. Org Policies del baseline (adjuntas a Organization)

| Constraint | Donde | Por qué |
|------------|-------|---------|
| `iam.disableServiceAccountKeyCreation=enforced` | Organization (con `enforce=false` en `Sandbox`). | Evita el anti-patrón "SA key en Git o CI logs". Uso obligatorio de impersonation o WIF (ver `gcp-10`). |
| `compute.vmExternalIpAccess=denyAll` | Organization. | Obliga a usar Cloud NAT para salida y Load Balancer para entrada. Reduce superficie de ataque. |
| `storage.publicAccessPrevention=enforced` | Organization. | Cero buckets abiertos al mundo. |
| `iam.allowedPolicyMemberDomains=[customer-id]` | Organization. | Nadie fuera del dominio corporativo puede ser agregado como principal. |
| `compute.requireOsLogin=enforced` | Folder `Workloads/Prod`. | Centraliza acceso SSH vía IAM; sin SSH keys manuales en metadata. |
| `sql.restrictPublicIp=enforced` | Folder `Workloads/Prod`. | Cloud SQL productivo solo con IP privada. |
| `compute.restrictSharedVpcHostProjects` | Folder `Shared`. | Solo `shared-vpc-host` puede actuar como host. |

### 4. Grupos de Cloud Identity y bindings

| Grupo | Rol | Alcance |
|-------|-----|---------|
| `gcp-org-admins@ejemplo.com` | `roles/resourcemanager.organizationAdmin` + MFA obligatorio | Organization. 2 personas. |
| `gcp-billing-admins@ejemplo.com` | `roles/billing.admin` | Billing Account. 2 personas (Finance lead + head of platform). |
| `gcp-security@ejemplo.com` | `roles/iam.securityReviewer`, `roles/logging.viewer` | Organization. Equipo de security (3). |
| `gcp-platform@ejemplo.com` | custom `platform-engineer` | Folder `Shared`. 3 personas. |
| `gcp-dev-engineers@ejemplo.com` | `roles/editor` | Folder `Workloads/Dev`. 12 ingenieros. |
| `gcp-prod-sre@ejemplo.com` | custom `prod-sre` (editor sobre compute, viewer sobre data) | Folder `Workloads/Prod`. 4 on-call. |
| `gcp-breakglass-checkout@ejemplo.com` | `roles/owner` con `Condition` de tiempo | Project `checkout-prod`. Vacío por defecto; se puebla en incidente. |
| `gcp-sandbox-users@ejemplo.com` | `roles/editor` | Folder `Sandbox`. Todos los ingenieros. |

**Nunca** aparece un `user:` directo. Rotación de personas se hace cambiando membresías en Cloud Identity.

### 5. Perímetro VPC Service Controls

Se crea una **Access Policy** a nivel de Organization y un **service perimeter** llamado `prod_data_perimeter` que envuelve:

```yaml
resources:
  - projects/<project-number-of-checkout-prod>
  - projects/<project-number-of-analytics-prod>
restrictedServices:
  - storage.googleapis.com
  - bigquery.googleapis.com
  - cloudkms.googleapis.com
  - secretmanager.googleapis.com
accessLevels:
  - accessPolicies/<policy-id>/accessLevels/corp_network
    # access level: IP corporativa + device trust via Access Context Manager (fase 2)
ingressRules: []    # ningún tráfico cruzado por ahora
egressRules: []     # ningún egress a projects fuera del perímetro
```

**Importante**: se adopta en **dry-run mode** durante 2 semanas antes de `enforce` para detectar llamadas legítimas que rompan (p. ej. CI accediendo a `storage.googleapis.com` desde un runner fuera del perímetro).

### 6. Billing Account y Essential Contacts

- Una Billing Account corporativa única paga todos los projects.
- Labels obligatorias por project: `cost_center`, `team`, `env`, `workload`. Un custom constraint (fase 2) hará esto `enforce`.
- Essential Contacts poblado para `BILLING`, `SECURITY`, `TECHNICAL`, `LEGAL`.
- Billing export a BigQuery activado en `logging-prod`; dashboards en `security-audit`.

### 7. Residencia de datos

Las policies de Organization aplican a toda la jerarquía. Para forzar `europe-west1`/`europe-west4` se añade `gcp.resourceLocations` (list constraint) con `allowedValues: ["in:eu-locations"]`. Esto cubre el constraint equivalente a la SCP AWS `deny-regions` del módulo paralelo `aws-15`.

## Consecuencias

### Positivas

- Blast radius por project: un error en `checkout-dev` no toca `checkout-prod`.
- Auditoría trivial: logs centralizados en `logging-prod`, inmutables (object lock), filtrables por project/folder.
- Finance puede atribuir coste por `workload` y `env` vía labels + billing export.
- Developers tienen `Sandbox` con hard cap: experimentan sin romper la factura.
- SCPs/Org Policies defensivas desde día 1: imposible subir un bucket público "sin querer" o crear una SA key.
- Rotación de personas se hace en Cloud Identity, no en IAM — baja carga operativa.

### Negativas

- Más projects = más Terraform states, más overhead de boilerplate.
- VPC-SC perimeter rompe cosas la primera vez: hace falta dry-run y ventana de observación.
- Cloud Identity Free no provee grupos dinámicos avanzados ni algunas features de auditoría de Workspace.
- El `prod_data_perimeter` complica el pipeline de deploy: hay que incluir el runner CI en el access level o impersonar un SA interno al perímetro.
- Terraforming cross-folder requiere permisos a nivel Organization — concentra riesgo en el pipeline de bootstrap.

## Alternativas descartadas

### Alternativa 1 — Un único project por workload (dev/stg/prod juntos)

Se descarta porque:

- Un `terraform apply` apuntando al workspace equivocado destruye prod.
- VPC-SC solo tiene granularidad de project; mezclar envs rompe el perímetro.
- Billing agregado por env se vuelve imposible sin labels perfectos (y los labels se olvidan).

### Alternativa 2 — Replicar 1:1 la estructura AWS (una cuenta ↔ un project)

Se descarta porque:

- En GCP el project es más barato y granular que una cuenta AWS; forzar 1:1 pierde la ventaja de aislamiento por ambiente.
- Mezcla el modelo: un auditor que conoce GCP esperaría ver `checkout-prod` como project, no `checkout` como project con subcarpetas (que no existen).
- Dificulta aplicar Org Policies por folder, que es el idioma nativo GCP.

### Alternativa 3 — Dos folders (`Prod`, `Non-prod`) sin más

Se considera y se descarta porque `Non-prod` mezclando dev/stg/sandbox dificulta diferenciar budget caps y Org Policies entre entornos. Tres folders operativos (`Prod`, `Stg`, `Dev`) + `Sandbox` separado es la segunda forma más simple y la mínima que diferencia donde importa.

## Preguntas abiertas (fase 2)

- Shared VPC: ¿cuándo se adopta y qué projects pasan a *service*? Hoy cada project tiene su VPC propia; cuando el egress o la ingeniería de red se vuelva ruido, se migra.
- GKE Autopilot vs seguir con Cloud Run: evaluación en `gcp-07`.
- Pasar de Security Command Center Standard a Premium cuando aparezca Compliance Reports como requisito.
