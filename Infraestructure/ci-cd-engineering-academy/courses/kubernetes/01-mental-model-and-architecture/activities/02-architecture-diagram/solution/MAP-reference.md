# MAP (reference) — k8s-01: Arquitectura de Kubernetes

> Autoevaluación. **No** es una respuesta única — es *una* respuesta correcta y profesional.

## A. Control plane

```
┌────────────────────────────────────────────────────────────────┐
│                       CONTROL PLANE                            │
│                                                                │
│   ┌───────────────────────────┐                                │
│   │ kube-apiserver            │◄──── kubectl / Argo / cliente  │
│   │  authn → authz → admission│      autenticado (REST/HTTPS)  │
│   │  (mut→val) → persist      │                                │
│   └──────────┬────────────────┘                                │
│              │ gRPC                                            │
│              ▼                                                 │
│   ┌───────────────────────────┐                                │
│   │ etcd (Raft, KV)           │   fuente de verdad del cluster │
│   └───────────────────────────┘                                │
│                                                                │
│   ┌───────────────────────────┐                                │
│   │ kube-scheduler            │   asigna spec.nodeName         │
│   │  (filter + score)         │   (NO ejecuta)                 │
│   └───────────────────────────┘                                │
│                                                                │
│   ┌───────────────────────────┐                                │
│   │ kube-controller-manager   │   Deployment, ReplicaSet, Node,│
│   │  (muchos controllers)     │   Endpoints, SA, Job, CronJob, │
│   │                           │   PV, PVC, Namespace, GC, …    │
│   └───────────────────────────┘                                │
│                                                                │
│   ┌───────────────────────────┐                                │
│   │ cloud-controller-manager  │   LB, Node, Route del cloud    │
│   │                           │   (EKS/GKE/AKS integration)    │
│   └───────────────────────────┘                                │
└────────────────────────────────────────────────────────────────┘
```

- **`kube-apiserver`** — única puerta a `etcd`. Expone la API REST, hace authn/authz/admission/validación/persistencia. Expone `WATCH` para que los controllers reaccionen.
- **`etcd`** — base clave-valor consistente (algoritmo Raft, cluster de 3 o 5 nodos en producción). Guarda **todos** los objetos del cluster. Nadie más que el API server lo toca.
- **`kube-scheduler`** — mira Pods con `spec.nodeName` vacío, filtra nodos que caben y puntúa los que quedan; escribe `spec.nodeName` del elegido. **No** ejecuta contenedores.
- **`kube-controller-manager`** — un binario con muchas gorutinas, cada una un controller con su propio bucle (Deployment, ReplicaSet, Node, Endpoints, SA, Job, PV, Namespace, GC, …).
- **`cloud-controller-manager`** — controllers específicos del cloud (crear LBs para `Service type=LoadBalancer`, marcar `Node NotReady` si la instancia fue terminada, atachear EBS/PD a nodos). Se separó para que el core de K8s sea cloud-agnóstico.

**Por qué el API server es la única puerta a `etcd`:** (1) centraliza **autenticación y autorización (RBAC)** — un solo lugar donde comprobar permisos; (2) centraliza **admission** (mutating + validating) — un único punto para aplicar policies; (3) centraliza **auditoría** — un único log de todas las intenciones; (4) desacopla a los consumidores (controllers, kubelet) del formato de almacenamiento (se podría cambiar `etcd` por `kine`/SQL sin tocar nada más); (5) permite al API server servir **versiones distintas** de un mismo recurso (`v1beta1`, `v1`) convirtiendo on-the-fly, lo cual sería imposible si cada cliente leyera `etcd` directamente.

## B. Data plane (un nodo)

