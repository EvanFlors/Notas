# REFERENCE — gcp-03-01-shared-vpc-host-and-service

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Shared VPC para la organización GCP

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Platform + Security y materializado con Terraform en Fase 4.

## Contexto

La startup entra en GCP tras un año en una cuenta "fundadora" de otro cloud. Necesita:

- **Compliance Europa**: todas las cargas residentes en `europe-*`. Nada en `us-*` ni `asia-*`.
- **Blast-radius**: un `terraform apply` equivocado contra la red de producción no debe venir de un equipo de aplicación.
- **Billing**: Finance quiere diferenciar coste por workload (checkout, analytics).
- **Operación de red**: Platform/Networking quiere operar una sola VPC, no N.
- **Sin IP externa por default**: VMs sin IP pública; egress por Cloud NAT; APIs de Google por PGA.
- **Firewall por identidad**: en vez de SGs/tags, filtrar por service account.

## Decisión

### 1. Projects

```
Organization / folders/prod
│
├── net-host-prod       ← host project de la Shared VPC (operado por Platform)
├── checkout-prod       ← service project (workload checkout)
└── analytics-prod      ← service project (workload analytics)
```

Reemplaza esto por `-stg` y `-dev` para el resto de entornos (fuera del alcance de este ADR, mismo patrón).

### 2. VPC y subnets

```
Shared VPC: vpc-prod   (global, custom, routing_mode=GLOBAL)
CIDR         10.10.0.0/16          (deja 16 subnets /20 — margen amplio)

Subnets
├── europe-west1-primary   10.10.0.0/20     privateIpGoogleAccess=true
└── europe-west4-primary   10.10.16.0/20    privateIpGoogleAccess=true
    (reservado 10.10.32.0/20..10.10.240.0/20 para futuras regiones/entornos)
```

### 3. Service accounts

| SA | Project | Rol en el workload |
|----|---------|--------------------|
| `app-sa@checkout-prod.iam.gserviceaccount.com` | checkout-prod | VMs del API checkout. |
| `db-sa@checkout-prod.iam.gserviceaccount.com` | checkout-prod | Proxy auth hacia Cloud SQL. |
| `analytics-sa@analytics-prod.iam.gserviceaccount.com` | analytics-prod | Pipeline Spark + BigQuery. |

### 4. Firewall rules del baseline (todas en la Shared VPC)

| Nombre | Dirección | Qué permite / deniega |
|--------|-----------|----------------------|
| `allow-health-checks-to-app` | INGRESS | 35.191.0.0/16 + 130.211.0.0/22 → `app-sa` en tcp:80,443 |
| `allow-app-to-db-5432` | INGRESS | `app-sa` → `db-sa` en tcp:5432 |
| `allow-analytics-to-bigquery-pga` | EGRESS | `analytics-sa` → `restricted.googleapis.com` en tcp:443 |
| `deny-all-egress-default` | EGRESS | 0.0.0.0/0 denegado (prio 65534) |
| `deny-all-ingress-default` | INGRESS | implícito en prio 65535 (regla explícita opcional para logging) |

### 5. Cloud NAT y Private Google Access

- **Cloud NAT** regional en `europe-west1` y en `europe-west4` (un Router + un NAT por región). Logging `ERRORS_ONLY`.
- **PGA** habilitado por subnet (`privateIpGoogleAccess = true`). Permite a las VMs sin IP externa alcanzar GCS, Logging, Monitoring, etc. sin pasar por el NAT (y sin coste de egress).

### 6. IAM Shared VPC

- `roles/compute.xpnAdmin` otorgado al grupo `gcp-platform@` en `folders/prod` — pueden marcar hosts y attachar service projects.
- `roles/compute.networkAdmin` en `net-host-prod` para `gcp-platform@`.
- `roles/compute.networkUser` otorgado **a nivel de subnet** a los SAs y grupos de cada service project:
  - `checkout-prod` → `networkUser` sobre `europe-west1-primary` y `europe-west4-primary`.
  - `analytics-prod` → `networkUser` sólo sobre `europe-west4-primary` (donde vive el pipeline).

### 7. Firewall por SA, no por tag — justificación

Las reglas aquí usan `sourceServiceAccounts` / `targetServiceAccounts` en vez de `sourceTags` / `targetTags`. Razones:

