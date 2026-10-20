# az-09 — Lección: multi-subscription con MGs, Azure Policy y CAF Landing Zone

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `az-01`, `az-02`, `az-03`.

---

## 1. Por qué multi-subscription y no "una sola bien pintada"

El error de arranque más común en Azure es montar **todo** en una única subscription y "separar" entornos con prefijos de Resource Group o con tags. Funciona hasta que:

1. Un desarrollador borra por error un Storage Account de producción porque el RBAC es "flexible".
2. Las **quotas** por subscription (cores por región, Public IPs, VNets, Storage Accounts) empiezan a estrangular.
3. La factura es un único invoice y nadie sabe cuánto cuesta *dev* vs *prod* por workload.
4. Compliance pide aislamiento duro entre workloads regulados y no regulados.

En Azure, la **subscription** es el **límite de aislamiento operacional**: contiene quotas, policies heredadas y es la unidad natural de billing. El equivalente conceptual del "AWS account como blast-radius" es la **subscription** (no el Resource Group, que es solo una carpeta lógica dentro de una subscription).

> **Idea clave:** la subscription es el límite duro de billing y quotas. Los **Management Groups** son el techo (lo que **ninguna** subscription puede saltarse vía policy). **Entra ID + RBAC + PIM** son la puerta (cómo entran los humanos).

---

## 2. Jerarquía Azure: tenant, MG, subscription, RG, resource

Recordatorio de `az-01`, afinado para gobernanza:

```
      ┌───────────────────────────────┐
      │   Microsoft Entra ID tenant   │   ← identidad; 1 por organización
      │   (ex Azure AD)                │
      └──────────────┬────────────────┘
                     │
             ┌───────▼────────┐
             │ Tenant Root MG │   ← creado por Azure; NO hospedar workloads
             └───────┬────────┘
         ┌───────────┼───────────┬──────────────┐
         ▼           ▼           ▼              ▼
      ┌────┐     ┌──────┐    ┌──────┐      ┌──────────┐
      │ MG │     │  MG  │    │  MG  │      │    MG    │
      │Plat│     │ LZ   │    │Sandbx│      │Decommiss.│
      └─┬──┘     └──┬───┘    └──┬───┘      └────┬─────┘
        │           │           │               │
        ▼           ▼           ▼               ▼
   sub-mgmt    sub-corp-   sub-sandbox-   subs a dar
   sub-ident   prod        <user>         de baja
   sub-conn    sub-online-
               dev/prod
```

Conceptos clave:

- **Tenant Root Group**: nodo raíz lógico del tenant, inmutable, creado por Azure. **Regla de oro**: no asignes policies ni role assignments aquí salvo las absolutamente globales (p. ej. *deny de locations prohibidos a nivel organización*). Si asignas un `Owner` aquí, es `Owner` de todo el tenant.
- **Management Group (MG)**: carpeta jerárquica que agrupa MGs hijos y subscriptions. Soft-limit de **6 niveles** de profundidad (sin contar Tenant Root ni la subscription). Las **Azure Policies** y los **role assignments** se asignan a MGs y **heredan hacia abajo**.
- **Subscription**: límite de quotas, de billing y de policies heredadas efectivas. Una subscription vive **debajo** de exactamente un MG en cada momento (puede moverse).
- **Resource Group (RG)**: carpeta dentro de la subscription. Unidad de deploy y de **eliminación en cascada** (`az group delete` borra todo). No es un límite de seguridad; es un límite operacional.
- **Billing scope ≠ MG scope**. El **Billing Account** (EA/MCA) agrupa subscriptions para facturación; es ortogonal a la jerarquía de MGs. Una misma subscription aparece bajo un MG (gobernanza) y bajo una Billing Account (dinero).

> **Trampa habitual**: pensar que "mi RG es como una cuenta AWS". No lo es. El equivalente de la cuenta AWS a nivel de aislamiento es la **subscription**. El RG es *dentro de* la subscription.

---

## 3. Management Groups: diseño de la jerarquía (patrón CAF ALZ)

