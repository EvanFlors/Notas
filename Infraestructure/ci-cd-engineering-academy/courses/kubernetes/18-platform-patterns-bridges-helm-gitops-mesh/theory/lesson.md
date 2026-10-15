# Lección — Platform Patterns sobre Kubernetes

> Módulo **puente**. No reemplaza los cursos de Helm, Argo CD/GitOps ni los módulos de observabilidad y seguridad: les da contexto arquitectónico y los integra en una **plataforma** coherente.

Convención: prosa en español, código en inglés.

Índice:

1. ¿Qué es una "plataforma" sobre Kubernetes?
2. Capa de empaquetado: Helm vs Kustomize.
3. GitOps como modelo operativo: Argo CD y Flux.
4. Escalar GitOps: ApplicationSet, app-of-apps, repo-of-repos.
5. Service mesh: qué resuelve y qué cuesta.
6. Cuándo (y sobre todo) cuándo **no** introducir un mesh.
7. Internal Developer Platforms: Backstage, Crossplane y "golden paths".
8. Cost management: OpenCost y Kubecost.
9. Platform SLOs y contratos plataforma ↔ producto.
10. Ciclo de vida de la plataforma: versiones, deprecations, soporte.
11. Mapa mental: cuándo introducir cada pieza.
12. Checklist de decisión y errores comunes.

---

## 1. ¿Qué es una "plataforma" sobre Kubernetes?

Un cluster Kubernetes "pelado" entrega una API y un scheduler. **No** entrega una plataforma. Una plataforma es el conjunto de servicios transversales que los equipos de producto consumen sin pensar en el cluster:

```
+----------------------------------------------------------+
|                     Developer / App team                 |
|   (code, Dockerfile, manifests o chart, PR, telemetry)   |
+----------------------------+-----------------------------+
                             | consume via "golden path"
                             v
+----------------------------------------------------------+
|           Platform (contracted, versioned, SLO'd)        |
|  CI/CD  |  GitOps  |  Secrets  |  Policy  |  Observ.    |
|  Helm   |  ArgoCD  |  ESO/Vault|  Kyverno |  Prom+OTel  |
|  Mesh?  |  Cost    |  Backup   |  Ingress |  Logs/Traces|
+----------------------------+-----------------------------+
                             | provisions / observes
                             v
+----------------------------------------------------------+
|                        Kubernetes API                     |
|   (clusters, nodes, CNI, CSI, control plane)              |
+----------------------------------------------------------+
```

La pregunta del módulo es: **qué cajas aparecen en la capa Platform y en qué orden**. La respuesta por defecto es *menos cajas, más tarde*.

Dos clases de cliente:

- **Plataforma como *producto* interno**: tiene usuarios (devs), roadmap, SLOs, deprecations.
- **Plataforma como *script compartido***: zip de helm charts en GitHub, nadie lo mantiene. Anti-patrón frecuente.

---

## 2. Capa de empaquetado: Helm vs Kustomize

Un cluster Kubernetes consume YAML. La capa de empaquetado decide **cómo lo generamos y versionamos**. Hay dos escuelas vigentes:

### Helm (templating + release lifecycle)

- Un **chart** es un paquete versionado con `Chart.yaml`, `values.yaml`, `templates/` (Go templates sobre YAML) y, opcionalmente, `charts/` para dependencias.
- Un **release** es una instalación de un chart en un cluster con un `name`, un `namespace`, y un conjunto de `values` resueltos. Helm guarda la historia (install, upgrade, rollback) como Secrets en el namespace.
- Las **dependencies** (`Chart.yaml: dependencies:`) permiten componer. Ejemplo: un chart de app que depende de `postgresql`.
- **OCI registries para charts**: desde Helm 3, los charts se pueden publicar en registries OCI (ECR, GHCR, Harbor) como cualquier imagen. Esto unifica supply chain (firma con cosign aplicable).

Fortalezas:
- Modelo mental de *release* (instalar, upgrade, rollback) explícito.
- Enorme ecosistema de charts upstream (`ingress-nginx`, `cert-manager`, `kube-prometheus-stack`, operadores).
- Hooks (`pre-install`, `post-upgrade`) para orquestación.

Debilidades:
- Templating sobre YAML es **frágil**: espacios, indentación, "quién puso un `-` ahí".
- "Values matrix": `values.yaml` × overrides × secretos × entornos = complejidad real.
- Debug de un chart no trivial (`helm template`, `helm diff`, pero sigue siendo texto).

### Kustomize (overlays declarativos)

