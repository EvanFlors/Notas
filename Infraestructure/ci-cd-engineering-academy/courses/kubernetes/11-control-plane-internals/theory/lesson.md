# Lección: Control plane internals

> **ID:** `k8s-11-control-plane-internals` · **Nivel:** avanzado · **Duración:** 6 h
> **Prerrequisitos:** `k8s-01`, `k8s-02`.

---

## 1. Introducción intuitiva

Hasta aquí Kubernetes era "escribo un YAML, lo aplico, aparece un Pod". Este módulo abre la caja: cuando ejecutas `kubectl apply -f pod.yaml`, ocurren decenas de llamadas HTTP, un commit distribuido con **Raft**, dos rondas de admission, una decisión de scheduling, un `grpc` al runtime del nodo y un montón de watchers reaccionando. Todo eso tiene **nombre**, **archivo de log** y **métrica Prometheus**.

El propósito no es memorizar: es construir un mapa que te permita, ante cualquier síntoma, saber *dónde mirar*. "El Pod está `Pending`" → ¿scheduler? → `kubectl events`, logs del scheduler, filtros no cumplidos. "La request fue rechazada" → ¿admission? → audit log. "El cluster entero está lento para listar objetos" → ¿etcd? → `etcd_disk_wal_fsync_duration_seconds`.

Un cluster es un **API server que lee/escribe en etcd**, rodeado de controllers que reaccionan a cambios de ese estado. Todo lo demás es decoración.

```
         +--------------------+
cliente  |   kubectl / SDK    |
         +---------+----------+
                   | HTTPS (TLS mutual, token, cert)
                   v
  +-------------------------------------------+
  |  kube-apiserver                           |
  |   authn → authz(RBAC) → mutating admission|
  |   → validation admission → storage        |
  +---------+-------------------+-------------+
            |                   |
            | WATCH             | gRPC
            v                   v
  +------------------+   +------------------+
  | controllers,     |   |      etcd        |
  | scheduler, etc.  |   |   (Raft, KV)     |
  +--------+---------+   +------------------+
           |
           | WATCH / write Pod.spec.nodeName
           v
  +------------------+        CRI       +-------------+
  |    kubelet       | --------------->  | containerd  |
  +------------------+        CNI       +-------------+
                            CSI, kube-proxy
```

---

## 2. kube-apiserver: la cadena de una request

El `kube-apiserver` es un proceso Go que **expone la API REST** de Kubernetes y es el **único** componente que escribe en `etcd`. Toda request pasa por este pipeline:

```
request
  │
  ├─ (1) authentication     ¿quién eres? (cert cliente, token, OIDC, webhook)
  │                          → produce un user.Info { Name, Groups, UID }
  │
  ├─ (2) authorization      ¿puedes hacerlo? (RBAC es el autorizador por default;
  │                          también node auth, webhook, AlwaysAllow)
  │
  ├─ (3) mutating admission mutating controllers y webhooks pueden MODIFICAR el objeto
  │                          (p. ej., inyectar sidecars, defaulting de campos)
  │
  ├─ (4) schema validation  valida contra el OpenAPI schema del tipo
  │
  ├─ (5) validating admission  valida reglas custom; puede RECHAZAR (no modificar)
  │                          (p. ej., PodSecurity, Kyverno, Gatekeeper, VAP/CEL)
  │
  ├─ (6) storage            serializa (protobuf en etcd3), llama a etcd clientv3
  │                          → commit Raft → fsync WAL → ack
  │
  └─ (7) response + events  200/201/409 al cliente; dispara watchers (long-poll HTTP)
```

**Importante**:

- **Mutating** corre antes de **validating**. Si Kyverno agrega `runAsNonRoot: true` en mutating, luego PodSecurity (validating) lo verá y pasará.
- **Validating** no puede modificar. Solo acepta o rechaza. Esto evita bucles infinitos.
- Si cualquier paso falla, los siguientes no se ejecutan y el cliente recibe un `Status` con `code` y `reason`.
- El audit log (sección 8) registra la secuencia completa; es la fuente de forense.

Para ver todo esto en vivo:

```bash
kubectl -v=9 get pod -n kube-system 2>&1 | less
# Verás: GET /api/v1/namespaces/kube-system/pods
#        Request Headers: Authorization: Bearer ...
#        Response: 200 OK + JSON crudo
```

