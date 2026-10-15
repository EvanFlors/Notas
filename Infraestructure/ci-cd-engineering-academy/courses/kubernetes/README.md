# Curso: Kubernetes

Roadmap especializado #7. Plataforma de orquestación de contenedores *de facto*. Núcleo del Nivel D8 del programa. Helm y Argo CD se tratan como cursos aparte y aquí se dejan como referencias.

## 1. Introducción

### Qué es

**Kubernetes (K8s)** es un sistema de orquestación de contenedores: dado un **estado deseado** (manifests declarativos) y un conjunto de nodos computacionales, K8s se encarga de llevar y mantener el sistema en ese estado mediante **controllers** que ejecutan un **reconciliation loop** continuo. Es, al mismo tiempo, un *scheduler*, un *control plane distribuido*, un *API* genérico extensible, y una *abstracción portable sobre infraestructura heterogénea*.

Importante separar tres cosas:
- **Kubernetes API** — superficie declarativa (recursos tipados, versionados, con `spec` y `status`).
- **Control plane** — procesos que implementan la API y la reconciliación (`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `cloud-controller-manager`).
- **Data plane** — nodos con `kubelet` y runtime de contenedores (containerd/CRI-O) que ejecutan los Pods.

### Historia (síntesis)

- Pre-2014: Google opera **Borg** y **Omega** internamente desde ~2003.
- **2014** — Google libera Kubernetes como open source basado en lecciones de Borg.
- **2015** — v1.0; nace la **CNCF** con K8s como primer proyecto.
- **2016** — Helm; StatefulSets; RBAC alfa.
- **2017** — CRDs estables; aparece el ecosistema de operadores.
- **2018** — CSI, CNI, CRI estandarizados; multi-cluster y federation iteran.
- **2020** — K8s deprecia *dockershim* y migra a interfaz **CRI** pura (containerd/CRI-O).
- **2021–2023** — Gateway API GA, Pod Security Admission reemplaza PodSecurityPolicy, SIG-Node estabiliza seccomp/AppArmor como defaults razonables, Karpenter desplaza al Cluster Autoscaler.
- **2024+** — Sidecar containers nativos (initContainers con `restartPolicy: Always`), ValidatingAdmissionPolicy (CEL en el API server), DRA (Dynamic Resource Allocation) para GPUs.

### Problemas que resuelve

- **Scheduling** eficiente de muchas cargas sobre muchos nodos.
- **Self-healing**: reemplaza Pods caídos; reasigna si un nodo muere.
- **Declaratividad** uniforme para compute, red, almacenamiento, configuración, seguridad.
- **Portabilidad** entre on-prem y cloud, y entre clouds.
- **API extensible** (CRDs + controllers) → operadores que automatizan domain-specific knowledge.
- **Base común** sobre la cual montar GitOps, service mesh, observabilidad, policy, etc.

### Casos de uso

- Microservicios y aplicaciones web/API.
- Batch y jobs (CronJobs, Jobs, Argo Workflows).
- Workloads stateful (DBs operadas con operators: cuando aporta valor).
- Plataformas internas (Internal Developer Platforms) y "golden paths".
- Multi-tenant (con limits, policies y namespaces o sub-clusters).

### Arquitectura general

```
Control Plane (uno o varios nodos "master"/managed):
┌───────────────────────────────────────────────────────┐
│ kube-apiserver                                        │
│   - única puerta a etcd                               │
│   - autenticación, autorización (RBAC), admission     │
├───────────────────────────────────────────────────────┤
│ etcd (KV store consistente, Raft)                     │
│   - fuente de verdad de todo el estado del cluster    │
├───────────────────────────────────────────────────────┤
│ kube-scheduler                                        │
│   - decide a qué nodo va cada Pod sin nodo asignado   │
├───────────────────────────────────────────────────────┤
│ kube-controller-manager                               │
│   - ejecuta controllers (Deployment, ReplicaSet, Node,│
│     Endpoints, ServiceAccount, Job, …)                │
├───────────────────────────────────────────────────────┤
│ cloud-controller-manager                              │
│   - integra con APIs del cloud (LB, nodes, volumes)   │
└───────────────────────────────────────────────────────┘
                        │
                        ▼
Nodos (data plane):
┌───────────────────────────────────────────────────────┐
│ kubelet         (habla con el apiserver; aplica specs)│
│ kube-proxy      (reglas iptables/IPVS/eBPF para Svc)  │
│ container       (containerd / CRI-O; pulls imágenes,  │
│  runtime        ejecuta contenedores)                 │
│ CNI plugin      (red: Calico / Cilium / etc.)         │
│ CSI driver      (storage: EBS, Persistent Disk, …)    │
└───────────────────────────────────────────────────────┘
```

**Idea central**: todo en Kubernetes es un objeto en el API con `spec` (deseado) y `status` (observado). Los controllers son bucles que leen `spec`, miran la realidad, y actúan para converger.

### Alternativas

- **Nomad** (HashiCorp): orquestador general más simple, sin la amplitud de K8s.
- **Docker Swarm**: en declive.
- **ECS** (AWS): managed, propietario, suficiente para muchos workloads.
- **Cloud Run / App Runner**: PaaS sobre contenedores sin K8s expuesto.
- **Serverless** puro (Lambda/Cloud Functions): otra pirámide; a menudo complementario.
- **K8s "sabor ligero"**: k3s, k0s, MicroK8s — mismo API, menor footprint, útiles para edge.

### Ventajas / limitaciones

**Ventajas**: estándar de facto, API uniforme y extensible, ecosistema (operadores, Helm, GitOps, service mesh, policy), portabilidad real, comunidad y mercado laboral grandes.

**Limitaciones / riesgos**:
- **Complejidad real**: K8s *no* es sencillo; adoptarlo "porque sí" para un monolito pequeño es anti-económico.
- **Costo total**: no son solo nodos — es ingeniería de plataforma.
- Múltiples puntos donde fallar en **seguridad** (defaults laxos históricos, RBAC mal diseñado, imágenes sin firmar).
- **StatefulSets** son potentes pero no reemplazan un DBA; operar bases de datos en K8s requiere criterio.
- Debe elegirse un **CNI**, un **ingress/gateway**, una política de **storage**, un **autoscaler**, un **mesh** o no. Nada "viene incluido".

### Relación con el programa

- Blanco de **Terraform** (provisionar cluster) y de **Docker** (imágenes OCI).
- Base de **GitOps** (Helm → Argo CD, cursos siguientes).
- Base operativa de **observabilidad** del programa (Prometheus Operator, OTel).
- Punto de aplicación de controles **DevSecOps** (admission, policy, firma de imágenes, Pod Security).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **docker** completo (OCI, redes, volúmenes, imágenes). T-2 Linux (procesos, cgroups, filesystem). T-3 Networking (TCP/IP, DNS, HTTP). Curso **git-and-github** básico. |
| Recomendados | Curso **terraform** Nivel 1–2 (para provisionar clusters). Nociones de YAML y de controllers / reconciliation. |
| Complementarios | Curso **aws** o **gcp** para los módulos de clusters managed (EKS/GKE). |

## 3. Organización (4 niveles)

El curso tiene **18 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5): modelo mental y arquitectura, setup local y `kubectl`, Pods + Deployments, Services + DNS, Config/Secret/env/volúmenes.
- **Nivel 2 — Intermedio** (5): workloads deep (Deployments, StatefulSets, DaemonSets, Jobs/CronJobs), networking (CNI, NetworkPolicy, Ingress, Gateway API), storage (PV/PVC/StorageClass/CSI), scheduling (resources, affinity, taints, PDB), lifecycle (probes, preStop, rolling updates, rollback).
- **Nivel 3 — Avanzado** (4): control plane internals, RBAC + ServiceAccounts + admission + policy (OPA/Kyverno), autoscaling (HPA/VPA/CA/Karpenter/KEDA), operadores + CRDs.
- **Nivel 4 — Producción empresarial** (4): observabilidad en K8s, seguridad (Pod Security Standards, seccomp, AppArmor, runtime security con Falco, firma de imágenes), ciclo de vida del cluster (upgrades, backup/restore con Velero, multi-cluster), platform patterns (puente a Helm, Argo CD, OpenCost, service mesh intro).

## 4. Entregables del curso

- Cluster local **kind** o **k3d** con el workload del capstone (app + Postgres).
- Mismo workload portado a un cluster **managed** (EKS o GKE) desde Terraform.
- Pipeline que despliega imagen firmada; admisión por policy (Kyverno) exige firma + no-root.
- NetworkPolicies default-deny + reglas explícitas.
- HPA + Karpenter demostrables.
- CRD propio + controller mínimo (educativo, no para producción).
- Stack de observabilidad (Prometheus Operator + Grafana) y Velero para backup.
- ADR: cuándo K8s *no* es la respuesta correcta.

## 5. Evaluación

- **Conceptual**: explicar la reconciliación; qué garantiza etcd; qué hace `kube-proxy`; cómo un Service se materializa en reglas iptables/IPVS; cómo RBAC autoriza una request paso a paso; qué diferencia a un Deployment de un StatefulSet.
- **Operativa**: depurar `CrashLoopBackOff`, `ImagePullBackOff`, `Pending`; implementar un rolling update sin downtime; recuperar un StatefulSet con PVC perdido; escribir una NetworkPolicy correcta.
- **Arquitectónica**: decidir self-hosted vs managed; CNI (Calico vs Cilium vs managed); Ingress vs Gateway API; cuándo introducir operadores; cuándo K8s es desproporcionado para el problema.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial `kubernetes.io/docs`.
- *Kubernetes Up & Running* (Burns/Beda/Hightower/Villalba).
- `kubernetes/community` repo y KEPs (Kubernetes Enhancement Proposals).
- CNCF Landscape.
- Documentación de proveedores managed (EKS, GKE, AKS).
- Pod Security Standards docs.
- Gateway API docs y conformance.
- OPA/Gatekeeper, Kyverno, Falco, Velero docs oficiales.
