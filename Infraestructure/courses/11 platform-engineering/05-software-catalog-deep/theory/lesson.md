# plat-05 — Lección: el Software Catalog en serio

> 12 secciones. Prerrequisito: `plat-04` (Backstage levantado al menos una vez). Las actividades validan estructuralmente con `python3` + `pyyaml`; **no** hace falta Backstage corriendo.

---

## 1. Qué es el catálogo (y qué no es)

El **Software Catalog** de Backstage es un **inventario tipado** de todo lo que un platform team necesita saber sobre el software de la organización: servicios, APIs, bases de datos, dashboards, pipelines, equipos y personas. Cada ítem es una **entity** con un **kind**, una **metadata** y una **spec**.

> **Idea clave que repetiremos:** el catálogo es la **fuente de verdad del inventario**, **no** un wiki. Un wiki describe prosa; un catálogo describe entidades con relaciones consultables y procesables por plugins.

Un catálogo bien modelado permite responder, sin abrir un ticket y sin preguntar en Slack:

- *"¿Quién es el owner del servicio `checkout-api`?"*
- *"¿Qué servicios dependen del API `payments-v1`? Si la deprecamos, ¿a quién hay que avisar?"*
- *"¿Qué equipos tienen hoy on-call activo para servicios en `tier=critical`?"*
- *"¿Qué servicios no tienen owner declarado? (deuda a saldar)."*

Un catálogo mal modelado — con relaciones inventadas, annotations vacías y owners "platform-team" en todo — **degrada** hasta el punto de volverse ruido que nadie consulta.

---

## 2. El entity model: `apiVersion`, `kind`, `metadata`, `spec`

Todas las entidades siguen la misma plantilla (muy parecida a Kubernetes a propósito):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-api
  description: Servicio HTTP de checkout
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
  dependsOn:
    - resource:checkout-db
```

- `apiVersion` — hoy `backstage.io/v1alpha1` para kinds core; otros plugins añaden sus propias apiVersions (`scaffolder.backstage.io/v1beta3`, por ejemplo, para templates).
- `kind` — **Component**, **API**, **Resource**, **System**, **Domain**, **User**, **Group**, **Location**. Cada uno con su `spec` propia.
- `metadata.name` — identificador único **dentro del kind**. Convención: lowercase, kebab-case. Caracteres válidos: `[a-z0-9-]`.
- `metadata.annotations` — pares `clave: valor` que **plugins** consumen (nunca se usa para prosa libre; para eso está `description`).
- `spec` — campos específicos por kind. Casi todos requieren `owner`.

> **Trampa #1 del novato:** confundir `description` (prosa libre, para humanos) con `annotations` (pares consumidos por plugins). Prosa en annotations **rompe** los plugins silenciosamente.

---

## 3. Los 8 kinds principales

### 3.1 Component

Un **Component** es "una pieza de software que un equipo mantiene": un microservicio, una web app, una CLI, una librería. Es el kind **más común** y el que vive en cada repo.

- `spec.type`: `service`, `website`, `library`, `tool` (lista no cerrada, convenciones por org).
- `spec.lifecycle`: `production`, `experimental`, `deprecated`.
- `spec.owner`: `group:<nombre>` (preferido) o `user:<nombre>`.
- `spec.system`: a qué sistema pertenece (opcional pero muy recomendado).
- `spec.providesApis` / `spec.consumesApis` / `spec.dependsOn` — relaciones (ver §4).

### 3.2 API

Un **API** modela un **contrato** entre Components: una API REST, una API gRPC, una queue, un topic Kafka, un GraphQL schema. **No es** el servicio que la implementa; es la **interfaz**.

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: checkout-api-v1
spec:
  type: openapi        # openapi | grpc | asyncapi | graphql | ...
  lifecycle: production
  owner: group:payments-team
  system: checkout
  definition: |
    openapi: 3.0.0
    info:
      title: Checkout API
      version: 1.0.0
    paths:
      /checkout:
        post: { summary: Crear un pedido }
```