```
┌──────────────────────────────────────────────────────────────┐
│                           NODO                               │
│                                                              │
│   ┌─────────────────────────┐                                │
│   │ kubelet                 │◄── WATCH al API server         │
│   │  (único canal al cluster)│   (NUNCA habla con etcd)      │
│   │  arranca Pods vía CRI   │                                │
│   │  monta vols vía CSI     │                                │
│   │  configura red vía CNI  │                                │
│   │  ejecuta probes         │                                │
│   │  escribe status.*       │                                │
│   └─────────────────────────┘                                │
│                                                              │
│   ┌─────────────────────────┐                                │
│   │ kube-proxy              │  iptables / IPVS / eBPF para   │
│   │                         │  materializar Services (VIP)   │
│   └─────────────────────────┘                                │
│                                                              │
│   ┌─────────────────────────┐                                │
│   │ container runtime       │  containerd o CRI-O            │
│   │  (CRI)                  │  pulls OCI; delega a runc/crun │
│   └─────────────────────────┘                                │
│                                                              │
│   ┌─────────────────────────┐                                │
│   │ CNI plugin              │  red del Pod (IP, veth, rutas) │
│   │  (Calico / Cilium / …)  │                                │
│   └─────────────────────────┘                                │
│                                                              │
│   ┌─────────────────────────┐                                │
│   │ CSI driver              │  volúmenes (EBS/PD/local-path) │
│   │  (EBS CSI / PD CSI / …) │                                │
│   └─────────────────────────┘                                │
└──────────────────────────────────────────────────────────────┘
```

- **`kubelet`** — agente del nodo. Habla **solo con el API server** (vía TLS y bearer token / cert cliente). **No** habla con `etcd`. Mira Pods con `spec.nodeName == <este nodo>` y los materializa.
- **`kube-proxy`** — programa reglas iptables/IPVS/eBPF para que los Services (VIPs) balanceen a los Pods respaldantes. Opcional si usas CNI con eBPF que lo reemplace (Cilium).
- **container runtime** (containerd / CRI-O) — habla CRI con el kubelet; pulls imágenes OCI; delega al runtime de bajo nivel (runc, crun).
- **CNI plugin** (Calico, Cilium, Flannel, AWS VPC CNI) — asigna IP al Pod, crea veth-pair, inyecta rutas. Lo elige el admin del cluster; no viene incluido.
- **CSI driver** (EBS, GCE PD, local-path, Longhorn) — provisiona y montea volúmenes de PVCs. Habla CSI (gRPC) con el kubelet.

**El kubelet habla con el API server, nunca con `etcd` directamente** — por el mismo motivo que todos los demás: centralización de authn/authz/admission/auditoría. Si cambias el kubeconfig del kubelet, "ya es otro cluster".

## C. Reconciliation loop: Deployment → ReplicaSet → Pods

```
┌──────────────────────────────────────────────────────────────┐
│ Deployment "web"                             (kind: Deploy)  │
│   spec.replicas: 3                                           │
│   spec.template: {image: nginx:1.27, ...}                    │
│   status.observedGeneration, status.availableReplicas, …     │
└───────────────────────┬──────────────────────────────────────┘
                        │ gestionado por: Deployment controller
                        │   (en kube-controller-manager)
                        │ crea / actualiza
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ ReplicaSet "web-6c7f...."                    (kind: RS)      │
│   spec.replicas: 3                                           │
│   spec.selector: app=web, pod-template-hash=6c7f....         │
└───────────────────────┬──────────────────────────────────────┘
                        │ gestionado por: ReplicaSet controller
                        │   (en kube-controller-manager)
                        │ crea / borra Pods para mantener N
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ Pod web-6c7f....-a1b2c                        (kind: Pod)    │
│ Pod web-6c7f....-d3e4f                                       │
│ Pod web-6c7f....-g5h6i                                       │
│   spec.containers: [{image: nginx:1.27}]                     │
│   spec.nodeName: <escrito por kube-scheduler>                │
│   status.phase: Running                                      │
└───────────────────────┬──────────────────────────────────────┘
                        │ gestionado por: kubelet del nodo
                        │   (ejecuta vía CRI)
                        ▼
             contenedor nginx corriendo en el nodo
```

**Qué pasa si borras un Pod directamente** (`kubectl delete pod web-6c7f....-a1b2c`):

