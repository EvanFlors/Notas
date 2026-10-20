# REFERENCE — plat-05-01-model-capstone-in-catalog

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Decisiones de modelado

El sistema `orders` (del stub del README) se puede modelar así:

- **1 Domain:** `commerce` (dueño: `commerce-leadership`).
- **1 System:** `orders` (dueño: `orders-team`, dentro de `commerce`).
- **3 Components:**
  - `orders-api` (HTTP, Python/FastAPI, dueño `orders-team`).
  - `payments-worker` (async worker, dueño `orders-team`).
  - `notifications-sender` (consumer de eventos, dueño `comms-team`).
- **2 APIs:**
  - `orders-api-v1` (openapi, provista por `orders-api`).
  - `orders-events-v1` (asyncapi, provista por `payments-worker`, consumida por `notifications-sender`).
- **2 Resources:**
  - `orders-db` (Postgres, usado por `orders-api` y `payments-worker`).
  - `orders-receipts-bucket` (S3, usado por `notifications-sender`).
- **3 Groups:** `orders-team`, `comms-team`, `commerce-leadership`.

Observa que **todas** las relaciones apuntan a entidades existentes. Esa es la higiene mínima.

## Árbol de archivos (modelo)

```
/tmp/plat-05-catalog/
├── orders-api/catalog-info.yaml           (Component + API)
├── payments-worker/catalog-info.yaml      (Component + API)
├── notifications-sender/catalog-info.yaml (Component)
└── platform-catalog/catalog-info.yaml     (System + Domain + 2 Resources + 3 Groups)
```

## `orders-api/catalog-info.yaml` (modelo)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  description: HTTP API that creates and queries orders.
  tags: [python, fastapi, tier-1]
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
    backstage.io/kubernetes-id: orders-api
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
  system: orders
  providesApis:
    - orders-api-v1
  dependsOn:
    - resource:orders-db
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-api-v1
  description: Orders REST API v1.
spec:
  type: openapi
  lifecycle: production
  owner: group:orders-team
  system: orders
  definition: |
    openapi: 3.0.0
    info: { title: Orders API, version: 1.0.0 }
    paths: {}
```

## `payments-worker/catalog-info.yaml` (modelo)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payments-worker
  description: Async worker that charges orders and emits events.
  tags: [python, worker, tier-1]
  annotations:
    github.com/project-slug: acme/payments-worker
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
  system: orders
  providesApis:
    - orders-events-v1
  dependsOn:
    - resource:orders-db
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-events-v1
  description: Order lifecycle events (AsyncAPI).
spec:
  type: asyncapi
  lifecycle: production
  owner: group:orders-team
  system: orders
  definition: |
    asyncapi: 2.6.0
    info: { title: Orders Events, version: 1.0.0 }
    channels: {}
```

## `notifications-sender/catalog-info.yaml` (modelo)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: notifications-sender
  description: Consumes order events and sends email notifications.
  tags: [python, worker, tier-2]
  annotations:
    github.com/project-slug: acme/notifications-sender
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:comms-team
  system: orders
  consumesApis:
    - orders-events-v1
  dependsOn:
    - resource:orders-receipts-bucket
```

## `platform-catalog/catalog-info.yaml` (modelo)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: commerce
spec:
  owner: group:commerce-leadership
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: orders
spec:
  owner: group:orders-team
  domain: commerce
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: orders-db
spec:
  type: database
  owner: group:orders-team
  system: orders
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: orders-receipts-bucket
spec:
  type: object-store
  owner: group:comms-team
  system: orders
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: orders-team
spec:
  type: team
  profile: { displayName: Orders Team }
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: comms-team
spec:
  type: team
  profile: { displayName: Communications Team }
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: commerce-leadership
spec:
  type: team
  profile: { displayName: Commerce Leadership }
```

## Grafo que genera (ASCII)

```
                     Domain: commerce
                            │
                            ▼
                       System: orders
             ┌──────────────┼──────────────────┐
             ▼              ▼                  ▼
    Component:         Component:          Component:
    orders-api         payments-worker     notifications-sender
         │                  │                      │
    providesApi       providesApi            consumesApi
         ▼                  ▼                      │
    API:              API:                         │
    orders-api-v1     orders-events-v1 ◄───────────┘
                                 (misma API)
         │                  │                      │
    dependsOn          dependsOn               dependsOn
         ▼                  ▼                      ▼
    Resource:         Resource:              Resource:
    orders-db         orders-db              orders-receipts-bucket
```

## Punto a repetir hasta que suene aburrido

> El catálogo es **grafo**, no lista. Cada relación es una pregunta de impacto respondible sin salir de Backstage. **Relación muerta = agujero en tu operación**.
