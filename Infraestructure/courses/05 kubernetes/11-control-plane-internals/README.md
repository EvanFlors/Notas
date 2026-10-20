# k8s-11 — Control plane internals

## Identificación

- **ID:** `k8s-11-control-plane-internals`
- **Curso:** `kubernetes`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-01-mental-model-and-architecture`, `k8s-02-setup-local-and-kubectl`.

> Este módulo abre la caja negra. Hasta ahora `kubectl apply -f pod.yaml` "funcionaba y ya". Aquí seguimos la request desde el cliente, pasando por `kube-apiserver`, admission, validación, almacenamiento en `etcd`, lectura por `kube-scheduler`, llegada al `kubelet`, y aparición del contenedor en el nodo. Si entiendes esa cadena, puedes depurar casi cualquier fallo del cluster: sabrás *dónde mirar*.

## Objetivo

Mirar el control plane por dentro para depurar y razonar sobre fallos. Al terminar deberías poder trazar un `kubectl apply` end-to-end sin consultar docs y saber qué log abrir ante un síntoma dado (`Pending`, `CrashLoopBackOff`, admission rechazada, etcd lento, etc.).

## Alcance

Este módulo cubre:

- **kube-apiserver**: autenticación → autorización (RBAC) → mutating admission → validating admission → persistencia en etcd. El API server es la **única** puerta a etcd.
- **etcd**: KV store distribuido con **Raft**, snapshotting, compactación, impacto de latencia en el control plane.
- **kube-scheduler**: filtros (predicates) + scoring (priorities) + extenders + **scheduling framework** (plugins).
- **kube-controller-manager** y **cloud-controller-manager**: colección de controllers con **leader election**.
- **kubelet**: pod lifecycle, cAdvisor para métricas, image GC, interfaz **CRI**.
- **kube-proxy**: modos **iptables / IPVS / eBPF**.
- Interfaces estandarizadas: **CRI**, **CNI**, **CSI**.
- Observabilidad del control plane: `kubectl events`, auditoría (`audit.k8s.io/v1`), `kubectl -v=9` para ver HTTP crudo.

Lo que **no** cubre (va en módulos posteriores):

- RBAC y admission webhooks propios → `k8s-12`.
- Operadores y CRDs → `k8s-14`.
- Backup/restore de producción con Velero → `k8s-17`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-apiserver-request-tracing/` — `kubectl -v=9` para ver cada llamada HTTP contra el apiserver.
  - `02-etcdctl-snapshot-restore/` — snapshot y restore de etcd en `kind` (restore solo documentado).
  - `03-scheduler-plugin-skeleton/` — recorrido conceptual por el **scheduling framework** (filter, score, bind).
- **`activities/`**:
  - `01-why-is-pod-pending/` — debug independiente: un Pod se queda `Pending`. Diagnostica y escribe el `ANALYSIS.md`.
  - `02-etcd-backup-and-restore/` — guiada: snapshot de etcd via `kubectl exec` en el Pod estático del control plane.
- **`resources/links.md`** — docs oficiales de componentes del control plane.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Trazar un `kubectl apply` desde el cliente hasta `etcd` (authn → authz → mutating → validating → storage → watchers → scheduler → kubelet → CRI). Explicar qué hace Raft y por qué etcd es sensible a latencia de disco. |
| Operativa | Depurar un Pod `Pending` leyendo `kubectl describe pod` + `kubectl events` + logs del scheduler. Tomar un snapshot de etcd en un cluster local. Leer el audit log para reconstruir "quién tocó qué". |
| Arquitectónica | Justificar por qué el apiserver es la *única* puerta a etcd (consistencia, admission, RBAC, versionado). Elegir modo de `kube-proxy` (iptables vs IPVS vs eBPF) por carga esperada. |

## Criterios de evaluación

- Puedes **explicar la cadena completa** de `kubectl apply -f pod.yaml` sin consultar docs: desde la carga del kubeconfig hasta la aparición del contenedor en el nodo, nombrando componente, interfaz y archivo donde se registra cada paso.
- Puedes **diagnosticar un Pod `Pending`** sin tocar el YAML original: usas `kubectl describe` + eventos del scheduler + logs del control plane para encontrar la causa raíz.
- Puedes **tomar un snapshot de etcd** en `kind` vía `kubectl exec etcd-<node> -n kube-system -- etcdctl snapshot save ...`, verificar el archivo (tamaño > 0, estructura con `etcdctl snapshot status`) y listar las keys top-level.
- Explicas por qué el restore completo en `kind` requiere reconstruir el nodo del control plane (no es un `restore` idempotente como en un cluster self-hosted de verdad).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-apiserver-request-tracing/` sobre un cluster `kind`. Observa la secuencia GET → POST → WATCH.
3. Reproduce `examples/02-etcdctl-snapshot-restore/` para familiarizarte con `etcdctl` dentro del Pod estático.
4. Lee `examples/03-scheduler-plugin-skeleton/` — es un recorrido conceptual, no ejecutable.
5. Haz la actividad `activities/01-why-is-pod-pending/` **sin leer la solución** (es independiente).
6. Haz `activities/02-etcd-backup-and-restore/` (guiada, con validator).
7. Responde las preguntas de evaluación del final de la lección sin consultar.

## Entregables

- Writeup (`ANALYSIS.md`) del Pod `Pending` diagnosticado con la cadena de causa raíz.
- Snapshot de etcd en `/tmp/etcd-backup/snapshot.db` con su `snapshot status` y lista parcial de keys.
- Respuestas escritas a las 10 preguntas de evaluación de la lección.

## Siguiente

→ `k8s-12-rbac-serviceaccounts-admission-policy`: una vez que entiendes la cadena de la request, puedes insertarte en ella con RBAC, webhooks de admission y `ValidatingAdmissionPolicy` (CEL).