1. El API server lo marca `Terminating` y, tras el grace period, lo elimina de `etcd`.
2. El **ReplicaSet controller** (vía su WATCH) observa que ahora tiene 2 Pods matching su selector, pero su `spec.replicas` dice 3.
3. Escribe un **Pod nuevo** vía el API server (otro hash en el nombre).
4. El **scheduler** le pone `spec.nodeName`.
5. El **kubelet** del nodo lo arranca.
6. El sistema **convergió solo**: vuelves a tener 3 Pods, sin intervención humana.

**Reconciliation loop (mi definición):** un controller abre un `WATCH` sobre su tipo de recurso en el API server; cada vez que recibe un evento (ADDED / MODIFIED / DELETED), compara `spec` con la realidad observada (`status` o estado externo), calcula qué debería existir y lo materializa escribiendo nuevos objetos vía el API server. Si falla, reintenta. Si algo se desalinea (borras un Pod, un nodo muere), vuelve a actuar hasta converger. **Idempotencia por diseño**: no "haz esto", sino "quiero esto; alguien convergerá".

## D. `kubectl apply` end-to-end

```
1. kubectl construye POST /apis/apps/v1/namespaces/default/deployments
     (lee kubeconfig: endpoint del API server + credenciales)
                                │
                                ▼
2. kube-apiserver recibe la request:
     a) authn    — cert cliente o bearer token válido
     b) authz    — RBAC: ¿puede crear Deployments en 'default'?
     c) admission mutating    — webhooks pueden modificar (p.ej. inject sidecar)
     d) admission validating  — webhooks pueden rechazar (p.ej. Kyverno)
     e) validación de schema  — OpenAPI del tipo Deployment v1
     f) persistencia          — escribe en etcd (via gRPC)
                                │
                                ▼
3. Deployment controller está haciendo WATCH /apis/apps/v1/deployments.
   Recibe ADDED. Crea un ReplicaSet vía el API server.
                                │
                                ▼
4. ReplicaSet controller está haciendo WATCH /apis/apps/v1/replicasets.
   Recibe ADDED del nuevo RS. Cuenta Pods matching su selector (0).
   Crea 3 Pods vía el API server.
                                │
                                ▼
5. kube-scheduler está haciendo WATCH de Pods con spec.nodeName vacío.
   Para cada Pod: filter nodes → score → PATCH spec.nodeName = <nodo>.
                                │
                                ▼
6. kubelet de cada nodo elegido hace WATCH:
     /api/v1/pods?fieldSelector=spec.nodeName=<yo>
   Para cada Pod asignado:
     - CRI → runtime: pull imagen, crea pod sandbox (netns, cgroup)
     - CNI configura red (IP del Pod)
     - CSI monta volúmenes (si hay)
     - runtime arranca containers
                                │
                                ▼
7. kubelet escribe status.phase=Running, status.podIP=…,
   status.containerStatuses vía el API server
   (API server escribe a etcd).
                                │
                                ▼
8. (Si hay un Service con selector matching):
     Endpoints/EndpointSlice controller nota los Pods Ready y
     actualiza los EndpointSlices.
     kube-proxy nota el cambio y reprograma iptables/IPVS/eBPF.
     El tráfico al VIP del Service balancea a los nuevos Pods.
```

## Preguntas

1. Tres razones distintas de "por consistencia": (a) **centralización de authn/authz/admission** — un solo lugar donde aplicar RBAC y policies; (b) **auditoría** — un solo log de todas las intenciones (útil para forense y compliance); (c) **desacoplamiento del almacenamiento** — se puede cambiar `etcd` por `kine`/SQL (como hace k3s) sin tocar controllers ni kubelet; (d) **versionado del API** — el API server convierte entre `v1beta1` ↔ `v1` on-the-fly, lo cual sería imposible con acceso directo a `etcd`.

2. Los Pods **ya corriendo** siguen corriendo normalmente: los sostiene el `kubelet` + el runtime del nodo. kube-proxy sigue enrutando. El scheduler **no es ruta crítica para Pods existentes**. Los Pods **nuevos** que se declaren se quedan `Pending`: están en `etcd` sin `spec.nodeName`, y nadie los asigna. Cuando el scheduler vuelve, los procesa y pasan a correr. Esto ilustra que **el control plane se puede caer brevemente sin tirar los workloads** — es resiliente por diseño.

