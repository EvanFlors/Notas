# ADR 001 — Estructura de Management Groups y Landing Zone en Azure

> Documento de referencia para autoevaluación de la actividad `az-09-01`.
> No es la única solución válida; es una solución **razonada y completa**.

## Estado

Aceptado (propuesto para implementación en Fase 4 con AVM ALZ Terraform).

## Contexto

Tras un año operando en una **única subscription Azure** compartida entre `checkout` (API crítica, procesa pagos, SLA 99.9%, PCI-light) y `analytics` (Databricks + Power BI, no toca datos de pago, horario laboral), los problemas son concretos:

- Un `terraform apply` en `analytics` tocó por error una NSG que afectaba a `checkout` — blast-radius compartido.
- Finance no puede saber cuánto cuesta `checkout` vs `analytics`: una sola invoice.
- Security no tiene un sink único de logs; los diagnostic settings están configurados ad-hoc por recurso.
- Los developers crearon una VM GPU en "pruebas" que costó 400 EUR en un fin de semana sin alertas.

Constraints:

- Todas las cargas deben vivir en **`westeurope`** y **`northeurope`** (compliance EU, PCI-light exige datos en UE).
- La org tiene **Microsoft Entra ID P2** (bundle Office 365 E5), por lo que **PIM** está disponible y es gratuito para la org.
- No hay ExpressRoute aún; Private Endpoints es el mecanismo para proteger datos de `checkout` por ahora.
- El equipo plataforma son 2 personas; el gobierno debe ser **declarativo y versionable** (policies as code), no clics manuales.

## Decisión

Adoptamos la jerarquía **CAF Enterprise Scale Landing Zone** (ALZ) adaptada a nuestro tamaño, con **Management Groups** como eje de policies y **PIM** para elevaciones JIT.

### Jerarquía de Management Groups

```
Tenant Root Group                                   (sin assignments propias)
└── contoso                                          (Intermediate Root MG)
    ├── Platform
    │   ├── Identity                                 (sub: identity-prod)
    │   ├── Management                               (sub: management-prod)
    │   └── Connectivity                             (sub: connectivity-prod)
    ├── Landing Zones
    │   ├── Corp                                     (checkout aquí — Private Endpoints)
    │   │   ├── sub: corp-checkout-dev
    │   │   ├── sub: corp-checkout-stg
    │   │   └── sub: corp-checkout-prod
    │   └── Online                                   (analytics aquí — accesible internet)
    │       ├── sub: online-analytics-dev
    │       └── sub: online-analytics-prod
    ├── Sandbox
    │   └── sub: sandbox-shared                      (una compartida inicialmente)
    └── Decommissioned                               (vacío al arrancar)
```

### Subscriptions

| Subscription | MG parent | Propósito |
|--------------|-----------|-----------|
| `identity-prod` | `Platform/Identity` | Entra Connect, DCs (reservada; no hay DCs aún). |
| `management-prod` | `Platform/Management` | Log Analytics workspace central, Automation, Backup. |
| `connectivity-prod` | `Platform/Connectivity` | Hub VNet, Private DNS Zones centralizadas. **No Azure Firewall** (costo). |
| `corp-checkout-dev` | `Landing Zones/Corp` | Dev de `checkout`. |
| `corp-checkout-stg` | `Landing Zones/Corp` | Staging de `checkout`. |
| `corp-checkout-prod` | `Landing Zones/Corp` | Producción de `checkout` (PCI-light). |
| `online-analytics-dev` | `Landing Zones/Online` | Dev de `analytics`. |
| `online-analytics-prod` | `Landing Zones/Online` | Producción de `analytics`. |
| `sandbox-shared` | `Sandbox` | Experimentación. Budget duro 200 EUR/mes. |

**No usamos IDs reales de subscription aquí**; se asignarán en Fase 4 durante *Subscription Vending*.

### Azure Policies (baseline)

