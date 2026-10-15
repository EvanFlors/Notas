# Lección: Modelo mental y arquitectura de Kubernetes

> **ID:** `k8s-01-mental-model-and-architecture` · **Nivel:** fundamentos · **Duración:** 2–3 h
> **Prerrequisitos:** curso **docker** completo (OCI, redes, volúmenes). YAML y línea de comandos.

---

## 1. Introducción intuitiva

Supón que ya sabes Docker. Tienes una app FastAPI en una imagen OCI. En tu laptop corres `docker run -p 8080:8080 miapp:1.0` y funciona. Pasas a producción. Levantas una VM, instalas Docker, haces `docker run`. Funciona. Un día la VM se cae. La app se cae. La levantas a mano. Añades `docker compose` y un `restart: always`. Mejor, pero la VM sigue siendo un único punto de fallo.

Compras tres VMs. Instalas Docker en las tres. Ahora quieres **tres réplicas** balanceadas. Montas un nginx delante. Las tres leen la misma config. ¿Cómo despliegas una nueva versión? Escribes un script bash que hace `ssh` a cada VM, hace `docker pull`, para la vieja, levanta la nueva. ¿Rolling update? Lo codificas. ¿Health checks? Lo codificas. ¿Qué pasa si una VM muere a mitad del deploy? Lo codificas. ¿Y si quieres añadir una cuarta VM? La provisionas, instalas Docker, añades al script. ¿Y si quieres meter una segunda app con otro ciclo de vida? Duplicas el script.

Lo que empezó como `docker run` termina siendo una **plataforma de orquestación casera**: un montón de scripts bash y YAML pegados con cinta, con bugs sutiles cada vez que algo falla fuera del happy path. Al cabo de un año, lo que tienes es una **mala reimplementación** de lo que ya existe: un orquestador declarativo con reconciliation loop.

Eso es Kubernetes. Describes **qué** quieres ("tres réplicas de la imagen `miapp:1.0`, expuestas por un Service, con health check en `/healthz`"), y un conjunto de **controllers** se encarga de llevar y mantener la realidad a ese estado. Si una VM muere, un controller lo nota y rescheduling en otra. Si pides una nueva versión, un controller orquesta el rollout. Si quieres escalar a diez réplicas, cambias un número y pasa.

Pero Kubernetes es más que un orquestador — es también un **API** genérico y una **arquitectura distribuida** con piezas específicas. Este módulo construye el modelo mental correcto *antes* de instalar nada. Si no entiendes `spec` vs `status`, el reconciliation loop y por qué el API server es la única puerta a `etcd`, el resto del curso te parecerá magia frustrante.

---

## 2. Fundamentos

Tres ideas que necesitas fijar antes de ver cualquier `kubectl`:

### 2.1 Declarativo con `spec` y `status`

En Kubernetes, **todo recurso** (Pod, Deployment, Service, Node, Namespace, ConfigMap, PersistentVolume, lo que sea) es un objeto en el API con dos campos clave:

- **`spec`** — el estado **deseado**. Lo escribe quien crea/edita el objeto (humano, controller, CI).
- **`status`** — el estado **observado**. Lo escribe el componente que ejecuta la realidad (típicamente un controller o el kubelet).

Ejemplo mental de un Pod:

```
spec:
  containers:
    - name: web
      image: nginx:1.27
      ports: [{ containerPort: 80 }]

status:
  phase: Running
  podIP: 10.244.1.17
  containerStatuses:
    - name: web
      ready: true
      restartCount: 0
```

El usuario escribió `spec`. El `kubelet` del nodo asignado escribió `status` conforme el Pod arranca. **Nunca** escribes `status` a mano — es territorio de los controllers.

### 2.2 Reconciliation loop

Un **controller** es un proceso con un bucle infinito que:

1. **Observa** (`watch`) el `spec` del tipo de recurso que le compete, vía el API server.
2. **Observa** el `status` actual (o la realidad externa — nodos, cloud, red, etc.).
3. Calcula la **diferencia** entre lo deseado y lo observado.
4. **Emite acciones** (crear/modificar/borrar otros objetos; o llamar a una API externa) para converger.
5. Actualiza `status` con lo que vio y vuelve a 1.

Esto es toda la ingeniería mental de Kubernetes. Un **Deployment controller** reconcila "quiero N réplicas de esta imagen" creando/escalando un ReplicaSet. Un **ReplicaSet controller** reconcila "quiero N Pods con este template" creando/borrando Pods. Un **Node controller** marca nodos como `NotReady` si dejan de hacer heartbeat. Un **cert-manager controller** reconcila un `Certificate` CR pidiendo un cert a Let's Encrypt.

