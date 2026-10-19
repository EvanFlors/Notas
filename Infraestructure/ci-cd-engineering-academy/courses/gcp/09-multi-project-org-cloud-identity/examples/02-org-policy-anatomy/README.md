# Ejemplo 02 — Anatomía de una Org Policy

> Lectura y análisis. Sin ejecución. Objetivo: entender los campos de una Org Policy y cuándo usar cada forma (`boolean`, `list`, `custom`).

## 1. Las tres formas

| Forma | Qué expresa | Ejemplo de constraint |
|-------|-------------|-----------------------|
| **Boolean** | Enforced o no. Binario. | `iam.disableServiceAccountKeyCreation`, `storage.publicAccessPrevention`, `compute.requireOsLogin`. |
| **List** | Un conjunto de valores permitidos o denegados. | `iam.allowedPolicyMemberDomains`, `compute.restrictVpcPeering`, `compute.vmExternalIpAccess` (con allow/deny list). |
| **Custom** (CEL) | Expresión en Common Expression Language para constraints que Google no modela de base. | `custom.requireLabelCostCenter`. |

## 2. Boolean constraint — anatomía

```yaml
# Formato Org Policy v2 (resource-oriented).
name: organizations/123456789012/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: true
  inheritFromParent: false
  reset: false
```

Campos clave:

- `name`: incluye el **punto de aplicación** (`organizations/.../`, `folders/.../`, `projects/.../`) y el **constraint** (`policies/iam.disableServiceAccountKeyCreation`).
- `spec.rules[].enforce`: `true` para activar, `false` para desactivar explícitamente (útil para "apagar" la herencia en una subrama concreta).
- `inheritFromParent`: si `true`, suma restricciones del padre; si `false`, las ignora en esta rama.
- `reset`: si `true`, vuelve al default de Google (olvida cualquier política heredada o explícita).

## 3. List constraint — anatomía

```yaml
name: organizations/123456789012/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
    - values:
        allowedValues:
          - C01abc234    # customer ID de ejemplo.com (Cloud Identity)
  inheritFromParent: false
```

Campos extra:

- `values.allowedValues`: valores *permitidos*. Nadie fuera de esa lista se puede añadir como principal.
- `values.deniedValues`: valores *prohibidos* (patrón negativo).
- `allValues`: `ALLOW` o `DENY` para "permitir todo" o "denegar todo" sin enumerar.

**Ejemplo con denyAll + excepción**:

```yaml
name: organizations/123456789012/policies/compute.vmExternalIpAccess
spec:
  rules:
    - denyAll: true
    - condition:
        expression: "resource.matchTag('ejemplo.com/env', 'bastion')"
        title: "Allow external IP only for bastion VMs"
      values:
        allowedValues:
          - "projects/bastion-prod/zones/europe-west1-b/instances/bastion-01"
  inheritFromParent: false
```

> El bloque con `condition` requiere **Tag-based conditions** (feature de Org Policy avanzada). En diseños de arranque, es más limpio dejar `denyAll: true` sin excepciones y crear un project aparte para bastiones donde la policy esté `reset: true`.

## 4. Puntos de aplicación

```
Organization  ─── policy A (iam.disableServiceAccountKeyCreation, enforce)
      │
      ├── Folder: Workloads
      │        │
      │        └── Folder: Workloads/Prod  ─── policy B (compute.requireOsLogin, enforce)
      │                       │
      │                       └── Project: checkout-prod
      │                            → recibe A (heredada) + B (heredada) + cualquier policy local
      │
      └── Folder: Sandbox  ─── policy A override (iam.disableServiceAccountKeyCreation, enforce=false)
                                   ← permite SA keys solo en sandbox para experimentar
```

Regla: una Org Policy aplicada en Organization se **hereda** por defecto. Cada folder/project puede:

- Añadir policies adicionales.
- Overridear policies heredadas con `inheritFromParent: false` + nueva regla.
- Resetear a default con `reset: true`.

## 5. Patrones del baseline — por qué cada uno

| Constraint | Qué evita | Dónde adjuntar |
|------------|-----------|----------------|
| `iam.disableServiceAccountKeyCreation` | Que alguien descargue una SA key JSON y la pegue en Git o un pipeline. | Organization (con override `enforce=false` en `Sandbox` si se tolera). |
| `compute.vmExternalIpAccess=denyAll` | Que una VM salga a internet con IP pública sin querer; obliga a Cloud NAT. | Organization. |
| `storage.publicAccessPrevention=enforced` | Que un bucket se publique con `allUsers`/`allAuthenticatedUsers`. | Organization. |
| `iam.allowedPolicyMemberDomains` | Que se añada un principal externo (p. ej. `attacker@gmail.com`). | Organization, con `allowedValues` = customer ID de la org. |
| `compute.requireOsLogin` | Que se gestionen SSH keys manualmente en metadata (prefiere OS Login + IAM). | Folder `Workloads/Prod`. |
| `sql.restrictPublicIp` | Que una Cloud SQL instance tenga IP pública. | Folder `Workloads/Prod`. |

## 6. Comparación relámpago AWS SCP vs GCP Org Policy

| Aspecto | AWS SCP | GCP Org Policy |
|---------|---------|----------------|
| Modelo | Policy de acciones (`Deny` con `Action`/`NotAction`). | Constraint declarativo (`enforce`, `allowedValues`, `deniedValues`). |
| Granularidad | Nivel de acción IAM (`s3:PutObject`). | Nivel de servicio o feature (`storage.publicAccessPrevention`). |
| Punto de adjunción | Root, OU, cuenta. | Organization, Folder, Project. |
| Herencia | Siempre hereda; combinación por intersección de allows. | Hereda con `inheritFromParent`; se puede overridear/resetear localmente. |
| Deny de principal concreto | Dentro de la misma SCP con `Condition`. | Se separa en **IAM Deny Policy** (plano distinto). |
| Lenguaje de condiciones | JSON policy con `Condition`. | YAML + CEL en custom constraints. |

> Mnemotécnica: **SCP** dice *"qué acciones no se pueden hacer"*. **Org Policy** dice *"cómo tiene que estar configurado el servicio"*. Son complementarias; GCP exige menos "SCP en todo" porque muchos guardrails son policies de servicio.

## 7. Custom constraints (introductorio)

Cuando Google no modela un constraint que necesitas, puedes crear uno con CEL:

```yaml
name: organizations/123456789012/customConstraints/custom.requireLabelCostCenter
resourceTypes:
  - compute.googleapis.com/Instance
methodTypes:
  - CREATE
  - UPDATE
condition: "has(resource.labels.cost_center) && resource.labels.cost_center != ''"
actionType: ALLOW
displayName: "Require cost_center label on Compute Instances"
description: "Rechaza la creación de VMs sin label cost_center."
```

Y después se activa con:

```yaml
name: organizations/123456789012/policies/custom.requireLabelCostCenter
spec:
  rules:
    - enforce: true
```

> Custom constraints son GA pero su catálogo de `resourceTypes` crece con el tiempo; verificar en Fase 4 qué servicios los soportan.