---

## 3. etcd: Raft, snapshots, compactación, performance

**etcd** es un KV store distribuido *fuertemente consistente* basado en el consenso **Raft**. Es la fuente de verdad de todo el cluster.

### 3.1 Raft en una frase

Un cluster etcd tiene N miembros (típicamente 3 o 5, impar). Uno es **líder**, los demás **followers**. Las escrituras van al líder, que las replica a los followers; una escritura solo se "commitea" cuando la **mayoría** la acepta y escribe su **WAL** (write-ahead log) a disco con `fsync`. Si el líder cae, los followers eligen uno nuevo (eleción con *randomized timeouts*).

Consecuencias prácticas:

- **Latencia de disco mata etcd**. `fsync` por commit → cada escritura cuesta ~1-20 ms en SSD, 50-200 ms en HDD. Un etcd en HDD colapsa el cluster.
- **No escala horizontalmente**. 5 miembros son más tolerantes pero *más lentos* (más fsyncs que esperar). Más de 7 es contraproducente.
- **Latencia de red importa** entre miembros (`etcd_network_peer_round_trip_time_seconds`).

### 3.2 Snapshots

etcd mantiene toda la historia de revisiones. Para no crecer sin límite:

- **Compactación**: elimina revisiones viejas (`etcdctl compact <rev>`). El apiserver corre un `--etcd-compaction-interval=5m` por default.
- **Defragmentación**: tras compactar, el espacio no se libera al OS; `etcdctl defrag` lo compacta físicamente. Operación **cara** (bloquea escrituras del miembro).
- **Snapshot**: foto consistente del KV store a una revisión. Se usa para backup y para que miembros nuevos se pongan al día sin replicar desde cero.

```bash
etcdctl snapshot save /backup/snap.db
etcdctl snapshot status /backup/snap.db --write-out=table
# muestra: hash, revision, total keys, size
```

### 3.3 Métricas que importan

- `etcd_disk_wal_fsync_duration_seconds` — p99 debe estar < 10ms en SSD.
- `etcd_disk_backend_commit_duration_seconds` — p99 < 25ms.
- `etcd_server_leader_changes_seen_total` — > 0 reciente es *mal síntoma* (flapping).
- `etcd_mvcc_db_total_size_in_bytes` vs `--quota-backend-bytes` (default 2 GiB).

Si tu cluster "lentea" al listar o aplicar, el culpable es casi siempre etcd. Síntoma clásico: `kubectl get pods -A` tarda 5 segundos.

---

## 4. kube-scheduler: filtros, scoring, extenders, plugins framework

El scheduler decide a qué **nodo** va cada Pod con `spec.nodeName == ""`. Es un bucle:

```
for pod in queue:
    nodes = all_nodes
    nodes = filter(pod, nodes)   # predicates: NodeAffinity, Taints, Resources, PVCFit, ...
    if not nodes:
        emit Event("FailedScheduling", reason)
        requeue
        continue
    scored = score(pod, nodes)   # priorities: LeastAllocated, Spread, ImageLocality, ...
    chosen = argmax(scored)
    bind(pod, chosen)            # PATCH pod.spec.nodeName = chosen
```

### 4.1 Scheduling framework

Desde v1.19 el scheduler es un **framework** con puntos de extensión (**extension points**):

```
PreFilter → Filter → PostFilter → PreScore → Score → NormalizeScore
          → Reserve → Permit → PreBind → Bind → PostBind
```

Cada punto admite múltiples **plugins** (Go). Ejemplos built-in: `NodeAffinity`, `TaintToleration`, `NodeResourcesFit`, `InterPodAffinity`, `PodTopologySpread`, `VolumeBinding`, `ImageLocality`.

Un **scheduler profile** (`KubeSchedulerConfiguration`) activa/desactiva plugins. Puedes correr **múltiples schedulers** con `spec.schedulerName`.

### 4.2 Extenders vs plugins

- **Extenders** (viejo): el scheduler llama por HTTP a un servicio externo tras los built-in. Deprecated en favor de plugins.
- **Plugins out-of-tree**: compilas tu scheduler con tus plugins; se usa poco salvo necesidades muy específicas (p. ej. GPU batch scheduling, co-scheduling MPI).