El sistema no es "haz esto". Es "quiero esto; alguien convergerá". Si una acción falla, el loop lo intentará otra vez. Si borras algo que debería existir, el controller lo recrea. **Idempotencia por diseño**, no por disciplina.

### 2.3 El cluster es un API, no una máquina

Un novato piensa "el cluster es un conjunto de máquinas". Un practicante piensa "el cluster es un API con controllers". La diferencia importa:

- Las máquinas (nodos) son **recursos** del API, representados como objetos `Node`. Pueden entrar y salir sin que la identidad del cluster cambie.
- La **fuente de verdad** no es ningún nodo — es `etcd`, al que solo `kube-apiserver` escribe. Si pierdes todos los nodos pero conservas `etcd`, el cluster "sigue existiendo" conceptualmente; solo falta ejecutar.
- `kubectl` no habla con los nodos. Habla con el **API server**. El API server es el único que habla con `etcd`. Los nodos escuchan al API server. Todo pasa por un embudo.

Memoriza las tres ideas: **`spec`/`status`**, **reconciliation loop**, **cluster = API con controllers**. Son toda la base de este módulo.

---

## 3. Contexto histórico

Kubernetes no cayó del cielo. Viene de una línea de pensamiento sobre orquestación de contenedores que lleva más de dos décadas:

- **~2003** — Google empieza a operar **Borg** internamente. Borg es un orquestador cerrado que corre casi toda la infra de Google (search, Gmail, etc.) sobre un pool de máquinas compartidas. Modelo mental: *jobs declarativos sobre un cluster*.
- **~2013** — Google construye **Omega** como refinamiento de Borg (scheduler compartido optimista en lugar de monolítico).
- **2013** — Docker libera `docker run`: hace trivial empaquetar y correr un contenedor en una máquina. Nadie resuelve bien el problema de "muchas máquinas".
- **2014** — Google libera **Kubernetes** como open source, basado en lecciones de Borg/Omega. El nombre viene del griego "piloto" o "timonel". El commit inicial es de Joe Beda, Brendan Burns y Craig McLuckie.
- **2015** — **v1.0** de Kubernetes. Nace la **CNCF** (Cloud Native Computing Foundation) bajo la Linux Foundation; K8s es su primer proyecto donado.
- **2016–2017** — Explosión del ecosistema: Helm, StatefulSets, RBAC, CRDs estables → aparecen los primeros **operadores** (controllers con dominio de negocio).
- **2018** — Se estandarizan las interfaces de plugin: **CRI** (Container Runtime Interface), **CNI** (Container Network Interface), **CSI** (Container Storage Interface). Esto permite intercambiar runtimes/CNIs/CSIs sin tocar el core.
- **2017–2020** — EKS (AWS), GKE (Google), AKS (Azure) y OKE (Oracle) consolidan la oferta **managed**. "No corras tu control plane si no tienes que".
- **2020** — K8s deprecia *dockershim* (el shim que permitía usar Docker como runtime) y migra a **CRI puro** (containerd, CRI-O). Esto no cambia tus imágenes (siguen siendo OCI); cambia *quién* las ejecuta.
- **2021–2023** — Gateway API GA; **Pod Security Admission** reemplaza PodSecurityPolicy (removido en v1.25); **Karpenter** desplaza al Cluster Autoscaler clásico; **sidecar containers nativos** entran a estabilización.
- **2024+** — **ValidatingAdmissionPolicy** (CEL en el API server, sin webhook); **DRA** (Dynamic Resource Allocation) para GPUs; sidecar containers nativos GA.

Qué memorizar: Kubernetes **no inventó la orquestación de contenedores** (Borg la hacía desde 2003). Inventó una **API declarativa portable y extensible** sobre esa idea, y la liberó como estándar de facto. Hoy el "cluster" lo gestiona el proveedor cloud (EKS/GKE/AKS) o lo levantas con kubeadm/kops/Cluster API; en ambos casos la API es la misma. Esa portabilidad del skill es gran parte del valor.

---

## 4. Funcionamiento interno

### 4.1 Las piezas

Para que todo lo anterior funcione, Kubernetes se divide en **control plane** (el "cerebro") y **data plane** (los nodos que ejecutan workloads). Diagrama de alto nivel:

```
┌───────────────────────────────────────────────────────────┐
│                       CONTROL PLANE                       │
│                                                           │
│  ┌─────────────────┐    ┌──────────────────────────────┐  │
│  │ kube-apiserver  │◄──►│ etcd (KV store, Raft)        │  │
│  │  única puerta   │    │  fuente de verdad del cluster│  │
│  │  autenticación  │    └──────────────────────────────┘  │
│  │  autorización   │                                      │
│  │  admission      │                                      │
│  └────────▲────────┘                                      │
│           │ watch/update                                  │
│   ┌───────┴─────────────────────────────────────────┐     │
│   │ kube-scheduler                                  │     │
│   │   asigna nodo a cada Pod sin nodo asignado      │     │
│   ├─────────────────────────────────────────────────┤     │
│   │ kube-controller-manager                         │     │
│   │   N controllers: Deployment, ReplicaSet, Node,  │     │
│   │   Job, Endpoints, ServiceAccount, …             │     │
│   ├─────────────────────────────────────────────────┤     │
│   │ cloud-controller-manager                        │     │
│   │   integra con APIs del cloud (LB, Nodes, Vols)  │     │
│   └─────────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────┘
                            ▲
                            │ kubelet talks only to apiserver
                            │
┌───────────────────────────┼───────────────────────────────┐
│                       DATA PLANE  (muchos nodos)          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Node 1                                              │  │
│  │   kubelet       — aplica specs de Pods del nodo     │  │
│  │   kube-proxy    — reglas iptables/IPVS/eBPF (Svc)   │  │
│  │   container     — containerd / CRI-O                │  │
│  │     runtime       (pulls imágenes, ejecuta ctr)     │  │
│  │   CNI plugin    — red del Pod (Calico, Cilium, …)   │  │
│  │   CSI driver    — volúmenes (EBS, PD, …)            │  │
│  └─────────────────────────────────────────────────────┘  │
│  (Node 2, Node 3, …, Node N — mismos componentes)         │
└───────────────────────────────────────────────────────────┘
```

### 4.2 Componentes del control plane, uno por uno

**`kube-apiserver`** — el **único** proceso del cluster que escribe en `etcd`. Expone la **API REST** de Kubernetes (`/api/v1/pods`, `/apis/apps/v1/deployments`, etc.). Todas las requests pasan por:

1. **Autenticación** (certs TLS cliente, bearer tokens, OIDC, webhooks).
2. **Autorización** (RBAC: ¿este usuario puede hacer esta acción sobre este recurso?).
3. **Admission** (mutating → validating): webhooks o policies que pueden *modificar* o *rechazar* la request antes de persistir.
4. **Validation** del esquema del recurso.
5. **Persistencia** en `etcd`.

Es horizontalmente escalable (varias réplicas detrás de un LB) porque es *mayormente* stateless — el estado vive en `etcd`.

**`etcd`** — base de datos clave-valor **consistente** (algoritmo **Raft**). Guarda **todos** los objetos del cluster: Pods, Deployments, Secrets, Nodes, ConfigMaps, etc. Es la **fuente de verdad**. Si pierdes `etcd` sin backup, perdiste el cluster — por eso en producción corre con 3 o 5 nodos (quorum impar) y se le hacen snapshots periódicos. Nadie más que `kube-apiserver` lo toca directamente; los controllers y `kubelet` consumen el API, no `etcd`.

**`kube-scheduler`** — mira Pods con `spec.nodeName` vacío (todavía no asignados a ningún nodo), aplica una fase de **filtering** (descarta nodos que no caben: requests, taints, affinity, …) y una de **scoring** (puntúa los que quedan), y le pone `spec.nodeName = <elegido>` al Pod vía el API server. **No ejecuta el Pod** — solo decide dónde debería correr. El `kubelet` del nodo elegido es quien lo arranca.

**`kube-controller-manager`** — un **único binario** que contiene **muchos** controllers en gorutinas separadas: Deployment, ReplicaSet, StatefulSet, DaemonSet, Job, CronJob, Node, Endpoints, EndpointSlice, ServiceAccount, GC, PV, PVC, Namespace, etc. Cada uno tiene su propio reconciliation loop. Se junta en un solo proceso por motivos de empaquetado, no de arquitectura.

**`cloud-controller-manager`** — controllers específicos del cloud (crear un ELB cuando aparece un `Service type=LoadBalancer`, marcar un Node como `NotReady` si la instancia EC2 fue terminada, atachear EBS a nodos para PVCs, etc.). Se separó del `kube-controller-manager` para que el core de K8s sea cloud-agnóstico.

### 4.3 Componentes del nodo (data plane)