| Policy | Efecto | Asignado en | Justificación |
|--------|--------|-------------|---------------|
| `deny-locations` | `deny` | `contoso` (Intermediate Root) | Compliance EU. Permite `westeurope`, `northeurope` y `global`. |
| `require-tags` (`env`, `owner`, `cost-center`) | `deny` | `contoso` | Billing analytics por tag; sin tags, el reporte Finance es inútil. |
| `audit-diagnostic-settings` | `auditIfNotExists` | `contoso` | Marcar non-compliance de cualquier recurso sin logs → LA central. |
| `deny-public-ip` | `deny` | `Landing Zones/Corp` | Fuerza Private Endpoints en `checkout`; superficie reducida. |
| `deny-rdp-from-internet` | `deny` | `Landing Zones` | NSG que permite 3389/22 desde 0.0.0.0/0 → bloqueado. |
| `require-waf` | `audit` → `deny` fase 2 | `Landing Zones/Online` | App Gateways sin WAF marcados; en fase 2 pasa a `deny`. |
| `deny-non-spot-vms` | `deny` | `Sandbox` | Solo Spot VMs en sandbox (ahorro). |
| `allowed-sku-sizes` (sin GPU, max 8 vCPU) | `deny` | `Sandbox` | Evita que developer arranque NC-series por error. |
| `enforce-decommissioned` | `deny *` | `Decommissioned` | Subs en cierre: nada se puede crear/modificar. |

### Role assignments con PIM

| Grupo (Entra ID) | Rol | Scope | PIM eligible? | Comentario |
|------------------|-----|-------|---------------|------------|
| `azure-security-auditors` | `Reader` | `contoso` (Intermediate Root) | Active | Security necesita leer todo. |
| `azure-platform-admins` | `Owner` | `Platform` | **Eligible** (max 4h, approval requerido) | Operaciones de plataforma elevadas vía PIM. |
| `azure-platform-admins` | `Reader` | `contoso` | Active | Visibilidad base siempre activa. |
| `azure-network-admins` | `Network Contributor` | `Platform/Connectivity` | Active | Operan el hub día a día. |
| `checkout-developers` | `Contributor` | `corp-checkout-dev` | Active | Dev libre. |
| `checkout-developers` | `Contributor` | `corp-checkout-stg` | **Eligible** (max 2h) | Staging requiere elevación. |
| `checkout-developers` | `Reader` | `corp-checkout-prod` | Active | Lectura siempre. |
| `checkout-developers` | `Contributor` | `corp-checkout-prod` | **Eligible** (max 1h, approval 2 personas, MFA) | Deploys a prod requieren approval. |
| `analytics-developers` | `Contributor` | `online-analytics-dev`, `online-analytics-prod` | Active | Workload no crítico, trade-off velocidad. |
| `break-glass-prod` | `Owner` | `corp-checkout-prod`, `online-analytics-prod` | Active (cuenta sellada, MFA, alerta) | Emergencia. |
| `developers-all` | `Contributor` | `sandbox-shared` | Active | Sandbox libre con budget. |

### Patrón por workload

- **`checkout`** = **N subscriptions** (`dev`, `stg`, `prod`). Justificación:
  - Blast-radius por entorno (crítico para PCI-light).
  - Policies más estrictas en `prod` (gracias a MG parent `Corp`).
  - PIM eligible para prod con approval.
  - Billing por entorno sin agregación compleja.

- **`analytics`** = **2 subscriptions** (`dev`, `prod`). Justificación:
  - No procesa pagos; blast-radius es menor.
  - Un entorno dev + un prod cubre el ciclo (sin stg porque el equipo es 1 persona).
  - Policies `Online` menos restrictivas (puede tener Public IPs con WAF).

## Consecuencias

### Positivas

