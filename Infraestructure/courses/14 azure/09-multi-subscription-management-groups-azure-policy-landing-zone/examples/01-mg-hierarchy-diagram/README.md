# Ejemplo 01 — Jerarquía de Management Groups (CAF ALZ)

> Lectura y análisis. Sin ejecución. Objetivo: entender la jerarquía canónica de **CAF Enterprise Scale** y por qué cada MG existe.

## 1. El árbol completo

```
Tenant Root Group                                   (gestionado por Azure)
└── contoso                                          (Intermediate Root MG)
    ├── Platform
    │   ├── Identity                                 (sub: identity-prod)
    │   ├── Management                               (sub: mgmt-prod)
    │   └── Connectivity                             (sub: connectivity-prod)
    ├── Landing Zones
    │   ├── Corp
    │   │   ├── sub: corp-checkout-dev
    │   │   ├── sub: corp-checkout-stg
    │   │   └── sub: corp-checkout-prod
    │   └── Online
    │       ├── sub: online-analytics-dev
    │       └── sub: online-analytics-prod
    ├── Sandbox
    │   ├── sub: sandbox-alice
    │   └── sub: sandbox-bob
    └── Decommissioned
        └── sub: legacy-crm-closing
```

## 2. Por qué cada MG existe

| MG | Rol | Policies típicas | Role assignments típicos |
|----|-----|------------------|--------------------------|
| **Tenant Root Group** | Raíz lógica, inmutable. | **Solo** las absolutamente globales (muy pocas o ninguna). | Ninguna (ni Owner ni Contributor). |
| **contoso (Intermediate)** | Punto único de aplicación para toda la org. | `deny-locations` (whitelist UE), `require-tags` básicos. | `Reader` para `security-auditors`. |
| **Platform** | Opera la plataforma (red, logs, identidad). | Permite publicar hub networking, Log Analytics; policies restrictivas sobre cambios no autorizados. | `Owner` eligible (PIM) para `platform-admins`. |
| **Platform / Identity** | Entra Connect, DCs. | Policies específicas de identidad (deny de local admins). | `Owner` solo para `identity-admins`. |
| **Platform / Management** | Log Analytics centralizado, Automation, Backup. | Protección de recursos de logging (`deny delete` por policy). | `Reader` para toda la org, `Contributor` solo para `platform-admins`. |
| **Platform / Connectivity** | Hub VNet, Azure Firewall, Private DNS, ExpressRoute/VPN. | `deny` de hubs duplicados, policies de network peering. | `Network Contributor` para `network-admins`. |
| **Landing Zones** | Nodo intermedio para policies comunes a todas las LZ. | `deny-public-ip` (en Corp), `audit-diagnostic-settings`. | — |
| **Landing Zones / Corp** | Workloads internos; conectividad corporativa vía hub. | `deny-public-ip` (fuerza ExpressRoute/App Gateway + Private Endpoints). | `Contributor` para equipos de producto, scoped a sub. |
| **Landing Zones / Online** | Workloads expuestos a internet (sin red corporativa). | Policies más laxas en red; `require-waf` para expuestos. | `Contributor` para equipos de producto. |
| **Sandbox** | Experimentación. | `allowed-sku-size` (sin GPUs ni VMs grandes); `require-budget-alert`. | `Contributor` para cualquier developer, scoped a su sub. |
| **Decommissioned** | Subs en proceso de cierre. | `deny *` por policy (nada se puede crear/modificar). | `Reader` solamente. |

## 3. Trampas comunes al diseñar la jerarquía

1. **Asignar policies al Tenant Root Group**. Si lo haces, cualquier futuro tenant guest o sub externa heredará esas policies. Siempre operar desde un `Intermediate Root` propio.
2. **Mezclar Platform y Landing Zones bajo un mismo padre operativo**. Si el equipo de producto tiene `Contributor` en `Landing Zones` y accidentalmente el role se hereda a `Platform/Connectivity`, puede modificar el hub VNet. Separar como ramas hermanas evita esto.
3. **Sandbox sin budget**. Un developer que arranca una NC24ads A100 v4 (~27 USD/hora) en sandbox puede quemar el presupuesto mensual en una noche. Policy `require-budget-alert` + alerting activo es obligatorio.
4. **Olvidar `Decommissioned`**. Las subs cerradas en Azure tardan 30-90 días. Durante ese tiempo pueden seguir siendo manipuladas si no las mueves bajo `Decommissioned` con `deny-all`.

## 4. Mapping a AWS Organizations

| AWS Organizations | Azure CAF ALZ |
|-------------------|---------------|
| Management account | Billing Account (ortogonal) + sub-mgmt-prod |
| OU Security | MG `Platform/Management` + MG `Platform/Identity` |
| OU Infrastructure/network | MG `Platform/Connectivity` |
| OU Workloads/dev-stg-prod | MG `Landing Zones/Corp` o `Online` con 1 sub por entorno |
| OU Sandbox | MG `Sandbox` |
| OU Suspended | MG `Decommissioned` |

**Diferencias importantes**:

- En AWS, la **management account** paga y gobierna; en Azure, **gobierno y billing están separados** (MG + Billing Account distintos).
- AWS "una cuenta = un blast-radius" ≈ Azure "una subscription = un blast-radius de quotas y billing" (no de red; VNets pueden hacer peering cross-sub).

## 5. Qué llevarse

- La jerarquía CAF ALZ es **convención, no obligación** — pero adoptarla te ahorra decisiones triviales y es compatible con el tooling oficial (ALZ Bicep/Terraform, Policy as Code templates).
- `Platform` y `Landing Zones` **siempre** como ramas hermanas. Nunca anidadas.
- `Sandbox` y `Decommissioned` casi siempre valen la pena, incluso en orgs pequeñas.
