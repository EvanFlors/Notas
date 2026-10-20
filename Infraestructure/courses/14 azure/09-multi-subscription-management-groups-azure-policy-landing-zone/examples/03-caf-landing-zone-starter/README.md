# Ejemplo 03 — CAF Enterprise Scale Landing Zone (starter)

> Lectura y análisis. Sin ejecución. Objetivo: entender qué entrega la **reference implementation** CAF ES ALZ cuando la despliegas, y qué decisiones toma por ti.

## 1. ¿Qué es la reference implementation?

**CAF ES ALZ** (Cloud Adoption Framework — Enterprise Scale Architecture, Landing Zone) es un **conjunto de templates oficiales de Microsoft** que, al desplegarse en un tenant limpio, dejan la plataforma lista para que los equipos empiecen a aterrizar workloads **el día uno**. No es un servicio; son plantillas (**Bicep**, **Terraform via AVM**, o portal "Start with Enterprise-Scale").

Entrega:

1. Una **jerarquía de MGs** completa (como en `examples/01`).
2. **Policies e initiatives** canónicas asignadas a cada MG.
3. Subscriptions de **Platform** bootstrapeadas (opcional) con los recursos de hub.
4. **Role assignments** base por MG.
5. Hooks para **Deployment Stacks** y **EPAC** si quieres gestionar policies como código.

## 2. Jerarquía de MGs que crea

Idéntica al patrón del `examples/01`:

```
Tenant Root Group
└── <intermediate-root>              (nombre que eliges, p.ej. "contoso")
    ├── Platform
    │   ├── Identity
    │   ├── Management
    │   └── Connectivity
    ├── Landing Zones
    │   ├── Corp
    │   └── Online
    ├── Sandbox
    └── Decommissioned
```

## 3. Initiatives y policies que asigna (resumen)

CAF ES ALZ asigna una **initiative** por MG mayor. Cada initiative agrupa decenas de policies. Tabla sintetizada:

| MG | Initiative | Qué cubre (muestra) |
|----|------------|---------------------|
| `<intermediate-root>` | `Enforce-ALZ-Decomm` + `Deploy-Diag-LogAnalytics` | diagnostic settings → LA central, baseline de tagging. |
| `Platform` | `Enforce-ALZ-Sandbox` **no**, `Deploy-ASC-Monitoring` | Defender for Cloud + sinks a LA. |
| `Platform/Connectivity` | `Enforce-DDoS-VNET` | DDoS Standard en VNets. |
| `Platform/Identity` | `Deploy-ASC-SecurityContacts` | contactos de seguridad configurados. |
| `Platform/Management` | `Deploy-Log-Analytics` | sku, retention, access policies de LA. |
| `Landing Zones` | `Deny-PublicIP`, `Deny-RDP-From-Internet`, `Deploy-MDFC-Config` | superficie restringida; Defender habilitado. |
| `Landing Zones/Corp` | `Deny-PublicEndpoints`, `Deny-Public-IP` (más estrictas) | fuerza Private Endpoints en Storage/KV/SQL. |
| `Landing Zones/Online` | menos estrictas en red; `Require-WAF` para App Gateway. | permite public endpoints pero exige WAF. |
| `Sandbox` | `Deny-Non-Spot-VMs`, `Deny-Large-VM-Sizes` | solo VMs baratas; evita quemar budget. |
| `Decommissioned` | `Enforce-ALZ-Decomm` | `deny *` efectivo. |

Nota: los nombres exactos de initiatives cambian entre versiones del ALZ; verifica contra `github.com/Azure/Enterprise-Scale` o `github.com/Azure/ALZ-Bicep` al desplegar.

## 4. Subscriptions "platform" que bootstrapea

En el flujo portal/Bicep, ALZ puede crear o aceptar como input:

- **`identity` subscription**: Entra Connect servers, Domain Controllers, Azure AD DS si aplica.
- **`management` subscription**: Log Analytics workspace central, Automation Account, Backup Vault, Monitor Workbooks.
- **`connectivity` subscription**: Hub VNet, Azure Firewall (opcional, el componente más caro), Private DNS Zones centralizadas, ExpressRoute Gateway o VPN Gateway.

Las subscriptions de **Landing Zones** no se crean automáticamente (son el "lienzo" para los equipos de producto). ALZ provee un flujo de **Subscription Vending** vía Bicep/Terraform para crear nuevas subs con governance aplicado.

## 5. Role assignments iniciales

Por defecto, ALZ asigna:

- `Reader` del `Tenant Root Group` a un grupo `AzureSecurityAuditors` (si existe).
- `Owner` del `Platform` MG a un grupo `AzurePlatformAdmins` (recomendado via PIM, eligible).
- `Owner` del `Landing Zones` MG a `AzureLandingZoneAdmins` para onboarding de nuevas subs.
- `Contributor` scoped a cada sub de LZ para el equipo de producto correspondiente (via *Subscription Vending*).

**Importante**: ALZ no gestiona usuarios ni grupos; **tú** debes tenerlos creados en Entra ID antes del deploy.

## 6. Qué cuesta desplegar ALZ

| Componente | Costo mensual aprox (orientativo 2026) |
|------------|----------------------------------------|
| MGs + Azure Policy engine | 0 USD |
| Log Analytics (ingesta baja, <5 GB/día) | ~15–40 USD |
| Automation Account (uso bajo) | <5 USD |
| Private DNS Zones (~10 zonas) | <2 USD |
| **Azure Firewall Standard** | **~900 USD** fijo + egress |
| **Azure Firewall Premium** | **~1400 USD** fijo + egress |
| ExpressRoute Gateway (si aplica) | ~140–400 USD según SKU |
| DDoS Standard (opcional) | ~2944 USD/mes (plan compartido entre VNets) |
| Defender for Cloud (Plan 2 selectivo) | depende de recursos; de 0 a cientos USD |

**Realidad práctica**: para una org pequeña (3–5 subs activas), si **omites Azure Firewall y DDoS Standard**, ALZ cuesta <100 USD/mes. Si los incluyes, el piso real son ~1000 USD/mes.

Para este módulo (az-09) y Fase 1-3 del programa, **no despliegues ALZ en un tenant real**. Es un ejercicio de diseño en papel.

## 7. Cómo desplegarlo (en Fase 4, no aquí)

Tres caminos oficiales en 2026:

1. **Portal — "Enterprise-Scale Landing Zones" wizard**: GUI, ideal para primer acercamiento. Lee los parámetros, elige el ámbito, deploy.
2. **Bicep** desde `github.com/Azure/ALZ-Bicep`: control fino, orchestración por módulos, soporte oficial Microsoft.
3. **Terraform** vía **Azure Verified Modules (AVM)**: `avm/ptn/alz`. Recomendado hoy (2026) si el equipo trabaja con Terraform.

**Deprecación relevante**: `caf-terraform-landingzones` (el repo histórico) sigue vigente pero AVM es el camino forward. **Azure Blueprints** se retira el **11 de julio de 2026**; cualquier deploy nuevo debe usar **Deployment Stacks**.

## 8. Qué llevarse

- ALZ es **la receta oficial**, no la única. Permite arrancar en días en lugar de meses.
- **Platform ≠ Landing Zones**. Policies, role assignments y hasta billing responsables separados.
- Azure Firewall es el **gran decisor de costo**: si lo incluyes, ALZ pasa de "docenas de USD" a "miles de USD" mensuales.
- En este módulo **no se despliega**. Se diseña y se escribe el ADR. Fase 4 lo materializa con Terraform/Bicep.