**`kubelet`** — agente que corre en **cada nodo**. Habla **solo** con el API server (nunca con `etcd` directamente). Mira los Pods asignados a su nodo (via `spec.nodeName`), llama al **container runtime** vía **CRI** para arrancarlos, les monta volúmenes vía **CSI**, les configura red vía **CNI**, hace **probes** (liveness/readiness/startup) y actualiza `status.containerStatuses` por cada contenedor. Si el kubelet se cae, los contenedores siguen corriendo (los sostiene el runtime), pero nadie actualiza su estado y el Node será marcado `NotReady` cuando falte heartbeat.

**`kube-proxy`** — mantiene las reglas de kernel (**iptables**, **IPVS** o programas **eBPF**) que materializan los **Services**. Un Service es solo un VIP + selector por labels; `kube-proxy` traduce eso a reglas que balancean tráfico a los Pods respaldantes. Con CNIs basados en eBPF (Cilium) se puede reemplazar `kube-proxy` por completo.

**Container runtime** (containerd, CRI-O) — ejecuta los contenedores. Habla con el kubelet vía **CRI** (gRPC). Internamente usa un runtime de bajo nivel OCI (`runc`, `crun`). Esto es exactamente lo que viste en `dkr-01`.

**CNI plugin** (Calico, Cilium, Flannel, AWS VPC CNI, …) — configura la red del Pod: le asigna IP, crea el veth-pair, inyecta rutas. El modelo de red K8s dice "todo Pod puede alcanzar a todo Pod sin NAT" — el CNI es quien lo hace cierto.

**CSI driver** (EBS CSI, GCE PD CSI, local-path, Longhorn, …) — provisiona y montea volúmenes. Permite al cluster manejar storage externo heterogéneo con una interfaz única.

### 4.4 El Pod como unidad mínima

**Un Pod NO es "un contenedor envuelto".** Es la unidad **mínima de scheduling** y de red. Un Pod agrupa 1..N contenedores que:

- Comparten el **mismo network namespace** (misma IP, mismos puertos — se hablan por `localhost`).
- Comparten el **mismo IPC namespace**.
- Pueden compartir volúmenes montados en varios de los contenedores.
- Viven y mueren **juntos** (se schedulean en el mismo nodo; si uno es rescheduling, todo el Pod lo es).
- No comparten PID namespace por default (cada contenedor sigue siendo un árbol de procesos independiente), pero puede habilitarse (`shareProcessNamespace: true`).

Por qué existen Pods multi-contenedor: patrones como **sidecar** (un contenedor "ayudante" que acompaña al principal — proxy, log shipper, metrics exporter), **init containers** (contenedores que corren a completación *antes* de que arranquen los principales — migraciones, warmup de cache), y **ambient / sidecar nativos** (sidecar como `initContainer` con `restartPolicy: Always`, GA desde 2024). Son **excepcionales** — la mayoría de Pods tienen un solo contenedor principal.

Lo clave: no se declara "un contenedor" como entidad; se declara un **Pod** cuyo `spec.containers` tiene uno (o varios). El scheduler asigna *Pods* a nodos, no contenedores.

### 4.5 Modos de distribución

Hay tres grandes maneras de obtener un cluster:

- **Self-hosted** — tú levantas y operas el control plane. Herramientas: `kubeadm` (bootstrap manual), `kops` (sobre AWS), **Cluster API** (K8s gestiona otros K8s), `k3s`/`k0s` (ligeros, buenos para edge o lab). Pros: control total, portabilidad real, sin lock-in. Contras: tú operas `etcd`, upgrades, certs, HA del control plane — mucha carga operacional.
- **Managed** — el cloud opera el control plane por ti; tú traes solo los **worker nodes** (y a veces ni eso: Fargate, Autopilot). Opciones: **EKS** (AWS), **GKE** (Google), **AKS** (Azure), **OKE** (Oracle), **DOKS** (DigitalOcean), **LKE** (Linode). Pros: menos cosas que puedes romper, SLA del control plane, upgrades mayormente gestionados. Contras: cuesta más, hay límites del provider, lock-in sutil (CSI/CNI/addons).
- **Sabor ligero local** — kind, k3d, minikube, Docker Desktop. Mismo API, un solo binario o un contenedor; perfecto para **dev local, CI, demos**. No es producción.

Regla heurística: **si tienes que preguntar, usa managed**. Los equipos que operan sus propios clusters saben *por qué* lo hacen (regulación, soberanía de datos, edge, costos a escala muy grande).

### 4.6 CNCF conformance