La jerarquía de MGs no es decoración: es **el eje sobre el que se cuelgan policies y role assignments**. El patrón recomendado por el **Cloud Adoption Framework (CAF) — Enterprise Scale Landing Zone (ES ALZ)** es:

```
Tenant Root Group
└── Intermediate Root MG (p. ej. "contoso")
    ├── Platform
    │   ├── Identity          (sub de identidad: Entra Connect, Domain Controllers)
    │   ├── Management        (sub de observabilidad: Log Analytics, Automation)
    │   └── Connectivity      (sub de red: hub VNet, Azure Firewall, ExpressRoute)
    ├── Landing Zones
    │   ├── Corp              (workloads internos, requieren conectividad corporativa)
    │   │   ├── workload-A-prod
    │   │   └── workload-A-dev
    │   └── Online            (workloads expuestos a internet, no requieren conect. corp.)
    │       ├── workload-B-prod
    │       └── workload-B-dev
    ├── Sandbox               (experimentación; policies laxas; budget duro)
    │   └── sandbox-<user>
    └── Decommissioned        (subs a dar de baja; policy deny-all)
```

Reglas de pulgar:

- **`Intermediate Root`** debajo del Tenant Root. Permite aplicar policies a toda la org **sin tocar el Tenant Root** (que afectaría a cualquier futuro tenant guest o a subs no empresariales).
- **`Platform` separado de `Landing Zones`**. La plataforma la opera el equipo central (SRE/Platform); las landing zones las consumen los equipos de producto. Policies distintas: la plataforma necesita permisos para operar red/logs; las LZ no deberían poder crear hubs de red.
- **`Corp` vs `Online`**. Corp necesita conectividad hacia on-premise (ExpressRoute, Hub VNet); Online no. Separarlos permite policies de red distintas (p. ej. deny de Public IP en Corp, allow en Online).
- **`Sandbox`** aislado, con **budget alerts duros** y policies laxas para experimentar. Una NC24ads A100 v4 (GPU) sin querer cuesta ~27 USD/hora.
- **`Decommissioned`** con `Deny *` por policy para subs en proceso de cierre (en Azure, cerrar una subscription tarda 30-90 días).

Alternativa: **jerarquía plana** (`Root → MG único → todas las subscriptions`). Útil solo en orgs muy pequeñas con un único equipo. Pierdes el aislamiento Platform/LZ y la asimetría de policies por entorno.

---

## 4. Azure Policy: el techo declarativo

Una **Azure Policy** (concretamente, un `policyDefinition`) es una regla declarativa en JSON **asignada a un MG, subscription o RG** que **evalúa recursos** contra una condición y aplica un **efecto**. Reglas conceptuales:

1. **La policy es un techo o un detective, no un `Allow`.** Los efectos "preventivos" (`deny`, `modify`, `append`) bloquean o transforman la creación/update del recurso. Los efectos "detectivos" (`audit`, `auditIfNotExists`) solo marcan non-compliance (sin bloquear). Los "autoremediadores" (`deployIfNotExists`, `modify`) corrigen.
2. **La evaluación es en el momento de la operación ARM.** Un `PUT /subscriptions/.../resourceGroups/.../providers/.../resource` dispara la evaluación. También hay un barrido periódico ("compliance scan", ~24h) sobre el estado existente.
3. **Herencia descendente**: una policy asignada a un MG se evalúa en todas las subscriptions descendientes. Las asignaciones son **acumulativas**: un recurso en una sub de `Corp` evalúa las policies asignadas a `Tenant Root`, `Intermediate Root`, `Landing Zones`, `Corp` y la subscription — todas al mismo tiempo.
4. **`deny` es inapelable.** No hay `role assignment` que lo salve. Ni siquiera `Owner`. Esto es lo que la hace útil como guardrail (equivalente conceptual del `Deny` en una SCP de AWS).
5. **El motor de policies es `Allow` por defecto en ausencia de policy.** Es decir: Azure no es "deny-list first" como SCPs; se parte de que todo está permitido salvo que una policy diga lo contrario. Es el modelo opuesto al de allow-list.

**Baseline mínimo recomendado** (lo trabajas en la actividad 02):