3. **`kube-controller-manager`** contiene los controllers que son **cloud-agnósticos** (Deployment, ReplicaSet, Node (la parte genérica), Endpoints, Job, PV, PVC, Namespace, GC, SA, …). **`cloud-controller-manager`** contiene los que **llaman a APIs del cloud**: crear ELBs para `Service type=LoadBalancer`, marcar Nodes `NotReady` si la instancia EC2 fue terminada, atachear EBS a nodos para PVCs, configurar rutas en VPCs. Se separaron para que (a) el **core de K8s sea cloud-agnóstico** y portable, y (b) cada proveedor cloud pueda liberar su implementación en su propio ciclo sin forkear K8s. En self-hosted puedes correr sin `cloud-controller-manager`; en EKS/GKE/AKS lo opera el proveedor.

4. Paso a paso tras `kubectl delete pod web-xxxxx`:
   - El API server marca el Pod `Terminating`, llama al `preStop` si existe, envía SIGTERM, espera `terminationGracePeriodSeconds`, SIGKILL, y lo elimina de `etcd`.
   - El **ReplicaSet controller** (en el kube-controller-manager) está haciendo WATCH sobre Pods matching su selector. Recibe el evento DELETED. Cuenta los que quedan: 2. Su `spec.replicas` dice 3.
   - **Escribe un Pod nuevo** vía el API server (con otro hash en el nombre, mismo pod-template-hash).
   - El API server lo persiste en `etcd`.
   - El **kube-scheduler** (WATCH sobre Pods sin `spec.nodeName`) lo observa, filtra+scorea nodos y le pone `spec.nodeName = <nodo>`.
   - El **kubelet** de ese nodo (WATCH filtrado) lo observa, llama a CRI, CNI, CSI, y arranca el contenedor.
   - El kubelet escribe `status.phase=Running`. Tienes 3 Pods otra vez. **El sistema convergió solo.**

5. Un Pod **comparte** entre sus contenedores: (a) **network namespace** (misma IP, mismos puertos, se hablan por `localhost`); (b) **IPC namespace** (colas, shm); (c) **volúmenes** que estén montados en varios; (d) **ciclo de vida** (se schedulean juntos al mismo nodo y mueren juntos). **No comparten** por default: (a) **PID namespace** (cada container es su propio árbol de procesos; habilitable con `shareProcessNamespace: true`); (b) **mount namespace** (cada container tiene su propio rootfs); (c) **filesystem** (salvo `volumes` compartidos). Un Pod es la **unidad mínima de scheduling y de red**, no un contenedor envuelto.

6. **`403 Forbidden`** se produce en la fase de **autorización (RBAC)**, después de autenticación exitosa. Significa: el API server **sí** sabe quién eres (authn pasó — tu cert o token son válidos), pero el **RBAC** no te concede permiso para hacer esa acción sobre ese recurso en ese namespace. Diferencia clave: `401 Unauthorized` sería "no sé quién eres" (authn falló); `403 Forbidden` es "sé quién eres y no puedes". La corrección es ajustar un `Role`/`ClusterRole` + `RoleBinding`/`ClusterRoleBinding`, no cambiar credenciales.

7. **Sí, el cluster sigue existiendo conceptualmente** — el estado deseado completo (todos los Deployments, Services, ConfigMaps, Secrets, etc.) vive en `etcd`. Los nodos son `Node` objects del API; perder las VMs físicas marca esos objetos como `NotReady` y los Pods quedan sin nodo donde correr. Para "recuperar": provisionas VMs nuevas, instalas `kubelet`, les das el kubeconfig del cluster (apuntando al mismo API server), y se registran como nuevos `Node` objects. Los controllers reconcilian: el Deployment controller nota que faltan Pods, el scheduler los asigna a los nuevos nodos, los kubelets los arrancan. Esto confirma el modelo mental: **el cluster es un API con controllers**; las máquinas son recursos reemplazables.