### 4.3 Cómo depurar scheduling

```bash
kubectl describe pod <pending> | tail -20   # Events con filtros no cumplidos
kubectl -n kube-system logs -l component=kube-scheduler --tail=50
kubectl get events --field-selector reason=FailedScheduling
```

Los mensajes son concretos: `0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector`.

---

## 5. kube-controller-manager: muchos controllers, un proceso

El `kube-controller-manager` embebe docenas de controllers oficiales (Deployment, ReplicaSet, Node, Endpoint, ServiceAccount, Namespace, Job, HPA, PV binder, …). Cada controller es un **bucle**:

```
informer = sharedInformerFor(Pod)   # cache local + WATCH
informer.AddEventHandler({
    OnAdd:    queue.Add(key),
    OnUpdate: queue.Add(key),
    OnDelete: queue.Add(key),
})

for key in queue:
    desired := spec(key)
    actual  := status(key)
    if desired != actual:
        act(desired, actual)   # PATCH / CREATE / DELETE recursos hijos
```

### 5.1 Reloj de reconciliación

Cada controller tiene su propia **cadencia**: `--horizontal-pod-autoscaler-sync-period=15s`, `--node-monitor-period=5s`, `--pvclaimbinder-sync-period=15s`. Los efectos "lentos" tras un cambio suelen deberse a esta cadencia.

### 5.2 Leader election

Para HA, varios `kube-controller-manager` corren en paralelo pero **solo uno es activo**: eligen líder vía **lease** (`coordination.k8s.io/Lease`) en etcd. Lo mismo aplica a `kube-scheduler` y `cloud-controller-manager`.

```bash
kubectl -n kube-system get lease
# NAME                                       HOLDER
# kube-controller-manager                    control-plane-xx
# kube-scheduler                             control-plane-xx
```

Si el líder pierde el lease (p. ej., GC pause > `--leader-elect-lease-duration=15s`), otro toma el relevo. Durante la transición, reconciliaciones se congelan unos segundos.

---

## 6. cloud-controller-manager

Separa del `kube-controller-manager` todo lo específico de un cloud: nodes (asociar node → VM), load balancers (crear ALB/NLB para `Service type=LoadBalancer`), routes (CIDR por nodo en VPC). Permite que `kube-controller-manager` sea cloud-agnostic.

En clusters managed (EKS/GKE/AKS) corre dentro del control plane gestionado. En self-hosted hay que desplegarlo con el provider correcto (`cloud-provider-aws`, `cloud-provider-gcp`, etc.).

---

## 7. kubelet: pod lifecycle, cAdvisor, image GC

El `kubelet` corre en **cada nodo**. Hace:

1. **WATCH** al apiserver por Pods asignados a `spec.nodeName == <my-node>`.
2. Para cada Pod nuevo o modificado:
   - Pull de imágenes (vía CRI).
   - Setup del **network namespace** y llamada al **CNI** plugin para configurar red.
   - Setup de volúmenes (**CSI** si aplica).
   - Arranca containers vía **CRI** (`containerd` / `CRI-O`).
   - Corre probes (`startup`, `liveness`, `readiness`).
3. Reporta `status` del Pod al apiserver (periódico).
4. Expone **métricas de recursos** vía **cAdvisor** (integrado) en `/metrics/cadvisor`.
5. Hace **image GC** (cuando el disco pasa `--image-gc-high-threshold`, default 85%, borra imágenes no usadas hasta `--image-gc-low-threshold`, default 80%).
6. Hace **container GC** (contenedores terminados viejos).
7. Reporta `NodeStatus` cada `--node-status-update-frequency=10s` (si no, el node controller marca el nodo `NotReady` tras `--node-monitor-grace-period=40s`).

### 7.1 Pod lifecycle (resumen)

```
Pending  → scheduler asigna nodeName
         → kubelet pulls images (ImagePullBackOff si falla)
         → kubelet runs initContainers (en orden)
         → kubelet runs containers (en paralelo)
Running  → readinessProbe OK → endpoints lo añade al Service
         → livenessProbe fail → kubelet mata+reinicia (CrashLoopBackOff con backoff exponencial)
Succeeded|Failed → Pod terminal
```