- **Blast-radius por subscription**: un deploy roto en `corp-checkout-dev` no toca `prod`.
- **Policies declarativas**: todo el baseline vive en Git (EPAC en fase 2); auditable y versionable.
- **PIM activo**: nadie es `Owner` permanente en prod; cada elevación queda logged y approved.
- **Billing claro**: `tags` + subscription como primer eje; Finance puede filtrar por workload y entorno.
- **CAF ALZ compliance**: cuando crezcamos, podemos onboarding con el tooling oficial (AVM, Bicep).
- **Compliance EU** garantizada por `deny-locations` desde el día 1.

### Negativas

- **9 subscriptions** vs **1 actual**: más overhead administrativo. Mitigación: *Subscription Vending* en fase 2.
- **PIM añade fricción** a los deploys de prod (approvals, MFA, TTL). Compensación: menor riesgo.
- **Jerarquía fija**: cambiar `checkout` de `Corp` a `Online` (si evoluciona a API pública) requiere mover la sub de MG — fácil pero cambia las policies efectivas al instante (hay que probarlo).
- **Platform/Identity y Platform/Connectivity vacías de recursos útiles al principio**: pagamos la estructura "por adelantado". A cambio, no tenemos que refactorizar cuando crezcamos.

## Alternativas descartadas

### Alternativa 1 — Jerarquía plana (todas las subs bajo `contoso`)

Pros: simple. Cons: imposible asignar policies distintas a `Corp` (checkout) vs `Online` (analytics) sin repetir assignments por sub. No alineado con CAF — perdemos el tooling oficial. **Descartada**: la asimetría de policies entre workload crítico y workload interno es el principal valor de la jerarquía.

### Alternativa 2 — Una subscription por app (checkout y analytics en una sub cada una)

Pros: menos subs (menos overhead). Cons: perdemos blast-radius entre entornos; un deploy roto en `checkout-dev` puede afectar `checkout-prod` si comparten RG o VNet. Para `checkout` (PCI-light) es inaceptable. **Descartada** para `checkout`; **aceptada parcialmente** para apps internas pequeñas en fase 2 (sub `internal-tools-prod`).

### Alternativa 3 — AWS-style "una app = una cuenta pagadora" (billing scope == MG scope)

En Azure esta alternativa **ni siquiera es posible**: billing y governance son ortogonales (EA/MCA Billing Account vs MG). **Descartada** por diseño del cloud. Documentamos aquí la diferencia con AWS para evitar que alguien lo intente.

### Alternativa 4 — Blueprints en lugar de policies individuales

Microsoft retira **Azure Blueprints el 11 de julio de 2026**. **Descartada** por deprecación; usaremos **Azure Policy** + **Deployment Stacks** (en fase 2).

## Fase 2 (planificado, no implementado aún)

- Introducir `Landing Zones/Corp/critical` para workloads tier-1 (checkout) y `Landing Zones/Corp/internal` para apps internas → policies distintas por tier.
- Enroll **EPAC** (Enterprise Policy as Code) para gestionar policies desde Git con pipelines.
- Deploy **Azure Firewall** en `connectivity-prod` cuando volúmenes de egress lo justifiquen (hoy, ~900 EUR/mes fijos son prohibitivos).
- **Subscription Vending** automatizado para crear subs nuevas con governance aplicado.
- Enroll de `Microsoft Defender for Cloud` Plan 2 selectivo (Key Vault, Storage, SQL de `checkout-prod`).

---

**Nota de autoevaluación**: tu ADR no tiene por qué ser idéntico a este. Debe:
- Tener las 6 secciones (Estado, Contexto, Decisión, Consecuencias, Alternativas + título ADR).
- Mencionar MGs, Entra ID, PIM, CAF/ALZ/Enterprise Scale, Europa, los 2 workloads.
- Nombrar >= 4 subscriptions, >= 3 Azure Policies del baseline, >= 3 roles del catálogo built-in.
- Decidir explícitamente el patrón por workload para `checkout` y `analytics`.
- Listar al menos 2 alternativas descartadas.
