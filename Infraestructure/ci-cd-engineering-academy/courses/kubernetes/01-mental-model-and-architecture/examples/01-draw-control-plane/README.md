# Ejemplo 01 — Diagramas anotados del control plane y del data plane

## Concepto que demuestra

Qué componentes forman un cluster Kubernetes, dónde vive cada uno, con quién habla, y por qué el **API server** es el embudo por donde pasa todo. Es un ejemplo **conceptual**: no requiere cluster ni `kubectl`.

## Contexto

En `theory/lesson.md` §4 ya se describieron los componentes. Aquí los **ves dibujados** y comentados pieza a pieza. Si cuando termines este ejemplo todavía no puedes reproducir los diagramas de memoria, re-lee la lección antes de hacer la actividad 02.

## Objetivo

Al terminar, podrás:

- Nombrar los **5 componentes** del control plane (`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `cloud-controller-manager`) y qué hace cada uno.
- Nombrar los componentes del **nodo** (`kubelet`, `kube-proxy`, container runtime, CNI, CSI).
- Explicar por qué el API server es la única puerta a `etcd`.
- Explicar por qué el `kubelet` solo habla con el API server (y no con `etcd` directamente).
- Dibujar la cadena **Deployment → ReplicaSet → Pods** como un ejemplo del reconciliation loop.

## Prerrequisitos

- Haber leído §4 de `theory/lesson.md`.

## Diagrama 1 — Control plane

```
┌───────────────────────────────────────────────────────────────┐
│                       CONTROL PLANE                           │
│                                                               │
│   ┌─────────────────────────┐                                 │
│   │   kube-apiserver        │                                 │
│   │   -----------------     │        REST sobre HTTPS         │
│   │   Única puerta a etcd.  │◄─── kubectl / Argo / cualquier  │
│   │   Hace:                 │     cliente autenticado         │
│   │     authn (certs/OIDC)  │                                 │
│   │     authz (RBAC)        │                                 │
│   │     admission:          │                                 │
│   │       mutating          │                                 │
│   │       validating        │                                 │
│   │     validación schema   │                                 │
│   │     persistencia        │                                 │
│   │                         │                                 │
│   │   Expone WATCH para     │                                 │
│   │   que controllers       │                                 │
│   │   reaccionen a cambios. │                                 │
│   └────────┬────────────────┘                                 │
│            │ gRPC                                             │
│            ▼                                                  │
│   ┌─────────────────────────┐                                 │
│   │   etcd                  │  cluster de 3 o 5 nodos (Raft)  │
│   │   -----------------     │  quorum impar; snapshots        │
│   │   KV store consistente. │  periódicos; TLS mutuo entre    │
│   │   Guarda TODO el estado │  réplicas; nadie más lee aquí.  │
│   │   del cluster.          │                                 │
│   └─────────────────────────┘                                 │
│                                                               │
│   ┌─────────────────────────┐                                 │
│   │   kube-scheduler        │                                 │
│   │   -----------------     │  WATCH: Pods sin spec.nodeName  │
│   │   1) filtra nodos       │  Al elegir uno, hace PATCH:     │
│   │   2) puntúa los que     │     spec.nodeName = <nodo>      │
│   │      quedan             │  NO arranca contenedores.       │
│   │   3) elige el mejor     │                                 │
│   └─────────────────────────┘                                 │
│                                                               │
│   ┌─────────────────────────┐                                 │
│   │ kube-controller-manager │                                 │
│   │   -----------------     │  Un binario con MUCHAS gorutinas│
│   │   Deployment ctrl       │  (controllers). Cada controller │
│   │   ReplicaSet ctrl       │  hace su propio reconciliation  │
│   │   StatefulSet ctrl      │  loop sobre su tipo de recurso. │
│   │   DaemonSet ctrl        │                                 │
│   │   Job / CronJob ctrl    │                                 │
│   │   Node ctrl             │                                 │
│   │   Endpoints / EndpointS │                                 │
│   │   ServiceAccount ctrl   │                                 │
│   │   PV / PVC ctrl         │                                 │
│   │   Namespace ctrl        │                                 │
│   │   GC ctrl               │                                 │
│   │   ...                   │                                 │
│   └─────────────────────────┘                                 │
│                                                               │
│   ┌─────────────────────────┐                                 │
│   │ cloud-controller-mgr    │                                 │
│   │   -----------------     │  Específico del cloud:          │
│   │   Node ctrl (del cloud) │    - crea LBs para              │
│   │   Service ctrl (LB)     │      Service type=LoadBalancer  │
│   │   Route ctrl            │    - marca Nodes NotReady       │
│   │                         │      si la VM fue terminada     │
│   │                         │    - integra con APIs AWS/GCP   │
│   └─────────────────────────┘                                 │
└───────────────────────────────────────────────────────────────┘
```

Lo clave:

- **`kube-apiserver` es el embudo**. Nada más escribe en `etcd`. Esto da **un único punto** donde aplicar autenticación, autorización, admission y auditoría.
- **Los controllers se comunican entre sí vía el API server**, no directamente. El API server es la "pizarra compartida".
- **`etcd` no sabe de Kubernetes**. Para él son solo bytes bajo claves. Toda la semántica (que un Deployment maneje ReplicaSets, que un Pod tenga containers, etc.) vive en el API server y en los controllers.
- **El scheduler no ejecuta**. Decide. Quien ejecuta es el kubelet del nodo elegido.

## Diagrama 2 — Data plane (un nodo)

```
┌──────────────────────────────────────────────────────────────┐
│                           NODO                               │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │  kubelet                                            │    │
│   │  -----------------                                  │    │
│   │  WATCH al API server:                               │    │
│   │    /api/v1/pods?fieldSelector=spec.nodeName=<yo>    │    │
│   │  Para cada Pod asignado:                            │    │
│   │    - habla con el runtime (CRI gRPC)                │    │
│   │    - pide crear pod sandbox (netns, cgroup)         │    │
│   │    - CNI configura red del Pod (IP, veth-pair)      │    │
│   │    - CSI monta volúmenes                            │    │
│   │    - arranca containers                             │    │
│   │    - ejecuta probes (startup/liveness/readiness)    │    │
│   │    - actualiza status.* vía API server              │    │
│   │  Hace heartbeat del Node periódico.                 │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │  kube-proxy                                         │    │
│   │  -----------------                                  │    │
│   │  WATCH: Services + EndpointSlices.                  │    │
│   │  Programa reglas de kernel:                         │    │
│   │    - iptables (default clásico)                     │    │
│   │    - IPVS (mejor a gran escala)                     │    │
│   │    - eBPF (vía Cilium; puede reemplazarlo)          │    │
│   │  Materializa Services: VIP + load-balance → Pods.   │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │  container runtime (containerd / CRI-O)             │    │
│   │  -----------------                                  │    │
│   │  Habla CRI con el kubelet (gRPC).                   │    │
│   │  Pulls imágenes OCI del registry.                   │    │
│   │  Delega la ejecución al runtime de bajo nivel:      │    │
│   │    runc / crun (OCI runtime-spec).                  │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │  CNI plugin (Calico / Cilium / Flannel / AWS VPC)   │    │
│   │  -----------------                                  │    │
│   │  Configura la red del Pod:                          │    │
│   │    - asigna IP (del rango del pod CIDR)             │    │
│   │    - crea veth-pair                                 │    │
│   │    - inyecta rutas                                  │    │
│   │  Modelo: todo Pod puede alcanzar a todo Pod sin NAT │    │
│   │  dentro del cluster.                                │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │  CSI driver (EBS / PD / local-path / Longhorn)      │    │
│   │  -----------------                                  │    │
│   │  Provisiona y montea volúmenes de PVCs.             │    │
│   │  Habla CSI (gRPC) con el kubelet.                   │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Lo clave:

- **El `kubelet` habla SOLO con el API server**. Nunca con `etcd`. Esto hace al nodo trivialmente reemplazable: si cambias su kubeconfig, "ya es otro cluster".
- **`kube-proxy` no es imprescindible** si tu CNI (p. ej. Cilium) lo reemplaza. Es un componente separable.
- **El runtime es intercambiable** por diseño (CRI). Esto permitió migrar de `dockershim` → `containerd`/`CRI-O` sin tocar imágenes ni manifests.
- **CNI y CSI son plugins**: eliges uno. "No viene incluido".

## Diagrama 3 — Reconciliation loop: Deployment → ReplicaSet → Pods

El ejemplo canónico de cadena de controllers:

```
┌──────────────────────────────────────────────────────────────┐
│  Deployment "web"                        kind: Deployment    │
│    spec.replicas: 3                                          │
│    spec.template: <pod template nginx:1.27>                  │
│    status.replicas: 3                                        │
│    status.availableReplicas: 3                               │
└──────────────────────────────────────────────────────────────┘
          │ gestionado por Deployment controller
          │
          │ crea / actualiza
          ▼
┌──────────────────────────────────────────────────────────────┐
│  ReplicaSet "web-6c7f...."              kind: ReplicaSet     │
│    spec.replicas: 3                                          │
│    spec.selector: app=web, pod-template-hash=6c7f....        │
│    status.replicas: 3                                        │
└──────────────────────────────────────────────────────────────┘
          │ gestionado por ReplicaSet controller
          │
          │ crea / borra para mantener N
          ▼
┌──────────────────────────────────────────────────────────────┐
│  Pod web-6c7f....-a1b2c                 kind: Pod            │
│  Pod web-6c7f....-d3e4f                                      │
│  Pod web-6c7f....-g5h6i                                      │
│    spec.containers: [{image: nginx:1.27, ...}]               │
│    spec.nodeName: <escrito por kube-scheduler>               │
│    status.phase: Running                                     │
│    status.podIP: 10.244.X.Y                                  │
│    status.containerStatuses: [{ready: true, ...}]            │
└──────────────────────────────────────────────────────────────┘
          │ gestionado por kubelet del nodo
          │
          ▼
     container runtime del nodo arranca los contenedores
```

