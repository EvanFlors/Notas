# argo-08 — Multi-cluster y patrones de bootstrap

## Identificación
- **ID:** `argo-08-multi-cluster-and-bootstrap-patterns`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `argo-02` (install + first app), `argo-07` (ApplicationSets + generators)

## Objetivo
Operar Argo CD contra **múltiples clusters** y **bootstrappear un cluster vacío** a su estado objetivo con un único `kubectl apply`, incluyendo add-ons y el propio Argo CD autogestionado — razonando sobre los riesgos chicken-and-egg del *self-managing*.

## Temas y subtemas
1. **Topologías multi-cluster**
   - *In-cluster*: una instalación de Argo CD por cluster, cada una se gestiona a sí misma.
   - *Control-plane cluster*: una sola instalación "hub" que gestiona N clusters remotos.
   - Trade-offs: blast radius, latencia, disponibilidad, RBAC, costo operativo.
2. **Registro de clusters remotos**
   - Imperativo: `argocd cluster add <kube-context>`.
   - Declarativo: Secret con label `argocd.argoproj.io/secret-type: cluster`.
   - Autenticación: bearer token de ServiceAccount, AWS EKS IAM, GKE workload identity.
   - Discovery automático con **Cluster API** o integraciones (Rancher, Capsule, Akuity).
3. **Bootstrap repo**
   - Estructura canónica (`bootstrap/`, `addons/`, `apps/`, `clusters/`).
   - *Root app* o *root ApplicationSet* que apunta al propio repo y despliega todo lo demás.
   - Patrón **app-of-apps** clásico vs **ApplicationSet con Git generator**.
4. **Add-ons del cluster**
   - ingress-nginx, cert-manager, external-dns, metrics-server, Prometheus Operator.
   - Orden mediante `sync-wave`; cert-manager antes de cualquier Issuer; CRDs antes que CRs.
5. **Argo CD self-managing**
   - Application que apunta al chart/manifests del propio Argo CD.
   - Chicken-and-egg: la primera instalación es imperativa; de ahí en adelante es GitOps.
   - Riesgos: cambio malo al chart = perder al controller que debía aplicarlo.
   - Mitigaciones: `selfHeal: false` en el root, canary cluster, backup Velero.
6. **Progressive sync y promoción de add-ons**
   - ApplicationSet con `strategy.rollingSync` para desplegar add-ons primero en dev, luego stg, luego prod.
7. **Operación diaria**
   - Añadir un cluster = 1 PR; remover = 1 PR; mismo contrato para dev/stg/prod/edge.

## Conceptos internos (fundamentos)
- El **cluster "in-cluster"** siempre existe en toda instalación (`https://kubernetes.default.svc`); registrar otros simplemente añade más entradas Secret.
- El `application-controller` tiene **un informer por cluster target**; muchos clusters = más memoria/CPU. Se mitiga con `sharding` (replicas del controller) y label-based cluster selection.
- `kubectl apply -f bootstrap/root.yaml` crea *una* Application que, al reconciliar, crea *N* Applications/ApplicationSets — el "efecto dominó" que define el patrón.
- Un cluster target autentica a Argo CD con un **ServiceAccount** en ese cluster (típicamente `argocd-manager` con un ClusterRoleBinding `cluster-admin`). Rotar ese token = rotar una credencial de "dios".

## Competencias
- **Conceptual:** diferenciar in-cluster vs control-plane; explicar app-of-apps vs root ApplicationSet; enumerar riesgos del self-managing.
- **Operativa:** registrar un cluster declarativamente; escribir un bootstrap repo mínimo; recuperar un cluster desde `apply` del root.
- **Arquitectónica:** diseñar la topología multi-cluster de una org (nº de clusters, geografía, blast radius) y defenderla.

## Ejemplos
- [`examples/01-register-second-cluster/`](examples/01-register-second-cluster/) — crear un segundo cluster kind, registrarlo en el hub Argo CD (Secret declarativo + CLI).
- [`examples/02-bootstrap-repo-skeleton/`](examples/02-bootstrap-repo-skeleton/) — layout de referencia de un bootstrap repo (`bootstrap/`, `addons/`, `apps/`, `clusters/`) con un root ApplicationSet.
- [`examples/03-argocd-self-managing/`](examples/03-argocd-self-managing/) — Application que gestiona la propia instalación de Argo CD, con las guard-rails recomendadas.

## Actividades
- [`activities/01-single-vs-control-plane-adr/`](activities/01-single-vs-control-plane-adr/) *(independent — architecture)* — ADR eligiendo topología para 3 orgs ficticias.
- [`activities/02-bootstrap-everything-from-git/`](activities/02-bootstrap-everything-from-git/) *(guided-lab)* — un cluster vacío converge a estado objetivo con un único `apply`.

## Entregables
- Cluster target registrado declarativamente (Secret versionado en Git — token redactado).
- Bootstrap repo mínimo (`root` + 1 add-on + 1 app) desplegado end-to-end.
- ADR comparando in-cluster vs control-plane para 3 escenarios.

## Criterios de evaluación
- **Conceptual:** nombra 3 riesgos del self-managing y una mitigación por cada uno.
- **Operativa:** desde cluster vacío → estado objetivo con un solo `kubectl apply`; validación automatizada verde.
- **Arquitectónica:** ADR consistente con los trade-offs enumerados en la teoría; se discute blast radius y recuperación ante pérdida del hub.

## Recursos
Ver [`resources/links.md`](resources/links.md).