| Policy | Efecto | Qué hace | Por qué |
|--------|--------|----------|---------|
| `policy-deny-locations` | `deny` | Impide crear recursos fuera de regiones permitidas. | Compliance (datos deben vivir en UE), control de superficie y de costo. |
| `policy-deny-public-ip` | `deny` | Impide crear `Microsoft.Network/publicIPAddresses` en MGs sensibles. | Reduce superficie de exposición; fuerza Private Endpoints + Front Door/App Gateway. |
| `policy-audit-diagnostic-settings` | `auditIfNotExists` | Marca non-compliant cualquier recurso sin diagnostic settings hacia Log Analytics. | Protege la auditoría: si no se envían logs a LA, no hay trazabilidad. |

Otros frecuentes: `require-tags` (require un tag `env` y `owner`), `allowed-sku-size` (en sandbox), `deny-nsg-rdp-from-internet`, `deployIfNotExists` para Microsoft Defender for Cloud en cualquier sub nueva.

> **Prueba mental antes de asignar una policy con efecto `deny`**: "¿esto bloquea algo que el equipo necesita hacer legítimamente ahora mismo?". Una policy que paraliza un deploy a producción un lunes a las 09:00 es peor que no tener policy.

---

## 5. Azure Policy: anatomía JSON

Esqueleto mínimo de un `policyDefinition`:

```json
{
  "properties": {
    "displayName": "Deny resources outside allowed locations",
    "policyType": "Custom",
    "mode": "All",
    "description": "Deny creation of any resource outside the allowed Azure regions.",
    "metadata": {
      "category": "General",
      "version": "1.0.0"
    },
    "parameters": {
      "allowedLocations": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed locations",
          "strongType": "location"
        },
        "defaultValue": ["westeurope", "northeurope"]
      }
    },
    "policyRule": {
      "if": {
        "allOf": [
          { "field": "location", "notIn": "[parameters('allowedLocations')]" },
          { "field": "location", "notEquals": "global" },
          { "field": "type", "notEquals": "Microsoft.AzureActiveDirectory/b2cDirectories" }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
```

Elementos:

- **`properties.policyType`**: `Custom` (lo que escribes tú), `BuiltIn` (lo que trae Azure) o `Static` (compliance regulatorio).
- **`properties.mode`**: `All` (todos los tipos de recurso) o `Indexed` (solo recursos con tags y location). Usa `All` salvo que tengas razón para lo contrario.
- **`properties.parameters`**: parámetros expuestos a la asignación. Permite reutilizar una misma definición con distintos valores (p. ej. regiones permitidas por MG).
- **`properties.policyRule.if`**: condición booleana. Operadores: `allOf`, `anyOf`, `not`, `field`, `value`, `exists`, `equals`, `notEquals`, `in`, `notIn`, `like`, `match`, `greaterOrEquals`, etc.
- **`properties.policyRule.then.effect`**: `audit`, `deny`, `append`, `modify`, `deployIfNotExists`, `auditIfNotExists`, `disabled`.
- **`[parameters('x')]`**: expresión ARM. Permite inyectar el parámetro en la regla.

Dos sutilezas importantes:

1. **`location notEquals "global"`**: muchos recursos (Front Door, DNS zones, Traffic Manager, roles) tienen `location = "global"`. Si no exceptúas `"global"`, tu `deny-locations` romperá la creación de cualquier recurso global.
2. **`field` vs `value`**. `field` referencia una propiedad del recurso bajo evaluación (`type`, `location`, `tags.env`, `kind`, `Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly`). `value` evalúa una expresión. Son operadores distintos; mezclarlos es la fuente #1 de policies rotas.

Efectos avanzados que vale conocer:

- **`deployIfNotExists` (DINE)**: si el recurso no cumple y falta un recurso relacionado, Azure despliega automáticamente ese recurso faltante usando una Managed Identity que configura la assignment. Ejemplo: *si una VM no tiene Microsoft Defender for Servers agent, instalarlo*. Potente, requiere `roleDefinitionIds` en la assignment.
- **`modify`**: añade/quita/actualiza tags o alias de propiedades sin bloquear la operación. Ejemplo: *añadir `tag.env=prod` a cualquier recurso en la sub de prod*.
- **`append`**: añade propiedades/tags a la **creación** (no a updates). Más limitado que `modify`.

