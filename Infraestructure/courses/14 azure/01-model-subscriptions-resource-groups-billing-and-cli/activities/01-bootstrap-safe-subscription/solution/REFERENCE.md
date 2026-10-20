# REFERENCE — az-01-01-bootstrap-safe-subscription

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Bootstrap de la subscription playground de la startup

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Platform + Security y materializado con Terraform (`azurerm`) en Fase 4.

## Contexto

La startup (20 personas, 10 ingenieros) va a estrenar Azure para experimentos y para el primer workload (`checkout`, llegará en `az-02`+). Hoy no hay nada montado:

- **Compliance**: datos en Europa (`westeurope` o `northeurope`).
- **Coste**: cero en Fase 3. En Fase 4, el objetivo es tope duro de 10 USD/mes en el playground.
- **Identidad**: ya existe un **Microsoft Entra ID tenant** corporativo (gestionado por IT, placeholder `00000000-0000-0000-0000-000000000000`).
- **Billing**: contrato **MCA** firmado con Microsoft, Billing Account única.
- **Escala esperada**: 1 subscription playground hoy; en 6 meses, 3 subscriptions (`sandbox`, `dev`, `prod` del workload `checkout`) bajo un Management Group `Landing Zones`.
- **Riesgo a evitar**: que un developer encienda un recurso caro por error en una subscription sin tope ni alertas.

## Decisión

### 1. Jerarquía Azure (vista desde el tenant)

```text
Microsoft Entra ID Tenant                   (00000000-0000-0000-0000-000000000000)
│
├── Tenant Root Group                       (= tenant id, creado por Azure)
│   │
│   └── Management Group: Sandbox MG        (11111111-1111-1111-1111-111111111111)
│       │   Azure Policy (futuro az-09):
│       │     - deny-non-eu-regions
│       │     - deny-expensive-vm-sizes
│       │     - require-tag:env
│       │
│       └── Subscription: Playground        (22222222-2222-2222-2222-222222222222)
│           │   Type: Dev/Test (sin SLA, pricing reducido)
│           │   Billing: ligada a MCA Billing Profile corporativo
│           │
│           ├── Resource Group: rg-sandbox-dev   (location: westeurope)
│           │   Tags: env=sandbox, owner=platform, cost-center=CC-0001,
│           │         workload=playground, managed-by=manual
│           │
│           └── Resource Group: rg-shared-logs   (location: westeurope)
│               Tags: env=sandbox, owner=platform, cost-center=CC-0001,
│                     workload=observability, managed-by=manual
```

### 2. Elección de subscription type

**Dev/Test** (ligada a los asientos Visual Studio del equipo).

- **Por qué**: pricing reducido para VMs, Storage, SQL, etc. Sin SLA — aceptable en playground. Es el único tipo moderno que da pricing preferente para experimentación.
- **Alternativas descartadas**:
  - *Free*: créditos iniciales caducan en 30 días; renovarlo es un dolor y no escala a 20 personas.
  - *Pay-As-You-Go*: pricing normal, sin descuento de experimentación.

### 3. Convención de Resource Groups

- `rg-<workload>-<env>` para workloads (p. ej. `rg-checkout-dev`).
- `rg-shared-<function>` para cross-cutting (`rg-shared-logs`, `rg-shared-network`).
- **Un RG = un ciclo de vida**: desmontar `rg-sandbox-dev` con `az group delete` debe ser una decisión segura.
- `location` del RG = `westeurope` (metadata), aunque recursos individuales podrían vivir en `northeurope` si se justifica DR.

### 4. Resource providers a registrar

Mínimo para el playground y para empezar `az-02` / `az-03` / `az-04`:

| Namespace | Para qué |
|-----------|----------|
| `Microsoft.Compute` | VMs, Disks, VMSS. |
| `Microsoft.Network` | VNets, NSGs, NAT Gateway. |
| `Microsoft.Storage` | Storage Accounts (Blob, Queue, File). |
| `Microsoft.KeyVault` | Key Vault para secretos/claves. |
| `Microsoft.ManagedIdentity` | Managed Identities (user-assigned). |
| `Microsoft.OperationalInsights` | Log Analytics workspaces (cuidado: cobran por GB). |
| `Microsoft.Insights` | Alerts, Action Groups, Application Insights. |
| `Microsoft.App` | Container Apps (`az-04`). |
| `Microsoft.ContainerRegistry` | ACR (`az-10`). |