### 7.2 Static Pods

El kubelet también lee **manifests desde disco** (`--pod-manifest-path=/etc/kubernetes/manifests/`). Esto es cómo arrancan `kube-apiserver`, `etcd`, `kube-scheduler` y `kube-controller-manager` en `kubeadm`/`kind` **antes** de que haya cluster. Son los **static Pods** del control plane. Aparecen en la API como mirror Pods pero el "dueño" real es el kubelet, no un controller.

---

## 8. kube-proxy: iptables, IPVS, eBPF

El `kube-proxy` traduce `Service` → **reglas de networking en el nodo**. Observa Services y EndpointSlices y escribe reglas:

| Modo | Cómo funciona | Cuándo |
|------|---------------|--------|
| **iptables** | Reglas DNAT por Service; selección aleatoria con probabilidades | Default; bien hasta ~1-5k Services |
| **IPVS** | Hashtable en kernel (LVS); mejor latencia y throughput, varias políticas (`rr`, `lc`, `sh`) | Clusters grandes (>5k Services) |
| **eBPF (Cilium)** | **Reemplaza** kube-proxy; programas eBPF en TC/XDP | Clusters muy grandes, DSR, Egress Gateway |

Verificar modo:

```bash
kubectl -n kube-system logs -l k8s-app=kube-proxy --tail=5 | head
# "Using iptables Proxier." / "Using ipvs Proxier."
```

Cuando "mi Service no enruta", el camino de debug es: ¿Endpoints poblados? → `kubectl get endpointslices -l kubernetes.io/service-name=<svc>`. Si sí: ¿reglas en el nodo? → `sudo iptables -t nat -L KUBE-SERVICES | grep <svc>`.

---

## 9. Interfaces estandarizadas: CRI, CNI, CSI

Kubernetes no "sabe" de containerd ni de Calico ni de EBS. Habla **tres interfaces**:

- **CRI (Container Runtime Interface)** — gRPC. El kubelet pide "crea un sandbox", "arranca un contenedor con esta imagen", "mátalo". Implementaciones: `containerd`, `CRI-O`.
- **CNI (Container Network Interface)** — binario invocado por el kubelet con JSON por stdin. Configura el network namespace del Pod. Implementaciones: Calico, Cilium, Flannel, AWS VPC CNI, Weave.
- **CSI (Container Storage Interface)** — gRPC sidecar + driver por nodo. Provisioning, attach, mount de volúmenes. Implementaciones: AWS EBS, GCE PD, Longhorn, local-path.

> Antes de CRI existía *dockershim* en el kubelet. Se removió en v1.24. Hoy el kubelet nunca habla "docker"; habla CRI con `containerd` (que puede, a su vez, ejecutar OCI runtimes como `runc`).

---

## 10. Observabilidad del control plane: events, audit

### 10.1 Events

Cada componente emite **Events** sobre objetos: "FailedScheduling", "Pulled", "Started", "Killing", "BackOff". Son recursos de la API (`v1/events` y el nuevo `events.k8s.io/v1`).

```bash
kubectl events --for pod/mypod
kubectl events --types=Warning
kubectl get events --field-selector involvedObject.name=mypod --sort-by=.lastTimestamp
```

Los Events tienen TTL (default 1 h en `--event-ttl`); no son un sistema de logging duradero.

### 10.2 Auditoría (`audit.k8s.io/v1`)

El apiserver puede escribir un **audit log** con cada request procesada. Políticas (`audit-policy.yaml`) deciden qué nivel registrar:

- `None` — ignorar.
- `Metadata` — quién, qué, cuándo (sin cuerpos).
- `Request` — + request body.
- `RequestResponse` — + response body.

```bash
# flag del apiserver (en kubeadm/kind, editar el static Pod manifest):
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
```

Útil para forense ("¿quién borró el Secret?"), para postmortems y para alimentar SIEMs.

---

## 11. Ejemplo end-to-end: `kubectl apply -f pod.yaml`

Trazamos la cadena completa.