CNCF mantiene un **programa de conformance** (`sonobuoy` ejecuta la suite oficial). Una distribución K8s es "**certified Kubernetes**" si pasa esos tests. Eso garantiza:

- Portabilidad **a nivel API**: tus manifests YAML corren igual en EKS, GKE, AKS, k3s, OpenShift, etc.
- Comportamiento consistente de los recursos core.

Lo que **no** garantiza: que la red, el storage, el ingress o los addons se comporten igual. Esos son extensibles por diseño. Un `Service type=LoadBalancer` crea un ELB en EKS, un Google Cloud LB en GKE y un Azure LB en AKS — todos cumplen el contrato de la API, pero con primitivas diferentes.

---

## 5. Ejemplo mínimo

Nada aquí requiere cluster — es lectura. Imagina este manifest de Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports: [{ containerPort: 80 }]
```

Qué pasa, paso a paso, cuando haces `kubectl apply -f` eso:

```
1. kubectl construye un POST /apis/apps/v1/namespaces/default/deployments
   con el YAML convertido a JSON.
                               │
                               ▼
2. kube-apiserver recibe la request:
     - authn (cert cliente o token del kubeconfig)
     - authz (RBAC: ¿puedo crear Deployments en 'default'?)
     - admission mutating (webhooks pueden inyectar sidecars/labels)
     - admission validating (webhooks pueden rechazar)
     - validación de esquema (coincide con el schema de Deployment v1)
     - persistencia: escribe el objeto en etcd
                               │
                               ▼
3. Deployment controller (en kube-controller-manager) está haciendo
   WATCH sobre /apis/apps/v1/deployments. Recibe el evento ADDED.
     - compara spec.replicas (3) con el estado observado (0).
     - crea un ReplicaSet con replicas=3 y el pod template.
     - escribe el ReplicaSet vía el API server (que escribe a etcd).
                               │
                               ▼
4. ReplicaSet controller está haciendo WATCH sobre ReplicaSets.
   Recibe el evento ADDED del nuevo RS.
     - cuenta cuántos Pods existen que matcheen su selector (0).
     - necesita 3; crea 3 Pods vía el API server.
                               │
                               ▼
5. Los 3 Pods quedan en etcd con spec.nodeName vacío.
                               │
                               ▼
6. kube-scheduler está haciendo WATCH sobre Pods sin nodeName.
   Para cada uno:
     - filtra nodos (requests que caben, no taints, match affinity).
     - puntúa los que pasan el filtro.
     - escribe spec.nodeName = <nodo_elegido> vía el API server.
                               │
                               ▼
7. kubelet de cada nodo elegido está haciendo WATCH sobre
   /api/v1/pods?fieldSelector=spec.nodeName=<miNodo>.
     - recibe el Pod asignado.
     - llama al container runtime vía CRI:
         - pide pull de nginx:1.27 si no está.
         - crea el pod sandbox (netns, cgroup).
         - CNI configura la red (IP del Pod).
         - CSI monta volúmenes si hubiera (acá no).
         - runtime arranca el contenedor nginx.
     - escribe status.phase=Running, status.podIP=..., etc.
       vía el API server.
                               │
                               ▼
8. kube-controller-manager (Endpoints/EndpointSlice controller) nota
   los nuevos Pods Ready con label app=web y, si existe un Service
   con selector app=web, actualiza sus EndpointSlices.
                               │
                               ▼
9. kube-proxy en cada nodo nota el cambio de EndpointSlices y
   actualiza las reglas iptables/IPVS/eBPF para balancear tráfico
   del VIP del Service a esos nuevos pod IPs.
