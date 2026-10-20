# Ejemplo 03 — Relaciones y vista de impacto

> Lectura y análisis. Sin ejecución. Objetivo: ver cómo las relaciones del catálogo convierten una lista plana de servicios en un **grafo consultable** que responde la pregunta "si tiro esto, ¿quién se rompe?".

## 1. El sistema de ejemplo

Modelamos un sistema `checkout` con:

- 3 Components: `checkout-api` (HTTP front), `checkout-worker` (procesa queue async), `notifications-sender` (consume eventos y envía emails).
- 2 APIs: `checkout-api-v1` (REST, provista por `checkout-api`), `checkout-events-v1` (asyncapi, provista por `checkout-worker`).
- 1 Resource: `checkout-db` (Postgres).
- 1 System: `checkout`.
- 1 Domain: `commerce`.

## 2. Los `catalog-info.yaml` (resumidos)

### `checkout-api/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-api
spec:
  type: service
  lifecycle: production
  owner: group:payments-team
  system: checkout
  providesApis:
    - checkout-api-v1
  dependsOn:
    - resource:checkout-db
    - component:checkout-worker
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: checkout-api-v1
spec:
  type: openapi
  lifecycle: production
  owner: group:payments-team
  system: checkout
  definition: '# OpenAPI omitido en el ejemplo'
```

### `checkout-worker/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-worker
spec:
  type: service
  lifecycle: production
  owner: group:payments-team
  system: checkout
  providesApis:
    - checkout-events-v1
  dependsOn:
    - resource:checkout-db
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: checkout-events-v1
spec:
  type: asyncapi
  lifecycle: production
  owner: group:payments-team
  system: checkout
  definition: '# AsyncAPI omitido en el ejemplo'
```

### `notifications-sender/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: notifications-sender
spec:
  type: service
  lifecycle: production
  owner: group:notifications-team
  system: checkout
  consumesApis:
    - checkout-events-v1
```

### `platform-catalog/catalog-info.yaml` (centralizado)

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: checkout
spec:
  owner: group:payments-team
  domain: commerce
---
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: commerce
spec:
  owner: group:commerce-leadership
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: checkout-db
spec:
  type: database
  owner: group:payments-team
  system: checkout
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: payments-team
spec:
  type: team
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: notifications-team
spec:
  type: team
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: commerce-leadership
spec:
  type: team
```

## 3. El grafo que Backstage construye

```
                       ┌──────────┐
                       │  Domain  │
                       │ commerce │
                       └────┬─────┘
                       hasPart│  (derivada de partOf)
                            ▼
                     ┌──────────────┐
                     │   System     │
                     │   checkout   │
                     └──┬──┬──┬─────┘
                        │  │  │
             hasPart    │  │  │
         ┌──────────────┘  │  └───────────────┐
         ▼                 ▼                  ▼
  ┌──────────────┐  ┌──────────────┐   ┌────────────────┐
  │ Component    │  │ Component    │   │ Component      │
  │ checkout-api │  │ checkout-   │   │ notifications- │
  │              │  │ worker       │   │ sender         │
  └──┬───┬───────┘  └──┬──┬────────┘   └──────┬─────────┘
     │   │             │  │                   │
     │   │             │  │                   │ consumesApi
     │   │             │  │                   ▼
     │   │             │  │          ┌───────────────────┐
     │   │             │  │          │  API              │
     │   │             │  │          │  checkout-events  │
     │   │             │  │          │  -v1              │
     │   │             │  └──────────┤                   │
     │   │             │ provides    └───────────────────┘
     │   │             │
     │   │             │ dependsOn
     │   │             ▼
     │   │        ┌─────────────┐
     │   │        │  Resource   │
     │   │        │ checkout-db │
     │   │        └─────────────┘
     │   │             ▲
     │   │             │ dependsOn
     │   │             │
     │   └─────────────┘
     │
     │ providesApi
     ▼
  ┌─────────────────┐
  │   API           │
  │ checkout-api-v1 │
  └─────────────────┘
```

## 4. Las queries de impacto que esto habilita

Dadas estas relaciones, Backstage responde (via UI del plugin `catalog-graph` o via `GET /api/catalog/entities/by-name/...`):

| Pregunta | Query sobre el grafo |
|----------|----------------------|
| "¿Quién consume `checkout-events-v1`?" | `apiConsumedBy` del API → `notifications-sender` |
| "¿Quién depende de `checkout-db`?" | `dependencyOf` del Resource → `checkout-api`, `checkout-worker` |
| "Si deprecamos `checkout-api-v1`, ¿a quién avisar?" | owners de `apiConsumedBy` → (en este ejemplo, nadie: nadie la consume aún) |
| "¿Qué servicios tiene `payments-team`?" | filtrar entidades por `spec.owner=group:payments-team` → `checkout-api`, `checkout-worker` (+ `checkout-db`, `checkout-api-v1`, `checkout-events-v1`, `checkout`) |
| "¿Qué contiene el system `checkout`?" | `hasPart` → los 3 Components, 2 APIs, 1 Resource |

## 5. Qué pasa si **no** declaras relaciones

Supongamos que `notifications-sender` **olvida** declarar `consumesApis: [checkout-events-v1]`. Técnicamente la app sigue funcionando (es solo metadata). Pero:

- Backstage **no sabe** que `notifications-sender` depende del API.
- Si `payments-team` deprecara `checkout-events-v1`, el plugin de impacto reportaría "nadie la consume" — falso.
- `payments-team` tira el API; `notifications-sender` se rompe en producción; el incidente se gestiona en Slack con sorpresa.

El valor del catálogo es **exactamente** el valor de la disciplina con que se declaran las relaciones. Un platform team maduro **audita** periódicamente (p. ej. con un CI job) las relaciones faltantes:

```
# pseudocodigo del check
for cada Component en el catalogo:
    si tiene llamadas HTTP conocidas (ej. logs/traces en OTel) a otros Components:
        verificar que esas relaciones esten declaradas via consumesApis o dependsOn
    si no:
        abrir issue al owner
```

(La integración con OTel para auditar relaciones es un patrón avanzado — se insinúa aquí; se trabaja a fondo en el curso de observabilidad.)

## 6. Preguntas de autocomprobación

1. En el grafo del ejemplo, ¿por qué `checkout-api` tiene **dos** `dependsOn` y ningún `consumesApis`?
2. ¿Qué pasa si `notifications-sender.spec.owner` apunta a un Group inexistente `group:ops-team`?
3. Si quisieras marcar que `checkout-api-v1` está **deprecated**, ¿dónde pondrías el flag?
4. ¿Qué 2 relaciones NO están declaradas en el ejemplo que mejorarían la vista de impacto?
5. Si `notifications-sender` moviera su `catalog-info.yaml` a otro repo, ¿cuánto tarda Backstage en reflejarlo? (asumir provider con `frequency: 30m`).

Las respuestas se trabajan en la actividad `01-model-capstone-in-catalog/`.