- **Sin lenguaje de plantillas**. Un `base/` con YAML plano + overlays (`overlays/prod/`, `overlays/stage/`) que aplican patches (`strategic merge`, `JSON6902`) sobre esa base.
- Integrado en `kubectl apply -k`.
- Composición por `components`, `resources`, `patches`, `images`, `replicas`, `configMapGenerator`, `secretGenerator`.

Fortalezas:
- No introduce un lenguaje nuevo; el output es YAML plano reviewable.
- Diferencias entre entornos son **explícitas** en los overlays.
- Ideal para "la misma app, 4 entornos con 10 diferencias" sin plantillas.

Debilidades:
- No tiene *release lifecycle*: no hay `rollback` ni `history` nativos; se delega a GitOps/Git.
- No tiene packaging-para-redistribución comparable al ecosistema de charts.
- Patches sobre bases profundas se vuelven ilegibles.

### Decisión práctica

| Caso | Elección razonable |
|------|--------------------|
| Consumir software upstream (operadores, ingress, monitoring stack). | **Helm** (sin discusión). |
| App propia, 2–4 entornos, control total del YAML. | **Kustomize** limpio. |
| App propia distribuida a terceros. | **Helm** chart. |
| App propia + varios entornos + GitOps estricto. | Kustomize *o* Helm *o* ambos (Helm para upstream, Kustomize para in-house). |

Es común y sano **combinarlos**: `kube-prometheus-stack` via Helm, apps internas via Kustomize, Argo CD orquesta ambos.

---

## 3. GitOps como modelo operativo: Argo CD y Flux

**GitOps** = Git es la **fuente de verdad** del estado deseado del cluster y un agente dentro del cluster reconcilia continuamente.

Principios (CNCF):
1. **Declarativo** — el sistema se describe por completo.
2. **Versionado e inmutable** — Git como historial.
3. **Pull automatizado** — un agente en el cluster hace *pull*; **no** CI haciendo *push* con `kubectl`.
4. **Reconciliación continua** — se corrige drift sin intervención.

### Modelo pull vs push

```
Push (CI/CD clásico)                 Pull (GitOps)
+-----------+                        +-----------+
|  CI job   |---kubectl apply--->    |   Git     |
+-----------+                        +-----+-----+
     |                                     | watch
     v                                     v
+-----------+                        +-----------+
| Cluster   |                        |  Agent in |
|           |                        |  cluster  |---apply---> Cluster
+-----------+                        +-----------+
```

Ventajas del pull:
- Credenciales del cluster **nunca salen** del cluster (CI no necesita `cluster-admin`).
- Drift detection "gratis": el agente ve lo real y lo deseado todo el tiempo.
- Rollback = `git revert`.

### Argo CD

- Controller + servidor API + UI web + CLI.
- Objeto central: `Application` (CR) con `source` (repo + path + revision), `destination` (cluster + namespace), `syncPolicy` (manual, automatic, selfHeal, prune).
- Soporta Helm, Kustomize, Jsonnet, plain YAML, plugins.
- UI rica (árbol de recursos, diff, sync, rollback).

### Flux

- Varios controllers (`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`, `image-reflector/automation-controller`).
- Más "unix-y": compón lo que necesitas.
- Sin UI oficial (hay terceras). Toda la operación es `kubectl` + CRs.
- Image automation nativo: puede abrir PRs cuando aparece una tag nueva.

### Comparación rápida

| | Argo CD | Flux |
|-|---------|------|
| UI | sí, rica | no (hay terceras) |
| Modelo | monolítico (un controller + API) | microservicios (varios controllers) |
| Multi-tenant | AppProjects, SSO | namespaces + RBAC |
| Image automation | con Argo CD Image Updater (addon) | nativo |
| Curva | baja (UI ayuda) | media |
| ApplicationSet equivalent | `ApplicationSet` (nativo) | `Kustomization` con generators, `ImagePolicy` |

Elegir uno. Mezclar los dos en el mismo cluster es un lujo caro.

---

## 4. Escalar GitOps: ApplicationSet, app-of-apps, repo-of-repos

Un `Application` por servicio × entorno escala mal. Hay dos patrones y una CR.

### App-of-apps

Un `Application` "raíz" que apunta a un path con **otros** `Application` manifests. Argo CD aplica los hijos. El root se bootstrap-ea a mano y luego "todo cuelga de ahí".

```
       root-app
          |
    +-----+------+------+
    |     |      |      |
  app-a app-b  app-c  app-...
    |
  subapps (opcional)
```

### Repo-of-repos

Variante donde el repo "root" solo contiene punteros a repos por app o por equipo. Útil para delegar ownership.

### ApplicationSet (recomendado)

Un `ApplicationSet` con **generators** produce N `Application` dinámicamente.

