# Ejemplo 01 — Anatomía de `catalog-info.yaml`

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria la **estructura mínima** vs la **estructura completa** de un `catalog-info.yaml` y los **errores habituales** que cometen los equipos cuando lo escriben por primera vez.

## 1. El mínimo que Backstage acepta

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: hello-service
spec:
  type: service
  lifecycle: production
  owner: group:platform-team
```

Esto **se registra** y aparece en el catálogo. Pero no es útil: sin `description`, sin `system`, sin `annotations`, sin relaciones, Backstage es poco más que una fila en una tabla.

## 2. El mínimo útil (lo que un platform team debería exigir)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-api
  description: HTTP API that creates and queries checkout orders.
  tags: [python, fastapi, tier-1]
  annotations:
    github.com/project-slug: acme/checkout-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:payments-team
  system: checkout
  providesApis:
    - checkout-api-v1
```

Qué añade sobre el mínimo:

- `description` humano (prosa corta, 1–2 líneas).
- `tags` para filtrar en la UI.
- 2 `annotations` que habilitan plugins (GitHub, TechDocs).
- `system` para que la entidad aparezca agrupada.
- `providesApis` para que la API sea descubrible desde el Component.

## 3. El completo (producción)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-api
  description: HTTP API that creates and queries checkout orders.
  tags: [python, fastapi, tier-1]
  links:
    - url: https://wiki.acme.io/checkout-api
      title: Runbook
      icon: docs
    - url: https://grafana.acme.io/d/checkout-api
      title: Dashboard
      icon: dashboard
  annotations:
    github.com/project-slug: acme/checkout-api
    backstage.io/techdocs-ref: dir:.
    backstage.io/kubernetes-id: checkout-api
    argocd/app-selector: app=checkout-api
    pagerduty.com/integration-key: XXXXXXXX
    grafana/dashboard-selector: "folder:checkout"
    sonarqube.org/project-key: acme_checkout-api
spec:
  type: service
  lifecycle: production
  owner: group:payments-team
  system: checkout
  providesApis:
    - checkout-api-v1
  consumesApis:
    - fraud-score-api-v2
  dependsOn:
    - resource:checkout-db
    - resource:checkout-cache
    - component:notifications-worker
```

Observa cómo cada annotation habilita un plugin distinto, y cómo las relaciones (`providesApis`, `consumesApis`, `dependsOn`) hacen el grafo real.

## 4. Los 7 errores habituales (y cómo detectarlos)

### 4.1 `name` con mayúsculas o caracteres inválidos

```yaml
metadata:
  name: CheckoutAPI   # ERROR: debe ser lowercase kebab-case
```

Backstage rechaza silenciosamente la entidad. La regex válida es `[a-z0-9]([-a-z0-9]*[a-z0-9])?`.

### 4.2 `owner` apuntando a un Group inexistente

```yaml
spec:
  owner: group:ninja-squad   # el group 'ninja-squad' no existe en el catalogo
```

La entidad se registra pero aparece "sin owner" en la UI. Solución: declarar el Group primero (o usar un Group ya conocido).

### 4.3 Annotation con **URL completa** cuando se esperaba `org/repo`

```yaml
annotations:
  github.com/project-slug: https://github.com/acme/checkout-api   # MAL
```

Debe ser:

```yaml
annotations:
  github.com/project-slug: acme/checkout-api                      # BIEN
```

El plugin de GitHub falla sin un error visible — simplemente no muestra releases ni PRs.

### 4.4 `description` dentro de `annotations`

```yaml
annotations:
  description: Este servicio hace checkout...   # MAL — prosa en annotations
```

`description` va en `metadata.description`, no en annotations. Annotations son pares consumidos por plugins; prosa libre va fuera.

### 4.5 `providesApis` sin entidad `API` correspondiente

```yaml
spec:
  providesApis:
    - checkout-api-v1   # pero NO existe un kind:API con metadata.name=checkout-api-v1
```

La relación aparece "muerta" en el catalog-graph. Hay que crear la entidad `API` (puede estar en el mismo `catalog-info.yaml` como documento YAML adicional separado por `---`).

### 4.6 Un `catalog-info.yaml` con varios documentos sin separador

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
...
apiVersion: backstage.io/v1alpha1
kind: API
...
```

YAML no entiende dos *root mappings* seguidos. Para dos entidades en el mismo archivo, usar separador `---`:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
...
---
apiVersion: backstage.io/v1alpha1
kind: API
...
```

### 4.7 `spec.type` con un valor que la org no reconoce

Backstage no valida los valores de `spec.type` (es string libre). Pero la UI y los scorecards sí los usan. Si en tu org se decidió `service | website | library | tool` y alguien pone `backend`, se rompe el filtrado.

Fix organizacional: definir vocabulario cerrado y validarlo con el pre-commit (actividad 02).

## 5. Patrón: varios kinds en el mismo repo

Cuando un servicio implementa **una** API, es común tener los dos en el mismo `catalog-info.yaml`:

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
  definition:
    $text: ./openapi.yaml
```

El `$text: ./openapi.yaml` le dice a Backstage que lea el contenido del archivo `openapi.yaml` del mismo repo. Así el spec vive junto al código sin duplicarse en el `catalog-info.yaml`.

## 6. Preguntas de autocomprobación

1. ¿Por qué `owner` siempre debería ser un `group:` y no un `user:`?
2. Si tu repo tiene un `catalog-info.yaml` pero `metadata.name` colisiona con otro repo, ¿qué pasa?
3. ¿Dónde pondrías la annotation `backstage.io/kubernetes-id` si tu servicio corre en 2 namespaces distintos (dev y prod)?
4. ¿Qué ventaja tiene usar `$text: ./openapi.yaml` en lugar de pegar el OpenAPI literal dentro del `catalog-info.yaml`?
5. En la lista de los 7 errores, ¿cuál es el **más silencioso** (el que menos síntomas da)? ¿Y el más fácil de atrapar con pre-commit?

Las respuestas se trabajan en la actividad `01-model-capstone-in-catalog/`.