- Cambiar el **tag** de una VM requiere `compute.instances.setTags` — un permiso que un developer con rol de operación básica puede tener.
- Cambiar la **SA** de una VM requiere además `iam.serviceAccountUser` **sobre esa SA específica** — binding IAM explícito, auditable, con contratos claros entre equipos.
- Un atacante que compromete una VM no puede "ponerse" la SA de otra; sólo puede usar la que ya tiene.
- En GCP la SA de la VM es la **identidad** que todo (IAM, firewall, logs) ve. Filtrar por ella alinea red con IAM.

## Consecuencias

### Positivas

- Platform opera **una sola red**; los equipos de aplicación crean VMs/MIGs pero no modifican subnets ni rutas.
- Compliance Europa está garantizada por la combinación de VPC regional (no hay subnets fuera de `europe-*`) + ausencia de peerings salvajes.
- Billing por workload sigue limpio: cada service project paga su compute; `net-host-prod` paga la red compartida.
- Firewall por SA es auditable y resistente a *tag squatting*.

### Negativas

- Coordinación requerida: cualquier cambio de red necesita a Platform. Mitigación: PR con revisión 24h SLA.
- Un bug en el host puede impactar a múltiples service projects. Mitigación: cambios con `terraform plan` revisado en PR, canary en `stg` antes de `prod`.
- Cloud NAT no es gratis — presupuestar con FinOps. Mitigación: PGA cubre el 80% del egress hacia Google (gratis).
- Alcance de la SA como filtro: si un servicio corre con una SA compartida con otro, la regla afecta a ambos. Mitigación: una SA por rol funcional, no por equipo.

## Alternativas descartadas

### Alt A: VPCs separadas por workload + VPC Peering

- Cada project tiene su propia VPC; se peerean dos a dos.
- **Por qué no**: multiplica la administración (una VPC por workload × por entorno), el peering no es transitivo, se duplican firewall rules y Cloud NATs. Billing de red se diluye. Sólo tiene sentido si hay un requisito legal **duro** de aislamiento de red entre workloads, que aquí no existe.

### Alt B: VPC `auto` con `/9` default

- Un `terraform apply` con `auto_create_subnetworks = true` y a correr.
- **Por qué no**: pierdes control del CIDR (solapes con on-prem si el día de mañana hay Interconnect), creas subnets en regiones que no quieres (`us-*`, `asia-*`) obligando a borrarlas, y no puedes planear secondary ranges para GKE. Sólo vale para un sandbox.

---

## Ejemplo de `firewall-rules.json` que cumple el validador

```json
[
  {
    "name": "allow-health-checks-to-app",
    "network": "projects/net-host-prod/global/networks/vpc-prod",
    "direction": "INGRESS",
    "priority": 1000,
    "sourceRanges": ["35.191.0.0/16", "130.211.0.0/22"],
    "targetServiceAccounts": ["app-sa@checkout-prod.iam.gserviceaccount.com"],
    "allowed": [{ "IPProtocol": "tcp", "ports": ["80", "443"] }]
  },
  {
    "name": "allow-app-to-db-5432",
    "network": "projects/net-host-prod/global/networks/vpc-prod",
    "direction": "INGRESS",
    "priority": 1000,
    "sourceServiceAccounts": ["app-sa@checkout-prod.iam.gserviceaccount.com"],
    "targetServiceAccounts": ["db-sa@checkout-prod.iam.gserviceaccount.com"],
    "allowed": [{ "IPProtocol": "tcp", "ports": ["5432"] }]
  },
  {
    "name": "allow-egress-google-apis",
    "network": "projects/net-host-prod/global/networks/vpc-prod",
    "direction": "EGRESS",
    "priority": 1000,
    "destinationRanges": ["199.36.153.4/30"],
    "allowed": [{ "IPProtocol": "tcp", "ports": ["443"] }]
  },
  {
    "name": "deny-all-egress-default",
    "network": "projects/net-host-prod/global/networks/vpc-prod",
    "direction": "EGRESS",
    "priority": 65534,
    "destinationRanges": ["0.0.0.0/0"],
    "denied": [{ "IPProtocol": "all" }]
  }
]
```

> El rango `199.36.153.4/30` corresponde a `restricted.googleapis.com` (ver docs oficiales de Private Google Access).
