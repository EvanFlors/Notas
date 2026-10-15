# k8s-01 — Modelo mental y arquitectura

## Identificación

- **ID:** `k8s-01-mental-model-and-architecture`
- **Curso:** `kubernetes`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** curso **docker** completo (OCI, redes, volúmenes, imágenes). Nociones de YAML y de línea de comandos.

## Objetivo

Construir el **modelo mental correcto** de Kubernetes *antes* de tocar `kubectl` o levantar un cluster: por qué un orquestador en vez de `docker run`, qué significa "declarativo" cuando el estado deseado es un objeto con `spec` y `status`, qué es el **reconciliation loop**, por qué el API server es la única puerta a `etcd`, y por qué un "cluster" es realmente un **API con controllers**, no una máquina.

Al terminar este módulo deberías poder, sin consultar docs:

- Explicar la diferencia entre lanzar contenedores "a mano" con Docker y declararlos en Kubernetes.
- Nombrar los componentes del **control plane** (`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `cloud-controller-manager`) y qué hace cada uno.
- Nombrar los componentes del **nodo** (`kubelet`, `kube-proxy`, container runtime, CNI, CSI) y qué hace cada uno.
- Describir el **reconciliation loop**: un controller lee `spec`, observa `status`/realidad, y actúa para converger.
- Explicar por qué un Pod **no es** "un contenedor envuelto" sino la **unidad mínima de scheduling**.
- Comparar **self-hosted** vs **managed** (EKS/GKE/AKS) y argumentar cuándo cada uno.
- Explicar qué es **CNCF conformance** y por qué permite portabilidad real.

Este módulo es deliberadamente **"antes de instalar nada"**: todo el contenido se puede completar sin cluster. La instalación local y el primer `kubectl` se cubren en `k8s-02`.

## Alcance

Este módulo cubre:

- Por qué orquestar: límites de `docker run`, `docker compose` y de scripts imperativos sobre flotas.
- **Modelo declarativo**: todo recurso tiene `spec` (deseado) y `status` (observado).
- **Reconciliation loop** como primitiva de diseño del sistema entero.
- **Control plane** (API server, etcd, scheduler, controller-manager, cloud-controller-manager) y **data plane** (kubelet, kube-proxy, runtime, CNI, CSI).
- **Pod** como unidad mínima: por qué no se declaran "a mano" y por qué los contenedores de un Pod comparten red e IPC.
- **Modos de distribución**: self-hosted (kubeadm, kops, Cluster API) vs managed (EKS, GKE, AKS) vs "sabor ligero" (k3s, k0s, kind, k3d).
- **CNCF conformance**: qué garantiza y qué no.

Lo que **no** cubre (vendrá después):

- Instalar `kubectl`, kind/k3d, levantar un cluster → `k8s-02`.
- Pods, Deployments, ReplicaSets como manifests reales → `k8s-03`.
- Internals ejecutables del control plane (etcdctl, scheduling framework, admission webhooks) → `k8s-11`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (≈ 2 h de lectura reflexiva).
- **`examples/`** — ejemplos conceptuales (no requieren cluster):
  - `01-draw-control-plane/` — diagramas ASCII anotados del control plane y del data plane, con la explicación de cada componente.
  - `02-spec-vs-status-walkthrough/` — recorrido comentado por un par `spec/status` de un Deployment real capturado.
- **`activities/`** — dos actividades **independientes y conceptuales**:
  - `01-when-is-k8s-overkill/` — **independent, análisis**. Produce `ADR.md` argumentando *cuándo K8s no es la respuesta*.
  - `02-architecture-diagram/` — **independent, arquitectura**. Produce `MAP.md` con el diagrama anotado del control plane + data plane y responde preguntas obligatorias.
- **`resources/links.md`** — docs oficiales, KEPs, lecturas de referencia.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar: declarativo vs imperativo en K8s, `spec`/`status`, reconciliation loop, componentes del control plane y del nodo. |
| Operativa | Leer un par `spec/status` real e identificar quién lo escribió (usuario vs controller). Dibujar el camino de un `kubectl apply` desde el cliente hasta `etcd`. |
| Arquitectónica | Argumentar self-hosted vs managed; justificar cuándo K8s *no* es la respuesta (ADR); explicar qué garantiza CNCF conformance. |

## Criterios de evaluación

- Lección leída y preguntas de evaluación respondidas (`theory/lesson.md` §12).
- Actividad 01 entregada: `ADR.md` con contexto, decisión y consecuencias para un escenario "monolito pequeño".
- Actividad 02 entregada: `MAP.md` describe los 5 componentes del control plane, los componentes del nodo, el reconciliation loop y la cadena `kubectl apply → etcd`.
- `tests/validate.sh` de cada actividad pasa (estructural; semántica contra `solution/`).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Reproduce mentalmente `examples/01-draw-control-plane/` — contrasta con lo leído.
3. Recorre `examples/02-spec-vs-status-walkthrough/` — identifica cada campo y quién lo escribe.
4. Haz la actividad `02-architecture-diagram/` — valida comprensión arquitectónica.
5. Haz la actividad `01-when-is-k8s-overkill/` — practica criterio profesional (ADR).
6. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `k8s-02-setup-local-and-kubectl`: instalar `kubectl` y un cluster local (**kind** o **k3d**), configurar kubeconfig con 2+ contextos, operar `get/describe/apply/explain` con disciplina.
