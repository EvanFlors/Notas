# k8s-18 — Platform Patterns: Puentes Helm, GitOps, Service Mesh, OpenCost

> Módulo **bridge** del curso Kubernetes. No duplica los cursos dedicados de **Helm**, **Argo CD/GitOps** ni los módulos de observabilidad: enlaza y deja claro **cuándo y cómo** se enganchan al cluster.

## Identificación

- **ID:** `k8s-18-platform-patterns-bridges-helm-gitops-mesh`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `k8s-14` (operators/CRDs), `k8s-16` (security hardening), `k8s-17` (lifecycle + backup)

## Objetivo

Operar un cluster Kubernetes **como plataforma**: entender qué piezas se montan encima del API (Helm, Kustomize, Argo CD/Flux, service mesh, OpenCost, Backstage/Crossplane) y, sobre todo, decidir **cuáles no**. El módulo cierra la pirámide del curso con una decisión arquitectónica, no con otro tutorial de instalación.

## Temas y subtemas

- **Templating y empaquetado de manifests**
  - Helm: charts, `values`, releases, dependencies, OCI registries para charts.
  - Kustomize: overlays declarativos sin templating.
  - Cuándo uno, cuándo el otro, cuándo los dos a la vez.
- **GitOps**
  - Argo CD vs Flux (modelo pull, reconciliación continua, drift detection).
  - `Application` y `ApplicationSet` para N entornos.
  - Patrón **app-of-apps** y **repo-of-repos**.
- **Service mesh**
  - Istio, Linkerd, Cilium Service Mesh.
  - mTLS automático, L7 observability, traffic shaping (canary, mirror).
  - Overhead real (CPU, memoria, latencia, operabilidad).
  - Criterios para **no** introducirlo.
- **Internal Developer Platform (IDP) y "golden paths"**
  - Backstage (portal), Crossplane (control plane de infra como CRDs), Argo (entrega), templates.
  - Contratos entre plataforma y producto.
- **Cost management**
  - OpenCost / Kubecost: cómo se calcula el coste de un namespace o workload.
  - Showback vs chargeback.
- **Platform SLOs y ciclo de platform engineering**
  - Versiones, deprecations, release notes, "support window" de la plataforma.

## Conceptos internos (fundamentos)

- Un **service mesh añade sidecars** (uno por Pod) o eBPF-ambient: cuesta CPU/memoria, suma una capa que debe operarse, y multiplica superficies de fallo. Vale la pena cuando se **necesita de verdad** mTLS automático *between workloads*, L7 observability uniforme, o traffic shaping fino que Ingress/Gateway API no cubren.
- **Helm** combina dos cosas en una: *templating* (Go templates sobre YAML) + *release lifecycle* (install/upgrade/rollback/history en Secrets/ConfigMaps).
- **Kustomize** es puro overlay: base + patches declarativos, sin lenguaje de plantillas, integrado en `kubectl apply -k`.
- **Argo CD** reconcilia Git → cluster: lee el repo (fuente de verdad), compara con el estado real del cluster y aplica (o alerta sobre) la diferencia. Es un *controller* más corriendo en el cluster.
- **ApplicationSet** genera N `Application` desde un *generator* (list, cluster, git, matrix), ideal para "la misma app en 20 clusters" sin duplicar YAML.
- **OpenCost** combina métricas de uso (CPU, memoria, GPU, PV, red) con precios de la cloud (o custom) para producir coste por `namespace`, `deployment`, `label`, `pod`.

## Competencias

- **Conceptual:** explicar en 1 minuto qué resuelve cada pieza y qué cuesta.
- **Operativa:** instalar Helm/Argo CD/OpenCost mínimos en un cluster local y entender el loop GitOps.
- **Arquitectónica:** elegir el **nivel de plataforma** adecuado a la organización. Defender **no** introducir service mesh. Documentar el **contrato plataforma ↔ producto** en un ADR.

## Ejemplos

- `examples/01-helm-release-walkthrough/` — install mínimo de un chart (`ingress-nginx`), inspección del Release, puente al curso **helm**.
- `examples/02-argo-app-of-apps-overview/` — Argo CD en kind, un `Application` apuntando a un repo público, puente al curso **argocd-gitops**.
- `examples/03-opencost-dashboard/` — OpenCost en cluster local, tour del dashboard.

## Actividades

- `activities/01-platform-contract-adr/` — **independiente**, formato ADR. Decidir Helm vs Kustomize, Argo CD vs Flux, mesh sí/no, cost management, para un escenario dado.
- `activities/02-when-not-mesh/` — **independiente**, análisis estructurado. El estudiante lista los criterios que deben cumplirse **antes** de introducir un mesh y cómo responderlos con evidencia.

## Entregables

- ADR firmado del contrato de plataforma mínimo viable (`activities/01`).
- Análisis "when NOT mesh" (`activities/02`).
- Opcionalmente: cluster local con Argo CD + un `Application` desplegando una app simple.

## Criterios de evaluación

| Dimensión | Qué se espera |
|-----------|---------------|
| Conceptual | Explicar diferencia Helm/Kustomize y Argo CD/Flux sin consultar. |
| Operativa | Levantar Helm + Argo CD + OpenCost en kind siguiendo los ejemplos. |
| Arquitectónica | ADR con decisiones **explícitas** y defendibles, incluyendo *no mesh* por default. |

## Recursos

Ver `resources/links.md`.

## Lección

Ver `theory/lesson.md` (12 secciones).
