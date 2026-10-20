# Actividad 02 — Escribir Azure Policies del baseline y validarlas

## 1. Identificación

- **ID:** `az-09-02-write-azure-policy-baseline-and-validate`
- **Tecnología:** `azure`
- **Módulo:** `az-09-multi-subscription-management-groups-azure-policy-landing-zone`
- **Dificultad:** advanced
- **Duración estimada:** 70–90 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de Security te pide escribir el **baseline de Azure Policies** del tenant. Son tres `policyDefinition` que todas las subscriptions de la org deben tener asignadas (directa o heredadamente desde un MG). No vas a asignarlas a nada: estás **escribiéndolas** para que Fase 4 las despliegue con Terraform (AVM ALZ) o Bicep. Deben ser JSON válido, respetar la estructura de `policyDefinition`, y venir acompañadas de un documento que explique qué hace cada una, en qué MG se asigna y qué parámetros expone.

**Importante**: no hay tenant Azure. No se asigna nada. El entregable son 3 archivos JSON + 1 README.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `policyDefinition` sintácticamente correcto usando `properties.mode`, `properties.policyRule.if`, `properties.policyRule.then.effect` y `properties.parameters`.
- Explicar por qué `deny-locations` debe exceptuar `location = "global"`.
- Elegir correctamente el efecto adecuado: `deny` (preventivo) vs `auditIfNotExists` (detectivo).
- Justificar por escrito dónde asignar cada policy (MG `contoso` vs `Landing Zones/Corp` vs subscription individual).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§4-6) y recorrido `../../examples/02-azure-policy-anatomy/`.
- Herramientas: `bash`, `jq` (parser JSON), `python3` (opcional, validación extra). Un editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-09-policy
cd /tmp/az-09-policy
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 3 archivos JSON

Nombres **exactos** (el validador los busca):

1. `policy-deny-locations.json`
2. `policy-deny-public-ip.json`
3. `policy-audit-diagnostic-settings.json`

Requisitos por archivo:

#### `policy-deny-locations.json`

- Objeto con `properties` que contenga: `displayName`, `policyType` (`"Custom"`), `mode` (`"All"` o `"Indexed"`), `policyRule`.
- `properties.parameters.allowedLocations` definido con `type: "Array"` y `defaultValue` con al menos una región europea (`"westeurope"`, `"northeurope"`, u otra `eu-*` legacy).
- `properties.policyRule.if` debe usar `field: "location"` con operador `notIn` referenciando `[parameters('allowedLocations')]`.
- Debe exceptuar `location = "global"` (p. ej. con `allOf` que incluya `{ "field": "location", "notEquals": "global" }`).
- `properties.policyRule.then.effect` debe ser `"deny"`.

#### `policy-deny-public-ip.json`

- Objeto con `properties`: `displayName`, `policyType` (`"Custom"`), `mode`, `policyRule`.
- `properties.policyRule.if` debe comprobar `field: "type"` igual a `"Microsoft.Network/publicIPAddresses"`.
- `properties.policyRule.then.effect` debe ser `"deny"`.

#### `policy-audit-diagnostic-settings.json`

- Objeto con `properties`: `displayName`, `policyType` (`"Custom"`), `mode`, `policyRule`.
- `properties.policyRule.if` debe comprobar `field: "type"` sobre al menos un tipo de recurso concreto (p. ej. `"Microsoft.KeyVault/vaults"`, `"Microsoft.Storage/storageAccounts"`, o `"Microsoft.Network/applicationGateways"`).
- `properties.policyRule.then.effect` debe ser `"auditIfNotExists"`.
- `properties.policyRule.then.details.type` debe ser `"Microsoft.Insights/diagnosticSettings"`.
- `properties.policyRule.then.details.existenceCondition` debe comprobar que `logs.enabled` sea `"true"` o que `workspaceId` exista.

Los tres archivos deben ser **JSON válido** (parseables por `jq .`).

### 5.3 Escribe `README-INTENT.md`

Un documento que explique, para cada policy:

- **Qué hace** (en lenguaje humano, no copiando el JSON).
- **A qué MG o scope se asignará** y por qué (`contoso` Intermediate Root, `Landing Zones/Corp`, `Sandbox`...).
- **Qué parámetros expone** y con qué valores por defecto.
- Para `deny-locations`, un párrafo justificando por qué exceptuar `location = "global"`.
- Para `audit-diagnostic-settings`, mención explícita de **Log Analytics** y **diagnostic settings**.

Secciones obligatorias (el validador las busca):

- `## policy-deny-locations`
- `## policy-deny-public-ip`
- `## policy-audit-diagnostic-settings`

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.4 Entregables

```
/tmp/az-09-policy/
├── policy-deny-locations.json
├── policy-deny-public-ip.json
├── policy-audit-diagnostic-settings.json
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 JSONs parsean con `jq .`.
- El validador pasa con `0 issue(s)`:
  - sintaxis JSON de cada archivo,
  - presencia de `properties`, `policyType`, `mode`, `policyRule.if`, `policyRule.then.effect`,
  - presencia de condiciones/campos mínimos por policy,
  - presencia del `README-INTENT.md` con las 3 secciones + mención Log Analytics + justificación de `global`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa con `0 issue(s)`.
- **Correctitud sintáctica**: JSON válido, strings bien cerradas, comas correctas.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/*.json` y `solution/README-INTENT.md`.
- **Mantenibilidad**: `displayName` legible, `description` presente, `metadata.category` consistente.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-09-policy
```

El validador comprueba sintaxis JSON y presencia de claves/campos mínimos. **No** comprueba que la policy, asignada a un MG real, se evalúe exactamente como dice el README. Esa validación semántica se hace en Fase 4 contra un tenant real (con `az policy state list` y con un recurso de prueba).

## 9. Preguntas de reflexión

1. Si quitas `location notEquals "global"` del `deny-locations`, ¿qué deja de poder crearse?
2. ¿Puedes asignar `deny-public-ip` al Tenant Root Group? ¿Qué pasaría con el hub VNet de `Platform/Connectivity`?
3. ¿Por qué `audit-diagnostic-settings` necesita `auditIfNotExists` y no simplemente `audit`? (pista: ¿sobre qué recurso evalúa?)
4. ¿Cómo probarías una policy sin arriesgarte a romper prod? (pista: Sandbox MG + `--enforce` flag al asignarla).
5. Si un desarrollador necesita temporalmente crear un recurso en `uksouth`, ¿cómo le concedes acceso sin desactivar la policy? (pista: `exemption` con TTL).

## 10. Extensiones

- Añade una cuarta policy: `policy-require-tags.json` que exija los tags `env` y `owner` en cualquier RG o recurso creado (`deny` si faltan).
- Añade una policy `policy-deploy-defender-for-storage.json` con efecto `deployIfNotExists` que habilite Microsoft Defender for Storage en cualquier Storage Account nueva (incluye `roleDefinitionIds` en el `details`).
- Escribe un pequeño script `verify-policy.sh` que corra `jq` + comprobaciones adicionales (p. ej. que todos los JSON tengan `metadata.category` y `description`).

## 11. Limpieza

```bash
rm -rf /tmp/az-09-policy
```

No hay infraestructura que detener.