Modelar la API como entidad **separada** del Component permite que varios Components la **consuman** (`consumesApis: [checkout-api-v1]`) y uno (o varios) la **provean** (`providesApis: [checkout-api-v1]`).

### 3.3 Resource

Un **Resource** modela una pieza de **infraestructura** de la que depende un Component: una base de datos, un bucket S3, una Kafka cluster, un KMS key. Es lo que no cabe como "mi código" ni como "una API expuesta por otro servicio".

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: checkout-db
spec:
  type: database
  owner: group:payments-team
  system: checkout
```

### 3.4 System

Un **System** agrupa Components, APIs y Resources que **conjuntamente** entregan una capacidad de negocio. Ejemplo: el system `checkout` agrupa `checkout-api` (Component), `checkout-worker` (Component), `checkout-api-v1` (API) y `checkout-db` (Resource).

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: checkout
spec:
  owner: group:payments-team
  domain: commerce
```

### 3.5 Domain

Un **Domain** agrupa Systems de la misma área de negocio. Ejemplo: el domain `commerce` agrupa los systems `checkout`, `cart`, `catalog`. Son útiles cuando la org tiene docenas de systems y hace falta un nivel más de agregación.

### 3.6 User y Group

- **User** representa a una persona (ligada al login via auth provider).
- **Group** representa a un equipo. Los `owner` de las entidades deberían ser **Groups**, no Users individuales — un User se va de la empresa, un Group persiste.

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: payments-team
spec:
  type: team
  profile:
    displayName: Payments Team
  parent: engineering
  children: []
  members:
    - alice
    - bob
```

### 3.7 Location

Un **Location** no es una entidad "de software": es una **referencia** a dónde encontrar más `catalog-info.yaml`. Es el mecanismo de **ingesta manual** (ver §5).

```yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: payments-services
spec:
  type: url
  targets:
    - https://github.com/acme/checkout-api/blob/main/catalog-info.yaml
    - https://github.com/acme/payments-worker/blob/main/catalog-info.yaml
```

Es el equivalente a un `import` o a un `include`. Backstage sigue esas URLs, lee los `catalog-info.yaml` destino y los procesa como entidades reales.

---

## 4. Relaciones: `providesApi`, `consumesApi`, `dependsOn`, `partOf`, `memberOf`

Las relaciones son lo que convierte el catálogo en **grafo** y no en una lista plana. Son el 80 % del valor del catálogo bien modelado.

| Relación | Entre | Semántica |
|----------|-------|-----------|
| `providesApis` | Component → API | "este Component implementa este contrato" |
| `consumesApis` | Component → API | "este Component llama a este contrato" |
| `dependsOn` | Component → Component / Resource | "este Component necesita este otro para funcionar" |
| `partOf` | Component / API / Resource → System; System → Domain | "esto pertenece a aquel grupo lógico" |
| `memberOf` | User → Group | "esta persona está en este equipo" |
| `hasPart` (inverso de `partOf`) | derivada por Backstage | permite ver desde el System quiénes son sus hijos |
| `apiProvidedBy` / `apiConsumedBy` (inversas) | derivadas | desde el API ves quién la implementa y quién la consume |

> **Lo que habilita el grafo:** la pregunta *"si deprecamos el API `payments-v1`, ¿quién se rompe?"* se contesta con una query de 1 línea sobre `apiConsumedBy`. Sin relaciones, se contesta mandando un email a toda la empresa y rezando.

Reglas de higiene:

- `owner` **siempre** apunta a un Group existente (no uses `group:unknown`).
- `dependsOn` debe reflejar dependencia **real en runtime**, no "tenemos el mismo repo padre".
- `providesApis` debe tener contrapartida con una entidad `API` real, no un string inventado.
- No crees relaciones cíclicas (`A dependsOn B dependsOn A`) — el catálogo las acepta pero semánticamente son un *smell*.

---

## 5. Processors y providers: cómo entra la data

Backstage separa **cómo descubre** entidades (**providers**) de **cómo las procesa** (**processors**).

### 5.1 Ingesta manual con `Location`

El patrón más simple: registras una `Location` apuntando a un `catalog-info.yaml` en un repo. Backstage lo lee, lo valida y guarda las entidades.

```yaml
# app-config.yaml
catalog:
  locations:
    - type: url
      target: https://github.com/acme/checkout-api/blob/main/catalog-info.yaml
