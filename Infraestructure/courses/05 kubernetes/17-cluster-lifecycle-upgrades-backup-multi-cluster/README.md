# k8s-17 — Cluster lifecycle, upgrades, backup y multi-cluster

## Identificación

- **ID:** `k8s-17-cluster-lifecycle-upgrades-backup-multi-cluster`
- **Curso:** `kubernetes`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-11-control-plane-internals`, `k8s-16-security-hardening-and-supply-chain`.

## Objetivo

Operar el **ciclo de vida** del cluster y la **continuidad del negocio**: planificar y ejecutar un upgrade sin dolor, demostrar backup y restore end-to-end con **Velero**, diseñar un plan de **DR** del cluster con RPO/RTO explícitos, y entender los patrones **multi-cluster** (fleet management) y la observabilidad de **costos** cluster-side. Al terminar, deberías poder presentar a tu equipo una propuesta defendible de "cómo actualizamos el cluster X" y "qué pasa si mañana lo perdemos".

## Alcance

Este módulo cubre:

- **Versionado K8s**: política de soporte (3 minors activas + patches), cadencia de release (~3 por año) y **skew policy** entre control plane, kubelet, `kube-proxy`, `kubectl` y controllers.
- **Upgrades**:
  - **Managed** (EKS, GKE, AKS): quién actualiza qué (control plane vs node groups), release channels, planes de salto, deprecation API checker.
  - **Self-hosted con kubeadm**: `apt-mark unhold → apt install kubeadm → kubeadm upgrade plan → upgrade apply → nodos uno a uno con drain`.
  - Estrategias: **in-place** vs **blue/green cluster** (cluster nuevo, migrar workloads, cortar DNS).
- **Node drain**: `kubectl drain` con `--ignore-daemonsets --delete-emptydir-data`, interacción con **PDB** (`minAvailable`/`maxUnavailable`), tolerancia a disrupción voluntaria vs involuntaria.
- **Velero**: arquitectura (controller + CRDs + object store + volume snapshotter), backup/restore de **recursos** + **volúmenes** vía CSI snapshots o `node-agent` (restic/kopia), schedules, backup location y hooks.
- **etcd backup**: `etcdctl snapshot save/restore`, consideraciones en kubeadm vs managed (etcd en EKS/GKE es "no tocar").
- **DR del cluster**: diseño con **RPO** (cuánto dato puedo perder) y **RTO** (cuánto tardo en volver), snapshots cross-region, playbook "no tengo cluster, lo necesito en 1 hora".
- **Multi-cluster y fleet management**: patrones y herramientas — **Rancher Fleet**, **Argo CD app-of-apps / ApplicationSet** sobre varios clusters, **Cluster API** (CAPI) para declarar clusters como CRs; **workload portability** (los manifests no deben asumir el cluster); introducción a **service discovery cross-cluster** (ExternalName, Submariner, Istio multi-primary — el mesh se cubre aparte en `k8s-18`).
- **FinOps cluster-side**: **OpenCost** (CNCF, OSS) y **Kubecost** (producto comercial sobre OpenCost); asignación de costo por namespace / label / workload; alertas de waste; integración con billing del cloud.
- **Mantenimiento sin dolor**: ventanas de mantenimiento, canarios de upgrade, test de upgrade en staging primero.

Lo que **no** cubre (viene en otros módulos):

- Service mesh completo — `k8s-18`.
- Secretos externos / rotación — `k8s-05` y `k8s-12`.
- Autoscaling de nodos (Karpenter / Cluster Autoscaler) — `k8s-13`.
- Backup de aplicaciones **a nivel de datos** fuera de Velero (p. ej. `pg_dump` por operador) — curso de la base de datos correspondiente.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones. Lee antes de los ejemplos.
- **`examples/`**:
  - `01-velero-backup-restore/` — install Velero en **kind** con **MinIO** local como object storage; backup de un namespace con datos; borrado del namespace; restore; verificación. 100% reproducible en portátil, cero cloud.
  - `02-eks-upgrade-walkthrough/` — walkthrough paso a paso de un upgrade de EKS (1.30 → 1.31) *sin* AWS real: comandos `aws eks` y manifests comentados, deprecation API check con `pluto`, orden correcto de upgrade (control plane → data plane → add-ons). Se lee y se razona; no se ejecuta en vivo.
  - `03-opencost-dashboard/` — walkthrough de instalación de **OpenCost** (chart Helm) y de **Kubecost** (free tier) sobre un cluster kind. Explica cómo se asigna costo por namespace y cómo se integra con el billing del cloud en producción.
- **`activities/`**:
  - `01-backup-and-restore-cluster/` — **guided-lab**. Instalar MinIO como backend de Velero en un cluster kind, instalar Velero, crear un namespace con workload y datos, hacer backup, borrar el namespace, restaurar, verificar. Validador scripted.
  - `02-upgrade-managed-cluster-adr/` — **independent** (`architecture`). Escribir un ADR eligiendo entre **in-place** y **blue/green cluster** para un perfil organizacional dado (SLO, criticidad, equipo, costo). Validador comprueba estructura del ADR.
- **`resources/links.md`** — docs oficiales de Velero, kubeadm upgrade, EKS/GKE upgrade, Cluster API, OpenCost/Kubecost, políticas de soporte.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la **skew policy** y por qué define el orden de upgrade; distinguir "backup de etcd" de "backup con Velero" y cuándo cada uno; explicar **RPO** y **RTO** y traducirlos a decisiones de arquitectura; distinguir **in-place** de **blue/green cluster** con sus trade-offs; explicar qué resuelve y qué *no* resuelve una fleet. |
| Operativa | Instalar Velero + MinIO y demostrar backup/restore de un namespace con PVCs; drenar un nodo respetando PDBs; detectar APIs deprecadas antes de un upgrade (`pluto`, `kubent`); escribir un ADR de upgrade; leer un dashboard de OpenCost y proponer un recorte. |
| Arquitectónica | Diseñar un **plan DR** del cluster del capstone con RPO/RTO explícitos y justificables; decidir in-place vs blue/green para un contexto dado; elegir patrón multi-cluster (ninguno / app-of-apps / Fleet / CAPI) por tamaño y madurez; defender cuándo *no* adoptar aún multi-cluster. |

## Criterios de evaluación

- Backup y restore de un namespace **completo** (incluyendo PVC) demostrado en el laboratorio con Velero + MinIO.
- ADR de upgrade (Actividad 02) con secciones estructurales presentes (contexto, decisión, consecuencias, alternativas descartadas, RPO/RTO si aplica).
- Plan DR del cluster del capstone con RPO y RTO numéricos, procedimiento paso a paso para "cluster perdido", y lista de dependencias externas (DNS, secretos, imágenes de registry, PVs huérfanos).
- Diagnóstico de un upgrade bloqueado por API deprecada (ejercicio al final de §12).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (≈1 h 45 min).
2. Reproduce `examples/01-velero-backup-restore/` entero. Es la base de la actividad 01.
3. Lee `examples/02-eks-upgrade-walkthrough/`. No se ejecuta: se razona y se contrasta con lo que harías con `kubeadm`.
4. Lee `examples/03-opencost-dashboard/`. Opcional ejecutar OpenCost en kind si tu máquina da.
5. Haz la **Actividad 01**. Ejecuta el validador. Si falla, no toques los manifests sin leer el mensaje.
6. Haz la **Actividad 02** (ADR). Ejecuta el validador de estructura.
7. Vuelve a §12 de la lección y responde las preguntas de evaluación por escrito.

## Siguiente

→ `k8s-18-platform-patterns-bridges-helm-gitops-mesh`: K8s como plataforma, bridges a Helm, Argo CD, OpenCost y service mesh (último módulo del curso).

## Notas sobre entorno

- Requiere **kind**, **kubectl**, **helm**, binario **velero** y **MinIO** (como contenedor en el cluster para la actividad 01). Opcional: `pluto`, `kubent`, `opencost`.
- Todo lo "live" ocurre en kind + /tmp. El walkthrough de EKS es solo lectura — no se ejecuta contra una cuenta real para no incurrir en costo ni requerir credenciales.
- No se usan secretos reales. MinIO corre con credenciales de desarrollo documentadas (`minioadmin:minioadmin`); **nunca** usar esas credenciales fuera de un lab local.
- Limpieza: `kind delete cluster --name k8s-17-lab` deja la máquina como estaba. Scripts `cleanup.sh` incluidos en examples y activities.