Generators comunes:
- **List**: lista estática de entornos.
- **Cluster**: una app por cluster registrado.
- **Git (directories/files)**: una app por carpeta/archivo en un repo.
- **Matrix**: producto cartesiano (p. ej. clusters × apps).
- **Pull Request**: ephemeral env por cada PR abierto.

```yaml
# ejemplo didáctico, no copiar sin leer la referencia
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: web-across-clusters
spec:
  generators:
    - clusters: {}
  template:
    metadata:
      name: 'web-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/acme/web
        targetRevision: main
        path: deploy/overlays/{{metadata.labels.env}}
      destination:
        server: '{{server}}'
        namespace: web
      syncPolicy:
        automated: {prune: true, selfHeal: true}
```

Con esto, "añadir un cluster" = registrar el cluster; el `ApplicationSet` genera la `Application` sola.

---

## 5. Service mesh: qué resuelve y qué cuesta

Un **service mesh** inyecta un *proxy* (sidecar Envoy, o eBPF/ambient) junto a cada Pod del data plane y añade un *control plane* que lo configura. Resuelve, de forma uniforme y transversal:

- **mTLS automático** entre workloads (identity por ServiceAccount).
- **Observabilidad L7** uniforme (métricas RED, trazas, logs de acceso) sin tocar el código.
- **Traffic shaping** fino: canary por porcentaje, mirroring, retries, timeouts, circuit breakers, outlier detection.
- **Políticas L7**: AuthZ por path/método/header, rate limiting.
- **Multi-cluster service discovery** y mTLS cross-cluster.

### Opciones vigentes

- **Istio** — el "pleno": Envoy sidecar (clásico) o **ambient mode** (ztunnel + waypoint, sin sidecars por Pod). Rico, complejo, ecosistema enorme.
- **Linkerd** — minimalista, proxy en Rust (`linkerd2-proxy`), SMI/propias CRs; opera "fácil" para lo que es un mesh.
- **Cilium Service Mesh** — reutiliza el CNI Cilium (eBPF). mTLS vía Envoy opcional; evita sidecars en varios casos.

### Coste real (hay que medirlo, no estimarlo a ojo)

- CPU/memoria por sidecar (típico: decenas–cientos de MB por Pod y porcentaje de CPU no despreciable; depende de QPS y features activados).
- Latencia P50 aceptable; **P99** puede sufrir con reglas L7 complejas.
- Operabilidad: upgrades del mesh son procedimientos *serios* (control plane + data plane + CRDs + webhooks).
- Debug: un fallo "de red" ahora es "de red *o* del sidecar *o* del control plane del mesh".

### Diagrama (sidecar clásico)

```
+------- Pod ---------+          +------- Pod ---------+
|  app container      |          |  app container      |
|      ^              |          |      ^              |
|      | localhost    |          |      | localhost    |
|  envoy sidecar  <---+--mTLS----+-> envoy sidecar     |
+---------------------+          +---------------------+
          ^                                 ^
          |                                 |
          +---- control plane (istiod) -----+
```

---

## 6. Cuándo (y sobre todo) cuándo **no** introducir un mesh

Regla del módulo: **tarde, no temprano**. Introducir mesh antes de tener claro qué problema resuelve es la vía rápida al burnout operativo.

### Síntomas que **justifican** evaluar un mesh

1. Necesitas **mTLS entre workloads** y los equipos no pueden (o no deben) tocar las apps para hacerlo.
2. Necesitas **observabilidad L7 uniforme** (incluyendo apps de terceros/legacy que no instrumentas).
3. Necesitas **canary/mirroring** finos cross-service y Argo Rollouts/Flagger + Ingress no te alcanzan.
4. Necesitas **AuthZ L7** entre servicios y no quieres (o no puedes) ponerla en cada app.
5. **Multi-cluster** con descubrimiento y mTLS cross-cluster.

### Criterios que deben **cumplirse antes** de introducirlo

- Observabilidad base (Prometheus + Grafana + logs + traces) **ya operativa**.
- Policy framework (Kyverno u OPA) **ya operativo**.
- Al menos una persona FTE con tiempo para operar el mesh (upgrades, incidencias, debugging).
- Presupuesto de CPU/memoria y P99 aceptados por los equipos de producto, con medición previa.
- Plan de rollback (desinstalar o aislar a un namespace).

### Alternativas antes del mesh

- **mTLS** limitado a los pares críticos → cert-manager + SPIFFE/SPIRE opcional, o directamente TLS en la app.
- **Observabilidad L7** → OpenTelemetry instrumentando apps (donde se puede).
- **Canary** → **Argo Rollouts** o **Flagger** + Ingress/Gateway API; no requieren mesh (aunque mesh mejora el shape).
- **AuthZ L7** → en el edge (Gateway + ext_authz) o en la app.