```
(1) kubectl lee ~/.kube/config → selecciona contexto → carga CA + cert cliente.
(2) kubectl GET /openapi/v3 (cache local) → sabe cómo serializar el objeto.
(3) kubectl POST /api/v1/namespaces/default/pods  { pod.yaml }  (si no existe)
      or
    kubectl PATCH ... (server-side apply, Content-Type: application/apply-patch+yaml)

(4) apiserver recibe:
    - authn: valida el cert cliente → user.Info { Name: "alice", Groups: ["dev"] }
    - authz: RBAC → ¿tiene Role que permite "create pods" en "default"? → OK
    - mutating admission:
        - DefaultStorageClass, ServiceAccount (inyecta token), MutatingWebhookConfiguration (Kyverno, Istio sidecar injector…)
    - schema validation: contra openapi del Pod
    - validating admission:
        - NamespaceLifecycle, ResourceQuota, LimitRanger
        - PodSecurity (label del namespace: baseline|restricted|privileged)
        - ValidatingWebhookConfiguration (Kyverno/Gatekeeper policies)
        - ValidatingAdmissionPolicy (CEL in-process)
    - storage:
        - serializa a protobuf
        - etcd clientv3: Txn{compare=modRev==0, put(key="/registry/pods/default/mypod", value=...)}
        - etcd leader propone a Raft → mayoría fsync WAL → commit
    - devuelve 201 Created al cliente + dispara WATCH events.

(5) kube-scheduler (watcher):
    - ve Pod con spec.nodeName="" → filter → score → bind
    - PATCH pod { "spec": { "nodeName": "node-1" } } al apiserver

(6) kubelet de node-1 (watcher):
    - ve Pod asignado
    - CRI RunPodSandbox → crea pause container + network namespace
    - CNI ADD → configura veth, IP del Pod, rutas
    - CRI PullImage → containerd baja la imagen
    - CRI CreateContainer / StartContainer (por cada container del Pod)
    - CSI NodeStageVolume / NodePublishVolume (si hay PVCs)
    - probes empiezan a correr
    - PATCH pod status { phase: Running, conditions: [Ready], containerStatuses: [...] }

(7) kube-controller-manager (endpoint controller):
    - ve Pod Ready con labels que matchean un Service
    - PATCH EndpointSlice añadiendo la IP del Pod

(8) kube-proxy en todos los nodos (watcher):
    - ve el EndpointSlice actualizado
    - re-escribe reglas iptables/IPVS para incluir la nueva IP
```

Cualquier fallo en esta cadena deja un rastro en:

- `kubectl describe pod` (events agregados).
- `kubectl events` (ordenados por tiempo).
- Audit log (si está activado).
- Logs del componente (static Pods: `kubectl -n kube-system logs <pod>`).

---

## 12. Preguntas de evaluación (sin consultar docs)

Responde por escrito. Son la evaluación del módulo.

1. Describe los 7 pasos que atraviesa una request en `kube-apiserver`, en orden, nombrando qué puede modificarla y qué puede rechazarla.
2. ¿Por qué el apiserver es el **único** componente que escribe en etcd? Da dos razones concretas.
3. ¿Qué garantía ofrece Raft y por qué un cluster etcd impar (3, 5) es preferible a uno par?
4. Un cluster tiene `etcd_disk_wal_fsync_duration_seconds` p99 = 150 ms. ¿Qué síntomas esperarías en `kubectl`? ¿Qué causa raíz investigarías primero?
5. Explica la secuencia `PreFilter → Filter → Score → Bind` del scheduling framework y qué built-in plugin descartaría un nodo con `taint: nvidia.com/gpu=true:NoSchedule` si el Pod no tiene toleration.
6. Un Pod se queda en `Pending`. Enumera los 4 lugares que mirarías *en orden* para diagnosticarlo.
7. ¿Qué es un static Pod? ¿Dónde vive su manifest en `kubeadm`/`kind`? ¿Qué pasa si editas ese manifest?
8. ¿Qué hace el `kubelet` cuando el disco del nodo supera `--image-gc-high-threshold`? ¿Puede afectar a imágenes de Pods en ejecución?
9. Compara `iptables` vs `IPVS` como modos de `kube-proxy`: cuándo cambiarías de uno a otro.
10. Describe la cadena end-to-end de `kubectl apply -f pod.yaml` desde el `~/.kube/config` hasta la aparición del contenedor en el nodo, nombrando componente, interfaz y recurso API tocado en cada paso.