```

Observa dos cosas:

1. **Nadie escribió `status`** a mano. Lo escribieron los controllers y el `kubelet`. Tú solo escribiste `spec`.
2. **Nadie dio instrucciones imperativas** ("crea 3 Pods, llama a `docker run` en el nodo X"). Describiste un estado deseado; una cadena de controllers reconcilió, cada uno en su propio bucle, usando el API server como pizarra compartida.

Este es el patrón entero de Kubernetes. Multiplicarlo por todos los tipos de recursos (y por CRDs + controllers de terceros) da el sistema.

---

## 6. Implementación progresiva

Un camino de aprendizaje realista — qué entender *antes* y qué *después*:

**Paso 1 — Modelo mental (este módulo).** `spec`/`status`, reconciliation loop, control plane vs data plane, Pod como unidad. Sin tocar nada.

**Paso 2 — Cluster local y CLI (`k8s-02`).** Levantar un cluster con **kind** o **k3d**, instalar `kubectl`, usar `get/describe/apply/explain`, trabajar con kubeconfig y namespaces.

**Paso 3 — Pods y Deployments (`k8s-03`).** Primer workload: Deployment de la app FastAPI. Rolling update. Rollback. Entender por qué nadie crea Pods a mano en producción.

**Paso 4 — Services y DNS (`k8s-04`).** Exponer el Deployment dentro del cluster vía Service. CoreDNS. `kube-proxy`. ClusterIP vs NodePort vs LoadBalancer vs Headless.

**Paso 5 — Config y Secrets (`k8s-05`).** ConfigMaps y Secrets, cómo se inyectan (env, volume), por qué base64 no es cifrado.

**Paso 6 — Workloads deep, networking, storage, scheduling, lifecycle (Nivel 2).**

**Paso 7 — Control plane internals, RBAC, autoscaling, operadores (Nivel 3).**

**Paso 8 — Observabilidad, seguridad, cluster lifecycle, platform patterns (Nivel 4).**

Lo importante de este módulo es que **ninguno de los pasos siguientes tiene sentido** si no tienes claro el modelo mental: por qué los Pods son "ganado y no mascotas", por qué el API server es el embudo, por qué el cluster es una API, por qué los controllers son el patrón.

---

## 7. Aplicación profesional

En una organización madura, Kubernetes **no es un detalle**: es la **plataforma** sobre la que corre todo (o casi). El flujo típico:

```
   Developer                 CI (GitHub Actions)                 Cluster (EKS/GKE)
   ─────────                 ───────────────────                 ─────────────────
   edita Dockerfile          build imagen OCI                    (nada todavía)
   edita manifests YAML      push a registry
                             firma con cosign
   ──PR a repo de infra──>   kubectl diff / helm diff            
                             comentario del diff en el PR
                                       │
                                       ▼
                             (review humano del diff)
                                       │
                             ──merge main──
                                       │
                                       ▼
                             Argo CD / Flux ve el cambio en Git
                             y reconcila el cluster:
                               aplica manifests vía API server
                             API server valida (admission:
                               Kyverno exige imagen firmada,
                               Pod Security = restricted, etc.)
                             controllers crean/actualizan Pods
                             kubelet arranca contenedores
                             kube-proxy actualiza reglas de Service