### Default saludable

> *"No service mesh"* es la decisión por defecto hasta que haya **al menos dos** síntomas justificantes y **todos** los criterios "antes" cumplidos. Esta decisión se registra en el ADR del contrato de plataforma.

---

## 7. Internal Developer Platforms: Backstage, Crossplane y "golden paths"

Un **IDP** empaqueta la plataforma como un **producto** que los devs consumen. Combina:

- **Portal** — Backstage (Spotify, CNCF). Catálogo de servicios, docs (TechDocs), templates para scaffold, plugins (Argo CD, Grafana, PagerDuty).
- **Control plane de infra como CRDs** — **Crossplane** expone *providers* (AWS, GCP, Azure, GitHub…) como recursos Kubernetes. Ejemplo: pedir una base de datos aplicando un `Database` CR; Crossplane crea el RDS y expone un `Secret` con las credenciales.
- **Entrega** — Argo CD + Helm/Kustomize.
- **Templates** — Backstage Software Templates + Crossplane Compositions = el "**golden path**": una ruta opinada, probada, soportada, para arrancar un servicio nuevo.

```
Dev --> Backstage ("new service") --> template --> PR --> merge
                                                         |
                                                         v
                                                   Argo CD aplica
                                                         |
                                                         v
                                               Crossplane crea infra
                                                         |
                                                         v
                                               K8s corre workload
```

El "golden path" es **el** entregable de la plataforma. Si cada servicio nuevo se bootstrapea distinto, no hay plataforma: hay un cluster compartido con convenciones orales.

### Cuándo un IDP tiene sentido

- Varios equipos (≥ 4–5) que se repiten las mismas tareas.
- Fricción medible: días desde "necesito un servicio" hasta "deploy en prod".
- Al menos una persona FTE para operar la plataforma.

### Cuándo **no**

- Un equipo pequeño con 2 servicios. Un `Makefile` y un `README` resuelven más barato.

---

## 8. Cost management: OpenCost y Kubecost

Un cluster "misterioso" en la factura cloud es un problema de negocio. Dos proyectos vigentes:

- **OpenCost** — CNCF, open source, especificación del modelo de coste K8s. Instalable como stack simple (OpenCost + Prometheus).
- **Kubecost** — producto comercial sobre OpenCost con UI más rica, multi-cluster, forecasting, integraciones.

### Cómo calculan coste

1. Observan uso por recurso (CPU, memoria, GPU, PV, red) con Prometheus + kube-state-metrics.
2. Aplican precios: cloud pricing API (AWS/GCP/Azure) o `node pricing` custom.
3. Asignan por `namespace`, `deployment`, `pod`, `label` (`team=`, `product=`).
4. Separan recursos **asignados** (requests) de **utilizados** (actuales). Útil para detectar sobre-aprovisionamiento.

### Showback vs chargeback

- **Showback** — se **enseña** el coste a cada equipo. Sin consecuencias financieras directas.
- **Chargeback** — el coste se **factura** internamente al cost center del equipo.

Empieza siempre por showback. Chargeback requiere confianza en los números (y en los labels).

### Diagrama (OpenCost mínimo)

```
+----------------+     scrape     +-----------------+
|   Prometheus   | <------------- | kube-state-mtx  |
|  (metrics)     |                | node-exporter   |
+-------+--------+                | cadvisor        |
        |                         +-----------------+
        v
+----------------+     prices     +-----------------+
|    OpenCost    | <------------- | cloud pricing   |
|   (allocation) |                | (AWS/GCP/Azure) |
+-------+--------+                +-----------------+
        |
        v
+----------------+
|  Dashboard /   |
|  Grafana / API |
+----------------+
```

---

## 9. Platform SLOs y contratos plataforma ↔ producto

La plataforma es **un servicio con usuarios**. Como todo servicio:

- Tiene **SLIs** medibles.
- Tiene **SLOs** publicados.
- Tiene **soporte** (horario, canales, severidades).
- Tiene **contratos** con sus consumidores.

### SLIs/SLOs típicos de plataforma

| SLI | Ejemplo de SLO |
|-----|----------------|
| Disponibilidad del plano de GitOps | 99.5% de syncs sin error de infra |
| Latencia de deploy end-to-end (PR merged → prod healthy) | p95 ≤ 15 min |
| Tiempo medio de upgrade del cluster | ≤ 2 h con zero incidencias de app |
| MTTR de incidencias de plataforma | p90 ≤ 1 h |
| Freshness del cost dashboard | datos ≤ 24 h |