Dejamos **no registrados** por ahora `Microsoft.ContainerService` (AKS, `az-07`), `Microsoft.DBforPostgreSQL` (`az-05`), `Microsoft.Sql`, `Microsoft.DocumentDB` — se registrarán cuando toque. Defensa en profundidad.

### 5. Budget con alertas

Scope: **Resource Group** `rg-sandbox-dev` para empezar (visibilidad inmediata; luego añadiremos uno a nivel subscription).

- `amount`: 10 USD/mes.
- `timeGrain`: Monthly.
- Thresholds:
  - `Actual 50%` → email `finops@example.com`.
  - `Actual 80%` → email + Action Group `ag-finops` (futuro: Slack).
  - `Forecasted 100%` → email + Action Group.
- Destinos: Action Group `ag-finops` en `rg-shared-logs` (encamina a Slack via Logic App en Fase 4).

> El Budget alerta, no bloquea. El bloqueo real lo hará **Azure Policy** `deny` sobre tipos de VM caros, en `az-09`.

### 6. `az` CLI defaults

```bash
# Tras `az login` + `az account set --subscription <GUID>`:
az config set defaults.group=rg-sandbox-dev defaults.location=westeurope
```

Ventaja: todos los comandos siguientes asumen RG + location. Trampa: olvidar los defaults y crear recursos en el RG equivocado — mitigación: `az config get` como primer paso del operador.

### 7. Flujo de login humano

- **Entra ID interactivo** (`az login`) desde laptop con MFA ya configurado.
- Dispositivos sin navegador: `az login --use-device-code`.
- **Nunca** `az login --service-principal` desde laptop personal (secreto en disco).
- Para CI/CD: **OIDC Federation** GitHub Actions → Entra ID (sin secreto), se ve en `az-10`.

## Consecuencias

### Positivas

- Jerarquía clara desde el día cero (`Tenant → MG → Sub → RG`), lista para crecer a 3+ subscriptions bajo el mismo MG.
- Dev/Test da pricing preferente y evita malas sorpresas en playground.
- Budget con alertas desde el día uno → nunca una factura "sorpresa".
- Resource providers mínimos → menos superficie de ataque y de coste no intencional.
- `az` CLI defaults → operación ágil con RG+location consistentes.

### Negativas

- Dev/Test **no tiene SLA**: no es trasladable a prod. Hay que migrar workloads a una subscription MCA Enterprise cuando entren en producción.
- Un RG `rg-sandbox-dev` compartido por 10 ingenieros puede saturarse de experimentos. Mitigación: política de limpieza semanal + un RG por developer en Fase 2 si hace falta.
- El Budget alerta pero no bloquea; un `p5.48xlarge` encendido 24 h puede exceder el amount antes de que el email llegue a Slack. Mitigación: Azure Policy `deny` en `az-09`.
- El `Management Group` para la Sandbox exige coordinación con IT (dueño del tenant). Mitigación: aprobación inicial documentada en este ADR.

## Alternativas descartadas

### Alternativa A: una sola Subscription PAYG sin Management Group

- Más rápido, menos coordinación con IT.
- **Por qué no**: no escala a 3+ subscriptions, y las Azure Policy del baseline del `az-09` tendrán que aplicarse una por una en lugar de heredar desde el MG.

### Alternativa B: subscription Free en lugar de Dev/Test

- Cero coste inicial garantizado (créditos iniciales).
- **Por qué no**: los créditos expiran en 30 días; renovar es manual y no escala; pierdes el acceso a servicios que requieren pago (Container Apps en algunas regiones, etc.).

### Alternativa C: un único RG `rg-all` que lo contenga todo

- Simpler mental model.
- **Por qué no**: pierdes la ventaja operativa de `az group delete` por ciclo de vida; mezclas `shared-logs` con experimentos efímeros y no puedes borrar uno sin romper el otro.

### Alternativa D: no habilitar `Microsoft.OperationalInsights` para "evitar coste"

- Verdadero: Log Analytics cobra por GB.
- **Por qué no**: observabilidad desde el día cero es barata (pocos GB) y evita descubrir problemas sin logs. Mejor habilitar + poner cap de ingestión en Fase 4 (`az-08`).

---

## Nota sobre IDs

Todos los GUIDs (`00000000-...`, `11111111-...`, `22222222-...`) son **placeholders ficticios**. Los IDs reales se materializan al crear el tenant/MG/subscription y se registran en un `subscriptions.yaml` versionado, **no** en este ADR.