Qué pasa si **borras un Pod**:

1. El API server marca el Pod `Terminating` y lo elimina de `etcd` tras el grace period.
2. El **ReplicaSet controller** observa que tiene 2 Pods matching su selector, pero su `spec.replicas` dice 3.
3. Crea **un Pod nuevo** (otro hash de nombre).
4. El **scheduler** lo asigna a algún nodo.
5. El **kubelet** del nodo lo arranca.
6. Todo esto sin que tú hagas nada. El sistema **convergió solo**.

Qué pasa si **cambias `spec.template.image`** del Deployment a `nginx:1.28`:

1. El **Deployment controller** crea un **ReplicaSet nuevo** (otro hash).
2. Escala el nuevo RS a 1, baja el viejo a 2 (progresivamente, según `maxSurge`/`maxUnavailable`).
3. Repite hasta que el nuevo RS tenga 3 y el viejo 0.
4. Guarda el RS viejo (para `kubectl rollout undo`).

Esto es un **rolling update sin downtime**, y lo orquesta un bucle que lees `spec` y mueve números — no hay scripts bash.

## Resultado esperado

Después de leer los tres diagramas deberías poder:

1. Dibujar los dos primeros (control plane y data plane) de memoria.
2. Explicar por qué `etcd` tiene **un solo cliente escritor** (el API server).
3. Dibujar la cadena Deployment → ReplicaSet → Pods y explicar qué controller la gestiona en cada eslabón.
4. Explicar qué pasa si borras un Pod gestionado por un Deployment.

## Interpretación

- **El sistema entero es WATCH + reconcile**. Si entiendes eso, entiendes K8s. Todo lo demás es "más controllers, más tipos de recurso".
- **El API server es un *router de intenciones***. Clientes mandan intenciones (`spec`); controllers reaccionan y escriben nuevas intenciones; el kubelet concreta en el nodo.
- **`etcd` no es "la base de datos de la app"**. Es la base de datos del *estado del cluster*. Nunca metas datos de aplicación ahí.

## Errores frecuentes

- **"El controller-manager es un solo controller"** — no, son **muchos**, empaquetados en un binario por conveniencia. Cada uno tiene su propio bucle independiente.
- **"El scheduler ejecuta los Pods"** — no, solo asigna nodo. Ejecuta el kubelet.
- **"`etcd` es opcional, es solo cache"** — no, es la **fuente de verdad** del cluster. Sin `etcd` no hay cluster.
- **"`kube-proxy` es imprescindible"** — no, con CNIs eBPF como Cilium se puede operar sin él.
- **"El cluster = las VMs"** — no, el cluster es un API con controllers; las VMs son `Node` objects.

## Relación con escenarios reales

- **Debugging**: cuando algo "no se despliega", preguntarte "¿qué controller debería estar actuando?" te lleva a los logs correctos (`kubectl logs -n kube-system <controller>`).
- **Diseño de CRDs** (nivel 3): escribir un operador propio es "añadir un nuevo controller al reconciliation loop global".
- **DR**: backup de `etcd` + manifests en Git te permite reconstruir un cluster perdido.
- **Managed**: EKS/GKE/AKS te esconden el control plane (ni ves `kube-apiserver` como proceso) pero el modelo es idéntico — lo operan ellos.

## Limpieza

Nada que limpiar — este ejemplo es conceptual.