```

Útil para empezar o para ingresar entidades únicas (p. ej., Groups centralizados). **No escala** a una org con 300 repos — tendrías 300 líneas en `app-config.yaml`.

### 5.2 Descubrimiento con `GithubEntityProvider`

Para escalar: el `GithubEntityProvider` **recorre** una org (o un conjunto de repos filtrados por topic / regex) y auto-descubre todo `catalog-info.yaml` que exista.

```yaml
catalog:
  providers:
    github:
      production:
        organization: 'acme'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          repository: '.*'   # regex sobre nombre
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

Resultado: cada repo que tenga un `catalog-info.yaml` en la raíz de `main` se registra automáticamente. Los repos que **no** lo tengan quedan **invisibles** para el catálogo — eso es el *driver* para que los equipos lo añadan.

### 5.3 Processors (recursivo)

El procesador por defecto, al leer un `catalog-info.yaml`, lo valida contra el schema del `kind`, resuelve relaciones, y si el documento es un `Location`, **sigue** los `targets` y procesa esos también. Así, un `Location` central puede apuntar a 50 repos y Backstage descubre todo transitivamente.

### 5.4 Otros providers útiles

- `GitLabDiscoveryEntityProvider`, `BitbucketDiscoveryEntityProvider` — equivalentes a GitHub.
- `AWSEntityProvider`, `GcpEntityProvider` — descubren recursos cloud y los crean como `Resource` entities automáticamente.
- `LdapOrgEntityProvider`, `MicrosoftGraphOrgEntityProvider` — descubren Users y Groups desde el directorio corporativo.
- Custom providers — se escriben en TS cuando ninguno encaja (p. ej., leer de un Service Registry propio).

---

## 6. Annotations: la bisagra con los plugins

Las `annotations` del catálogo son **cómo los plugins encuentran la data** que necesitan sobre una entidad. Sin ellas, los plugins muestran una pantalla vacía con el mensaje "configure the annotation `foo/bar`".

Catálogo mínimo de annotations que todo Component serio debería tener:

| Annotation | Plugin que la consume | Qué habilita |
|------------|----------------------|--------------|
| `github.com/project-slug` | GitHub plugin | releases, PRs, issues, workflow runs |
| `backstage.io/techdocs-ref` | TechDocs | docs renderizadas desde `/docs` del repo |
| `backstage.io/kubernetes-id` o `backstage.io/kubernetes-label-selector` | Kubernetes plugin | pods, deployments, logs por Component |
| `argocd/app-selector` | Argo CD plugin | sync status, history, rollback |
| `pagerduty.com/integration-key` | PagerDuty plugin | on-call actual, incidents abiertos |
| `grafana/dashboard-selector` | Grafana plugin | dashboards embebidos |
| `sonarqube.org/project-key` | SonarQube plugin | quality gate, cobertura, bugs |

> **Trampa #2 del novato:** poner la annotation con el **valor** mal formado (p. ej., `github.com/project-slug: https://github.com/acme/foo`). El valor correcto es `acme/foo`. Cada plugin tiene su propio formato — hay que leer la doc del plugin.

Regla operativa: **cada Component que entra al catálogo debe traer al menos 2 annotations útiles**, elegidas según los plugins instalados en tu Backstage. Si todas tus annotations son `backstage.io/techdocs-ref: dir:.`, el catálogo es solo un wiki tipado.

---

## 7. "Fuente de verdad del inventario" en la práctica

Decir "el catálogo es la fuente de verdad" implica tres compromisos operativos:

1. **Toda entidad nueva se crea con un `catalog-info.yaml` en el repo que la contiene.** No hay creación manual via UI (eso convierte el catálogo en wiki). El Scaffolder (plat-06) materializa esto: cada template produce un `catalog-info.yaml` como parte del scaffolding.
2. **Si una entidad no está en el catálogo, no existe para la plataforma.** Esto es duro al principio ("¿y mi servicio legacy sin `catalog-info.yaml`?") pero es el único driver real para que todo entre.
3. **Se protege con hooks pre-commit y validación en CI.** Si un `catalog-info.yaml` entra roto a `main`, el provider lo rechaza y la entidad desaparece del catálogo — pérdida silenciosa. La actividad `02-pre-commit-validate-catalog-info` cubre esto.

**Sin estos tres compromisos**, el catálogo degrada en 6 meses: entidades fantasma (quedaron en el catálogo pero el repo ya no existe), entidades sin owner (el equipo migró y nadie actualizó), relaciones a entidades inexistentes.

---

## 8. Vistas de impacto: por qué modelar bien compensa

Un catálogo bien modelado habilita, sin trabajo extra, un conjunto de **vistas** que son el pan y la mantequilla del platform team:

- **Vista por owner:** "todos los Components de `payments-team`".
- **Vista por system:** "todas las entidades del system `checkout` — Components, APIs, Resources".
- **Vista por API:** "quién provee y quién consume `payments-v1`".
- **Vista por lifecycle:** "qué Components están en `deprecated` y qué los consume aún".
- **Vista de dependencias:** grafo de `dependsOn` para hacer análisis de blast radius.
- **Vista sin owner:** la lista negra — Components en el catálogo con `owner: unknown` o Group inexistente.

Estas vistas son queries sobre el grafo. Backstage las expone en la UI (plugin `catalog-graph`) y via API REST (`/api/catalog/entities?filter=kind=component,spec.owner=group:payments-team`). Un CI job puede llamar al endpoint y abrir issues automáticos cuando aparece un Component sin owner.

---

## 9. Cómo evitar que el catálogo se vuelva stale

El antipatrón **"catálogo museo"** es: entidades viejas, relaciones a APIs que ya no existen, annotations con proyectos de GitHub archivados. Prevención:

1. **Pre-commit en cada repo** que valida `catalog-info.yaml` (sintaxis + schema + presencia de owner + annotations mínimas). → `activities/02`.
2. **CI job** en el repo central que, cada noche, consulta la API del catálogo y abre issues cuando:
   - Un Component está sin owner.
   - Un `consumesApis` apunta a un API inexistente.
   - Un `dependsOn` apunta a un Resource inexistente.
3. **Scorecard** (plat-10) que puntúa cada Component por calidad de su entrada en el catálogo. Equipos con score bajo saben qué arreglar.
4. **Deprecation policy**: cuando un servicio se apaga, el PR que lo apaga debe también borrar su `catalog-info.yaml` o cambiarlo a `lifecycle: deprecated`. **Checklist en el PR template.**
5. **Scheduled sync** del `GithubEntityProvider` lo suficientemente alto (30 min por defecto) para que cambios se reflejen rápido; no demasiado alto para no castigar la API de GitHub.

> El catálogo se mantiene **al día** solo si entra en el flujo diario de los equipos. Si vivir fuera de él es más fácil que vivir dentro, muere.

---

## 10. Importación gradual de un parque existente

Caso real: llegas a una org con 180 repos, 60 servicios en producción, cero `catalog-info.yaml`. Si pides que todos abran PR el mismo día, el proyecto fracasa.

Estrategia que funciona:

1. **Fase 0 — modelo mínimo central.** El platform team crea en un repo propio: todos los `Group`, todos los `Domain` principales (3–5), los `System` conocidos (10–15). Se publican via `Location` manual en `app-config.yaml`. **No se pide nada a los equipos todavía.**
2. **Fase 1 — pilot con 2 equipos.** Dos equipos amigos (los primeros adopters) añaden `catalog-info.yaml` a sus repos. El platform team los ayuda a mano. Se celebra la primera vista "mis servicios aparecen en Backstage".
3. **Fase 2 — plantilla + pre-commit.** El platform team publica un **template de Backstage** (plat-06) que genera un `catalog-info.yaml` listo. Los nuevos servicios **ya nacen** en el catálogo. Pre-commit hook disponible para repos que lo añadan.
4. **Fase 3 — provider en modo descubrimiento.** Se activa `GithubEntityProvider` sobre toda la org. Lo que esté, entra; lo que no, no. Los equipos ven a sus pares aparecer y se contagian.
5. **Fase 4 — scorecard pública.** % de servicios con entrada en el catálogo publicado en un dashboard. Cuando un director lo ve en una review, la adopción se acelera sola.
6. **Fase 5 — endurecer.** Mandato suave: *"nuevo servicio en producción = entrada en catálogo o no se despliega"*. Pre-commit obligatorio en los repos del golden path.

Lo que **no** se hace: migrar todo manualmente por el platform team. Eso convierte al platform team en un *ticket queue* y rompe la propuesta de X-as-a-Service.

---

## 11. Errores habituales (y cómo diagnosticar un catálogo "ruidoso")

Síntomas y causas más frecuentes:

| Síntoma | Causa habitual | Fix |
|---------|----------------|-----|
| Un Component aparece "sin owner" | `spec.owner` apunta a un `group:X` que no existe en el catálogo | crear el Group o corregir el nombre |
| Un API no muestra "providers / consumers" | nadie declaró `providesApis` / `consumesApis` apuntándole | añadir relaciones en los Components |
| El plugin GitHub no muestra nada | `github.com/project-slug` mal formado (URL completa en vez de `org/repo`) | corregir el valor |
| El plugin Kubernetes muestra "no resources" | falta `backstage.io/kubernetes-id` o el valor no coincide con la label del Pod | poner la label en el chart |
| El catálogo tiene 15 copias del mismo Component | varios `catalog-info.yaml` con el mismo `metadata.name` | el name debe ser único **por kind** en toda la org |
| Entidades que no se actualizan | `GithubEntityProvider.schedule` muy alto, o el repo cambió de nombre | bajar frecuencia o re-registrar |
| Relaciones aparecen y desaparecen | el `catalog-info.yaml` se valida y falla en algunas corridas | hook pre-commit no se está aplicando — hacer validación estructural obligatoria |

Herramienta mental para auditar un catálogo nuevo: contar **Components sin owner**, **APIs sin providers**, **Resources sin consumers**, **Groups sin members**. Cualquier número alto en estas 4 categorías es señal clara de que falta disciplina de annotations o que el provider está mal configurado.

---

## 12. Qué llevarse

Al terminar este módulo deberías poder:

- Diseñar la estructura **Domains → Systems → (Components / APIs / Resources)** para una organización dada.
- Escribir un `catalog-info.yaml` para un Component real con owner correcto, system, 2+ annotations útiles y relaciones a APIs / Resources.
- Decidir entre `Location` manual y `GithubEntityProvider` según el tamaño de la org.
- Diagnosticar un catálogo "ruidoso" nombrando las 4 métricas de higiene (components sin owner, APIs sin providers, resources sin consumers, groups sin members).
- Proteger un repo con un hook pre-commit que impide commits con `catalog-info.yaml` mal formado.

Una síntesis de una línea:

> **El Software Catalog de Backstage es un grafo tipado de entidades (Components, APIs, Resources, Systems, Domains, Users, Groups) relacionadas entre sí; su valor es exactamente el valor de la disciplina con que la organización lo mantenga.**

Lo que **sigue**:

- `plat-06` — Templates / Scaffolder: cómo convertir cada entrada deseada del catálogo en un *botón* que crea repo + CI + chart + entry.
- `plat-07` — TechDocs: cómo la annotation `backstage.io/techdocs-ref` renderiza docs del repo dentro de Backstage.
- `plat-08` — Plugins: cada annotation vista en §6 corresponde a un plugin que la consume.