---

## 6. Initiatives (Policy Sets): agrupar policies

Una **initiative** (`policySetDefinition`) es un **grupo de policyDefinitions** asignadas juntas con parámetros compartidos. Es el equivalente a un "paquete de guardrails".

Ejemplos de initiatives built-in que vienen con Azure:

- **Azure Security Benchmark** (`1f3afdf9-...`): ~250 policies alineadas con el benchmark de Microsoft, cubre todo (red, storage, IAM, key vault).
- **CIS Microsoft Azure Foundations Benchmark v2.0**: alineado con CIS.
- **ISO 27001:2013**, **PCI-DSS v4.0**, **NIST SP 800-53 Rev. 5**, **HIPAA HITRUST**.
- **Deploy Microsoft Defender for Cloud configuration**: habilita Defender en todas las subs del scope.

En **CAF Enterprise Scale**, Microsoft entrega una initiative llamada **Enterprise Scale Policies** con todas las policies canónicas del CAF (deny public IP en Corp, require diagnostic settings, etc.), asignadas automáticamente a los MGs correspondientes por la *reference implementation*.

**Trade-off**: asignar initiatives completas es cómodo pero puede inundarte de non-compliance irrelevante. Un patrón pragmático: empezar con una initiative custom pequeña (5-10 policies) + ir añadiendo built-in a medida que madura el gobierno.

---

## 7. CAF Enterprise Scale Landing Zone: la "receta oficial"

**CAF ES ALZ** es la **reference implementation** oficial de Microsoft para una landing zone empresarial. Entrega:

- Una jerarquía de MGs completa (la del §3).
- ~60–80 Azure Policies agrupadas en **~5 initiatives** (una por MG mayor: `Platform`, `Corp`, `Online`, `Sandbox`, `Decommissioned`).
- Subscriptions de **Platform** bootstrapeadas con los recursos de hub (Log Analytics, Automation, Azure Firewall, Hub VNet, Private DNS Zones centralizadas).
- **Role assignments** base por MG (p. ej. `Platform Operator` en `Platform`; `Landing Zone Contributor` en `Landing Zones`).

**Cómo se despliega**:

- **Portal "Start with Enterprise-Scale"** desde Microsoft Entra Admin Center.
- **Bicep** desde `Azure/Enterprise-Scale` (GitHub, soportado oficialmente).
- **Terraform** vía `Azure/avm-ptn-alz-management/azurerm` o el provider `azapi` sobre los módulos **Azure Verified Modules (AVM)**. Hoy (2026) es el camino recomendado para IaC.

**Qué es gratis y qué no**:

- MGs, Azure Policy engine, Entra ID (free tier), Deployment Stacks: **gratis**.
- Log Analytics Workspace: paga por GB ingerido (~2.76 USD/GB en pay-as-you-go, descuentos por commit).
- Azure Firewall: **~900 USD/mes** solo por el deployment (fijo, independiente de tráfico). Es el componente más caro de una LZ estándar.
- Private DNS Zones: pennies.

**Cuándo adoptarlo y cuándo no**:

- **Sí** si estás arrancando una org nueva en Azure y quieres el baseline en días en lugar de meses.
- **No** (o con cuidado) si ya tienes subscriptions dispersas: enroll a ALZ es laborioso y requiere mover subs entre MGs, revisar role assignments existentes y reconciliar policies legacy.

**Alternativa**: montar la misma estructura con Terraform propio o Bicep (`caf-terraform-landingzones`, legacy pero vigente). Más trabajo, más control, menos lock-in a la *reference implementation*.

---

## 8. Policy as Code: EPAC y Deployment Stacks

### 8.1 Enterprise Policy as Code (EPAC)

**EPAC** es un framework open-source (Microsoft, en GitHub) para gestionar Azure Policy como código con PowerShell + JSON. Permite:

- Definir todas las policies, initiatives y assignments en Git.
- Hacer `diff` entre lo que está en el tenant y lo que debería estar.
- Desplegar con pipelines (GitHub Actions, Azure DevOps) con approvals.
- Multi-tenant (un repo gestiona varias organizaciones).

Es el estándar de facto hoy (2026) para equipos que operan 10+ subscriptions y >50 policies.

### 8.2 Deployment Stacks (reemplazo de Blueprints)

**Azure Blueprints** fue el servicio oficial para empaquetar un conjunto de ARM templates + role assignments + policies como una "huella desplegable". **Deprecado**: será retirado el **11 de julio de 2026**. Microsoft recomienda migrar a **Deployment Stacks**.

**Deployment Stacks** son un recurso ARM/Bicep que:

- Agrupa un conjunto de recursos como una "stack" versionada.
- Permite políticas de **deletion lock** (si borras la stack, puedes decidir qué recursos se eliminan y cuáles se preservan).
- Soporta **deny settings** a nivel de stack (análogo a los Blueprints `locks`).
- Es ARM-native (GA desde 2024), no un servicio aparte.

Pattern en 2026: **EPAC** gestiona policies, **Deployment Stacks** empaquetan recursos. CAF ALZ está transicionando a ambos.

---

## 9. PIM y Entra ID: la puerta elevada

**Privileged Identity Management (PIM)** es el servicio de Microsoft Entra ID para **acceso elevado JIT (just-in-time)** a roles de Entra, de Azure (RBAC) y de grupos. Reemplaza el anti-patrón de "dejar a developers con `Owner` permanente".

Flujo:

```
┌────────────────────┐      ┌──────────────────────┐
│ Developer (user)   │      │   PIM (Entra ID P2)  │
│  eligible for      │─────►│  - activation req.   │
│  Owner on sub-prod │      │  - approval flow     │
└────────────────────┘      │  - MFA + justif.     │
                            │  - TTL (p.ej. 2h)    │
                            └──────────┬───────────┘
                                       │ grants role for TTL
                                       ▼
                                ┌─────────────┐
                                │ sub-prod    │
                                │ Owner role  │
                                │ (expires)   │
                                └─────────────┘
```

Reglas:

- **Eligible vs Active**. Un usuario *eligible* **no tiene** el rol hasta que lo activa. Un usuario *active* lo tiene permanente (igual que un role assignment normal).
- **Activation requires**: MFA (reautenticación), justificación opcional obligatoria, approval opcional (otra persona), ticket ID opcional (ServiceNow/Jira).
- **TTL**: configurable (típicamente 1-8h, max 24h).
- **Audit**: cada activación genera eventos en Entra ID audit log + Azure Activity Log en el scope.
- **Requisito**: **Entra ID P2** (~9 USD/user/mes). Sin P2 no hay PIM.

**Patrón recomendado**:
- Grupo `platform-admins` → *eligible* `Owner` en `Platform` MG.
- Grupo `developers-prod` → *eligible* `Contributor` en subs `prod`, con approval de un segundo developer.
- Nadie *active* `Owner` permanente, excepto una cuenta BreakGlass con MFA + alerta.

---

## 10. Patrones "una app = una subscription" vs "una app = N subscriptions"

### 10.1 Una app = una subscription

- Un solo blast-radius por app (en términos de quotas y billing).
- Billing claro (una subscription = una línea en el invoice).
- Pero: no hay separación dev/stg/prod a nivel de subscription; separas por RG o por tag. Un deploy a prod rompiendo dev por un bug compartido es posible.
- Útil para apps **pequeñas**, **internas** o **spikes**.

### 10.2 Una app = N subscriptions (dev / stg / prod)

- Blast-radius por entorno, no solo por app. Un `terraform apply` equivocado en *dev* no toca *prod* ni por accidente.
- Policies distintas por entorno vía MG hijo: *dev* laxa, *prod* estricta.
- Role assignments distintos: `Contributor` en dev, `Reader` en prod (excepto deployment SPN/MI).
- Pero: 3× subs por app, más overhead administrativo. Si tienes 20 apps, son 60 subs — todavía manejable, pero necesitas automatización.
- **Patrón estándar para producción crítica.**