### Contrato plataforma ↔ producto

El contrato explicita:

- Qué **ofrece** la plataforma (ingress, mTLS, observabilidad, secretos, backup…).
- Qué **espera** del producto (health probes, requests/limits, labels, imágenes firmadas, no `cluster-admin`).
- **Versiones soportadas** (K8s N y N-1; charts internos N y N-1).
- **Deprecations** con fecha y migración.
- Canal de soporte y severidades.

Este contrato es el **entregable principal** de la actividad 01.

---

## 10. Ciclo de vida de la plataforma: versiones, deprecations, soporte

Una plataforma viva **versiona** y **deprecia**. Puntos operativos:

- **Platform version**: un tag por release del stack (p. ej. `platform-v2024.05.1`): combinación concreta de versiones de K8s, CNI, Ingress, Argo CD, Helm charts internos, policies.
- **Soporte**: típicamente N y N-1; a veces LTS a 12 meses.
- **Deprecations**: cada cambio incompatible → nota en release notes, fecha de retiro, path de migración.
- **Canary de plataforma**: el equipo plataforma rolea primero en su propio namespace/entorno (`platform-dogfood`), luego a early adopters, luego a general availability.
- **Communications**: changelog + un canal (Slack/Teams/mailing) + Backstage announcement.
- **Runbooks**: upgrade, rollback, incident response.

Analogía: trata la plataforma como tratarías a una base de datos propia que vendes internamente. Rupturas sin aviso erosionan la confianza más rápido que un outage.

---

## 11. Mapa mental: cuándo introducir cada pieza

Orden razonable (de izquierda a derecha, cada uno "después de" el anterior):

```
K8s cluster
  -> Ingress / Gateway API
  -> cert-manager (TLS)
  -> Observabilidad (Prometheus Operator, Grafana, Loki, Tempo, OTel)
  -> Policy (Kyverno) + Pod Security Admission restricted
  -> Backup (Velero)
  -> Autoscaling (HPA, Karpenter/CA)
  -> Secret management (External Secrets Operator / Vault)
  -> Empaquetado (Helm para upstream; Kustomize para in-house)
  -> GitOps (Argo CD o Flux) con ApplicationSet
  -> Cost management (OpenCost)
  -> Platform portal (Backstage) + control plane (Crossplane)   [si hay varios equipos]
  -> Service mesh                                                [solo si justificado]
```

**Mesh e IDP al final**. Son potentes y caros de operar. Introducirlos sin la base genera dolor sin beneficio claro.

---

## 12. Checklist de decisión y errores comunes

### Checklist antes de añadir una pieza a la plataforma

- [ ] ¿Qué problema **concreto y medido** resuelve?
- [ ] ¿Cuál es el coste (CPU, memoria, incidencias, aprendizaje)?
- [ ] ¿Quién la opera? ¿Hay FTE asignado?
- [ ] ¿Cómo se **desinstala** si falla la apuesta?
- [ ] ¿Afecta al contrato con los equipos de producto?
- [ ] ¿Hay runbook y SLO?
- [ ] ¿Está en el release-notes y en Backstage?

### Errores comunes

- **"Instalamos Istio porque todo el mundo tiene mesh"** — sin justificar los síntomas → coste operativo sin retorno.
- **"Helm o Kustomize, no ambos"** como dogma — en la práctica, upstream es Helm y in-house suele ser Kustomize; combinarlos es sano.
- **CI haciendo `kubectl apply`** en lugar de GitOps — las credenciales del cluster viajan a CI y el drift queda sin detectar.
- **No versionar la plataforma** — "actualizamos cuando toca" acaba en upgrades mega-grandes y dolorosos.
- **Showback que nadie mira** — números sin dueño ni foro ≠ gobernanza de coste.
- **IDP sin FTE** — un Backstage sin mantenimiento es un cementerio de plugins rotos.
- **Mesh sin budget de latencia** — P99 degrada y nadie lo midió antes.

### Decisión de módulo

Tras este módulo, al estudiante debería serle **fácil defender** respuestas como:

> "Para esta organización, el stack mínimo viable es: Ingress + cert-manager + observabilidad OSS + Kyverno + Velero + Helm (upstream) + Kustomize (in-house) + Argo CD con ApplicationSet + OpenCost en showback. **No** mesh, **no** IDP todavía. Lo revisamos cuando aparezca el segundo cluster o el séptimo equipo de producto."

Ese es el entregable intelectual del módulo. Las actividades lo materializan en un ADR y en un análisis estructurado.