```

Puntos clave de la práctica profesional:

- **GitOps**: el estado deseado del cluster vive en Git. **Argo CD** o **Flux** reconcilan continuamente. Nunca `kubectl apply` manual en producción.
- **Managed control plane**: EKS/GKE/AKS. Nadie opera `etcd` a mano si no tiene que.
- **Admission policies obligatorias**: Pod Security `restricted`, Kyverno exigiendo imágenes firmadas, no `cluster-admin` para apps.
- **Autoscaling en dos capas**: HPA/VPA para Pods, Karpenter para Nodes.
- **Observabilidad nativa**: Prometheus Operator, Loki, Tempo, OpenTelemetry Operator.
- **Multi-cluster**: dev / staging / prod separados; a veces regionalmente.
- **DR**: backup de `etcd`, backup de PVCs (Velero), runbooks de restore probados.

Nada de esto es exclusivo de K8s — es el patrón **GitOps + policy + observabilidad** de plataforma, y Kubernetes es su encarnación más adoptada.

---

## 8. Trade-offs

### 8.1 Kubernetes vs `docker compose`

| Dimensión | `docker compose` | Kubernetes |
|-----------|------------------|------------|
| Alcance | Una máquina | Flota de máquinas |
| Self-healing | Reinicia contenedor | Rescheduling en otro nodo si el nodo muere |
| Rolling updates | Básico | Nativo con health gates |
| Networking | Red del host o bridge local | Red cluster-wide con policies |
| Curva | Muy suave | Pronunciada |
| Cuándo | Dev local, demos, single-host prod | Producción multi-nodo, plataforma |

Si un `docker compose` en una VM te alcanza, probablemente **no necesitas K8s**. Es la actividad 01 de este módulo.

### 8.2 Kubernetes vs **Nomad** (HashiCorp)

Nomad es un orquestador más simple: un solo binario, scheduling de contenedores *y* binarios *y* VMs, menos opciones, menos ecosistema. Para muchas cargas es suficiente y mucho más barato de operar. K8s gana por **ecosistema** (Helm, operators, GitOps, mesh, policy) y **mercado laboral**.

### 8.3 Kubernetes vs **AWS ECS** / **Cloud Run** / **App Runner**

Ofertas propietarias de cloud que corren contenedores sin exponer K8s. Pros: cero fricción, integración con el resto del cloud, costo operacional mínimo. Contras: lock-in, menos portabilidad del skill, menos extensibilidad (no hay CRDs ni admission webhooks). Si estás **monocloud por decisión** y nunca vas a mover, pueden ser la respuesta correcta.

### 8.4 Self-hosted vs managed (EKS/GKE/AKS)

| Dimensión | Self-hosted | Managed |
|-----------|-------------|---------|
| Control del control plane | Total (versiones, flags, add-ons) | Limitado (lo que el proveedor expone) |
| Operación de `etcd` | Tú | Proveedor |
| Upgrades | Tú diseñas | Proveedor ayuda / fuerza ventanas |
| Costo del control plane | Instancias EC2 que operes | Suele haber un cargo horario (EKS ~$0.10/h por cluster) |
| Portabilidad | Alta | Alta a nivel API; media en add-ons |
| Carga operacional | Alta | Baja |

Regla heurística: **managed por default**, self-hosted con justificación explícita (regulación, edge, costos a muy gran escala, requerimientos únicos de kernel/CNI).

### 8.5 Kubernetes vs no-Kubernetes (serverless puro)

Lambda/Cloud Functions son otra pirámide: no hay cluster, no hay Pods, no hay nada que operar — pagas por invocación. Para muchos workloads (event-driven, APIs simples, batch) es más barato y más simple. **A menudo complementarios**: K8s para servicios long-running, serverless para spikes y glue code.

---

## 9. Errores frecuentes

### 9.1 "K8s es solo 'docker run' escalable"

No. Es un **API con reconciliation loop**. Pensarlo como un `docker run` distribuido lleva a antipatrones: crear Pods a mano, parchear objetos en caliente, perseguir cada rollout con la mano. El API y los controllers son el punto.

### 9.2 "El cluster = las VMs"

No. Las VMs son `Node` objects en el API. La **fuente de verdad** es `etcd`, al que solo el API server escribe. Si pierdes todas las VMs pero conservas `etcd`, el cluster "sigue existiendo" conceptualmente. Si pierdes `etcd` sin backup, no hay cluster.

### 9.3 "Modifico el `status` para arreglarlo"

El `status` lo escriben los controllers. Si lo modificas, el próximo tick del controller lo pisa (o entras en inconsistencias peores). Si quieres que un controller "haga algo distinto", modifica el `spec`.

### 9.4 "Creo Pods directo con `kubectl run`"

Los Pods crudos no tienen auto-replace: si el Pod muere o el nodo cae, no vuelve. Por eso en producción se declara un **Deployment** (que crea un ReplicaSet, que mantiene N Pods vivos). `kubectl run` es para experimentos de un minuto.

### 9.5 "Un Pod es un contenedor"

No. Un Pod es la **unidad mínima de scheduling**; agrupa 1..N contenedores que comparten net+IPC y viven/mueren juntos. Pensar "Pod = contenedor" rompe cuando ves sidecars, initContainers, o el patrón de proxy ambient.

### 9.6 "El scheduler ejecuta los Pods"

No. El scheduler **asigna un nodo** (escribe `spec.nodeName`). El `kubelet` del nodo elegido es quien **ejecuta** vía el container runtime. Si el scheduler se cae, los Pods nuevos quedan `Pending`; los existentes siguen corriendo porque los sostienen los kubelets.

### 9.7 "`kubectl` habla con los nodos"

No. `kubectl` habla con el **API server**. El API server media con `etcd` y con los kubelets. Nunca abres una conexión directa a un `kubelet` desde tu laptop (en producción está detrás del VPC y requiere auth específica).

### 9.8 "K8s está incluido: tengo cluster, tengo todo"

No. Un cluster *vanilla* no trae **CNI** elegido (necesitas uno), ni **ingress** (necesitas uno), ni **storage class** por default razonable, ni **autoscaler**, ni **mesh**. "No hay baterías incluidas" — es extensible por diseño. En managed, el proveedor pre-instala una selección razonable; en self-hosted, lo eliges tú.

### 9.9 "Adoptar K8s porque la empresa de al lado lo usa"

El antipatrón más caro del mercado. K8s **no es gratis**: no son solo nodos — es ingeniería de plataforma, políticas, observabilidad, upgrades, formación. Si tu workload cabe en una VM con `docker compose` y no vas a crecer, usarla es profesional; adoptar K8s "porque sí" es anti-económico. Esta discusión es la actividad 01.

---

## 10. Buenas prácticas (todavía conceptuales)

- **Declarativo siempre.** Todo en Git como YAML (o Helm/Kustomize). Nada de `kubectl edit` en producción.
- **`spec` solo lo escribes tú (o CI); `status` nunca.** Si crees que necesitas tocar `status`, probablemente estás reinventando un controller mal.
- **Managed por default.** Operar tu propio control plane requiere justificación.
- **Pods son ganado, no mascotas.** Nombres impredecibles, IDs efímeros, pueden desaparecer en cualquier momento. Si tu app depende del hostname o de persistencia local, revisa tu diseño (o usa StatefulSet con intención).
- **Un Pod = un contenedor principal** por default. Sidecars con criterio.
- **Labels como contrato.** Services, Deployments, NetworkPolicies, HPAs — todo se engancha por labels. Diseña una convención (`app`, `component`, `tier`, `env`, `version`).
- **Namespaces para separar dominios.** No para separar entornos (eso suele ser **cluster separado**).
- **No `cluster-admin` para aplicaciones.** RBAC mínimo.
- **Antes de instalar nada, entiende el modelo.** Este módulo existe por eso.

---

## 11. Ejercicios recomendados

1. **`activities/02-architecture-diagram/`** — produce un diagrama ASCII anotado del control plane + data plane y responde 7 preguntas sin consultar la lección. **Independent**.
2. **`activities/01-when-is-k8s-overkill/`** — argumenta en un ADR corto cuándo K8s **no** es la respuesta. **Independent**.

Son conceptuales. Si no puedes escribirlas con tus palabras, el modelo mental todavía no está firme.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Verdadero / falso:
- [ ] Un Pod es "un contenedor con metadata".
- [ ] `etcd` es escrito por cualquier componente del control plane.
- [ ] `kube-scheduler` ejecuta los Pods asignados al nodo.
- [ ] En Kubernetes, los Services exponen Pods vía selectores de labels.

**P2.** Explica, en tus palabras y sin diagramas, el ciclo de un `kubectl apply -f deployment.yaml` desde que la request sale de tu laptop hasta que un `kubelet` arranca el primer contenedor. Nombra los componentes por los que pasa.

**P3.** ¿Qué diferencia hay entre `spec` y `status` en cualquier recurso de K8s? ¿Quién escribe cada uno? Da un ejemplo con un Pod.

**P4.** Explica el **reconciliation loop** y da un ejemplo concreto con la cadena **Deployment → ReplicaSet → Pods**. Si borras un Pod, ¿qué pasa y por qué?

**P5.** ¿Por qué el `kube-apiserver` es la única puerta a `etcd`? Da al menos dos razones distintas de las obvias ("por consistencia").

**P6.** ¿Por qué un Pod **no es** "un contenedor envuelto"? Nombra qué comparten los contenedores de un mismo Pod y qué no.

**P7.** Compara **self-hosted** vs **managed** (EKS/GKE/AKS) en tres dimensiones: control, costo operacional y portabilidad. ¿Cuál eliges por default y por qué?

**P8.** Un compañero propone: "en vez de K8s, usemos `docker compose` en una VM — más simple". Da **tres** criterios que te ayudarían a decidir si tiene razón para un caso dado.

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Kubernetes Components* — <https://kubernetes.io/docs/concepts/overview/components/>
- *Kubernetes Architecture* — <https://kubernetes.io/docs/concepts/architecture/>
- *What is Kubernetes* — <https://kubernetes.io/docs/concepts/overview/>
- *Controllers* — <https://kubernetes.io/docs/concepts/architecture/controller/>
- *API Overview* — <https://kubernetes.io/docs/reference/using-api/>
- *Pods* — <https://kubernetes.io/docs/concepts/workloads/pods/>
- *CNCF Software Conformance* — <https://www.cncf.io/certification/software-conformance/>

Lectura complementaria:

- Burns, Beda, Hightower, Villalba — *Kubernetes Up & Running* (3ª ed.), caps. 1–3. Introducción canónica y acorde a este modelo mental.
- Verma, Pedrosa, Korupolu et al. — *Large-scale cluster management at Google with Borg* (EuroSys 2015). El paper que explica por qué K8s tiene la forma que tiene.
- Burns, Oppenheimer — *Design patterns for container-based distributed systems* (HotCloud 2016). Patrones de Pod (sidecar, ambassador, adapter).
- Documentación de los proveedores managed: **EKS** <https://docs.aws.amazon.com/eks/>, **GKE** <https://cloud.google.com/kubernetes-engine/docs>, **AKS** <https://learn.microsoft.com/azure/aks/>.