### 10.3 Híbrido (recomendado en orgs reales)

En orgs maduras: apps críticas tienen dev/stg/prod en subs separadas; apps internas comparten una sub `internal-tools` con RGs por app. La jerarquía de MGs refleja esto con `Landing Zones/Corp/critical` y `Landing Zones/Corp/internal`.

---

## 11. Fundamentos internos (lo que suele doler en producción)

Cuatro cosas que **no se intuyen** y conviene fijar:

1. **El Tenant Root Group afecta a todo el tenant.** Un `role assignment` de `Owner` aquí es `Owner` de **cualquier** subscription que entre al tenant, hoy o en el futuro. Nunca asignes al Tenant Root salvo las policies verdaderamente globales. Operar siempre desde un `Intermediate Root` propio.
2. **Las Azure Policies no cambian el estado existente al asignarse.** Si asignas una policy `deny-public-ip` hoy, los Public IPs **ya creados** siguen existiendo (marcados non-compliant por el barrido). Las policies son controles **sobre acciones futuras**; para el estado existente necesitas remediation tasks (DINE) o limpieza manual.
3. **`deployIfNotExists` necesita una Managed Identity.** La assignment de una policy DINE crea (o referencia) una Managed Identity con el `roleDefinitionIds` que declaras en la assignment. Si olvidas los roles correctos, la remediation falla silenciosamente. En CAF ALZ la ME se gestiona por la *reference implementation*.
4. **Las subscriptions se mueven entre MGs sin cambiar nada *dentro* de ellas**, pero las policies **efectivas** cambian al instante. Mover `sub-corp-prod` desde `Corp` a `Sandbox` **relaja** las policies restrictivas y puede permitir que un recurso ya non-compliant lo deje de ser (o viceversa). Monitorizar movimientos de subs es parte del gobierno.

---

## 12. Alternativas y qué llevarse

### Alternativas al stack "MG + Azure Policy + CAF ALZ + PIM"

- **Terraform puro** (sin la *reference implementation* ALZ): más trabajo inicial, más control. Patrón si ya tienes una opinión fuerte sobre MG structure.
- **Bicep + Deployment Stacks**: path *native* Azure, buena opción si el equipo ya invirtió en Bicep.
- **Multi-cloud governance tools** (HashiCorp Sentinel, OPA/Gatekeeper, Prisma Cloud): capa adicional sobre Azure Policy. Útil si gobiernas Azure + AWS + GCP con un mismo lenguaje.

### Mapping conceptual AWS ↔ Azure (resumen)

| AWS | Azure |
|-----|-------|
| AWS Organization | Microsoft Entra ID tenant + Management Groups |
| Organizational Unit (OU) | Management Group (anidado) |
| Account | Subscription |
| SCP (`Deny`) | Azure Policy effect `deny` |
| SCP (`Allow` whitelist) | Azure Policy (no hay equivalente nativo; se simula con `deny` sobre todo lo no listado) |
| Control Tower | Enterprise Scale Reference Implementation (ES ALZ) |
| IAM Identity Center | Microsoft Entra ID + groups + RBAC assignments |
| Permission Set | Combinación de `role definition` + `role assignment` sobre scope |
| Cross-account role (`sts:AssumeRole`) | Managed Identity + role assignment en subscription remota |
| Blueprints (deprecado AWS? No) | Blueprints Azure (deprecados jul-2026) → Deployment Stacks |

### Qué llevarse en una frase

> La **subscription** es el límite duro de billing y quotas en Azure. **Management Groups + Azure Policy** definen el techo (lo que **ninguna** subscription puede saltarse). **Entra ID + RBAC + PIM** definen la puerta (quién entra y cómo). **CAF Enterprise Scale ALZ** empaqueta el baseline opinado. Diseñar la jerarquía de MGs al principio evita migraciones dolorosas después.

### Qué sigue

- `az-10` — aterriza DevSecOps sobre esta base: OIDC GHA → Entra ID (federated credentials), Defender for Cloud, ACR Premium + cosign, Deployment Stacks con deny settings.
