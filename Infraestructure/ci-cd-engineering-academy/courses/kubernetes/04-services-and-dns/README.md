# k8s-04 — Services y DNS

## Identificación

- **ID:** `k8s-04-services-and-dns`
- **Curso:** `kubernetes`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`.

## Objetivo

Exponer y descubrir workloads **dentro del cluster** usando la primitiva correcta de `Service`, entender cómo `kube-proxy` convierte un VIP en reglas de red reales, cómo `CoreDNS` resuelve nombres y cómo depurar el síntoma más clásico de la vida con K8s: "mi Service existe pero no responde".

## Alcance

Este módulo cubre:

- Los cinco tipos de `Service`: **ClusterIP**, **NodePort**, **LoadBalancer**, **ExternalName**, **Headless** (`clusterIP: None`).
- `Endpoints` y la primitiva moderna que escala, **EndpointSlices**.
- **CoreDNS** y el formato `<svc>.<ns>.svc.cluster.local` (más búsqueda por `search path`).
- Modos de `kube-proxy`: **iptables** (default), **IPVS**, **eBPF** (sustitución vía Cilium).
- `sessionAffinity` (ClientIP) y `externalTrafficPolicy: Cluster` vs `Local` (por qué importa para preservar la IP del cliente externo).
- Diagnóstico cuando un `Service` "no enruta": `endpoints` vacío, selector mal escrito, `targetPort` incorrecto, `readinessProbe` fallando, política de red bloqueando.

Lo que **no** cubre (vendrá después):

- `Ingress` y `Gateway API` → `k8s-07-networking-cni-netpol-ingress-gateway-api`.
- `NetworkPolicy` y CNIs a fondo → `k8s-07`.
- `StatefulSet` completo (solo preview mínimo de por qué pide Headless) → `k8s-06`.

## Materiales

- **`theory/lesson.md`** — 12 secciones (de qué es un Service a cómo depurarlo).
- **`examples/`**:
  - `01-clusterip-and-nodeport/` — mismo Deployment expuesto por ClusterIP y por NodePort; vemos los dos VIPs y el mapping al nodo.
  - `02-headless-stateful/` — `clusterIP: None` + preview breve de `StatefulSet` para entender por qué un Postgres pide Headless.
  - `03-coredns-resolution/` — `nslookup` desde un Pod cliente contra Services FQDN, cortos, headless y `ExternalName`.
- **`activities/`**:
  - `01-expose-api-via-clusterip/` (guided-lab) — exponer una API HTTP vía ClusterIP y consumirla por nombre DNS desde otro Pod.
  - `02-debug-no-endpoints/` (independent / debug) — un `Service` con selector mal etiquetado; el estudiante diagnostica por `kubectl get endpoints` y aplica el arreglo mínimo.
- **`resources/links.md`** — docs oficiales y lecturas complementarias.

## Temas y subtemas

1. Qué es un `Service` conceptualmente
   - Abstracción estable sobre un conjunto cambiante de Pods.
   - VIP virtual + reglas de red programadas por `kube-proxy`.
2. Los cinco tipos
   - `ClusterIP` (default; VIP interno).
   - `NodePort` (expone un puerto en todos los nodos; superconjunto de ClusterIP).
   - `LoadBalancer` (depende del cloud; superconjunto de NodePort).
   - `ExternalName` (CNAME DNS, sin VIP ni proxy).
   - **Headless** (`clusterIP: None`): sin VIP; DNS devuelve A-records de los Pods.
3. Selectores y labels como contrato
   - El Service **no** conoce al Deployment: conoce **labels**.
   - Mismatch de labels es la causa #1 de "endpoints vacío".
4. Endpoints y EndpointSlices
   - `Endpoints` legacy: una sola lista por Service → no escala.
   - `EndpointSlices`: varias slices (hasta 100 endpoints por slice) → mejor en clusters grandes y mejor para IPv6/dual-stack.
5. `kube-proxy` por dentro
   - `iptables` (default): reglas DNAT por servicio; balanceo aleatorio ponderado.
   - `IPVS`: hashing (rr, lc, wlc, sh) a escala.
   - `eBPF` vía Cilium: puede reemplazar `kube-proxy` entero.
6. CoreDNS y nombres
   - FQDN completo: `<svc>.<ns>.svc.cluster.local`.
   - `search` path en `/etc/resolv.conf` del Pod.
   - Resolución de headless Services (A-records por Pod).
7. `sessionAffinity`
   - `None` (default) vs `ClientIP` (`sessionAffinityConfig.clientIP.timeoutSeconds`).
   - Caveats: no sobrevive a cambio de IP de cliente ni a múltiples NAT.
8. `externalTrafficPolicy`
   - `Cluster` (default): tráfico externo cae en cualquier nodo y hace SNAT → pierdes IP del cliente.
   - `Local`: solo nodos con Pod reciben; preservas IP del cliente pero puede desbalancear.
9. Preview de `StatefulSet` + Headless
   - Por qué `cassandra`, `postgres`, `kafka` piden `clusterIP: None`.
   - Identidad DNS estable `<pod-name>.<svc>.<ns>.svc.cluster.local`.
10. Depurar un Service en 5 pasos
    - `kubectl get svc` → ¿existe el VIP?
    - `kubectl get endpoints <svc>` → ¿hay backends?
    - `kubectl describe svc <svc>` → ¿selector correcto?
    - `kubectl get pods -l <selector>` → ¿matchean?
    - `kubectl exec <cliente> -- curl <svc>:<port>` → ¿llega la petición?
11. Qué queda fuera (y cuándo entra Ingress/Gateway API)
    - Services son L4 (TCP/UDP/SCTP). Para HTTP + TLS + host/path → `Ingress` o `Gateway API`.
12. Antipatrones comunes
    - Hardcodear la IP del Pod.
    - Confundir `port` con `targetPort`.
    - Usar `NodePort` como "ingress casero" en producción.
    - Pensar que `ClusterIP` es alcanzable desde fuera del cluster.

## Conceptos internos (fundamentos)

- Un `Service` **no es un proceso**. Es una entrada en etcd que el controller de endpoints materializa como `EndpointSlice`s, y que `kube-proxy` (en cada nodo) traduce a reglas de `iptables`/`IPVS`/`eBPF`. Cuando un Pod hace `curl http://api.default:8080`, su kernel resuelve `api.default` vía CoreDNS, obtiene el VIP, y las reglas de `kube-proxy` hacen DNAT al IP:puerto de un Pod seleccionado.
- Las labels son el pegamento del contrato. El `Service.spec.selector` **no apunta** al `Deployment`; apunta a labels de Pods. Un typo en una label (`app: web` vs `app: webapp`) deja `endpoints` vacío sin ningún error visible en el Service.
- `EndpointSlices` reemplazan a `Endpoints`: cada slice tiene hasta 100 endpoints, lo que evita que un cambio en un Pod obligue a reescribir una estructura gigante. Son la base del scale a miles de pods.
- `Headless Service` (`clusterIP: None`) desactiva el VIP: CoreDNS responde directamente con los A-records de los Pods del selector. Es cómo los `StatefulSet` dan identidad DNS estable (`web-0.web.default.svc.cluster.local`).
- `externalTrafficPolicy: Local` cambia la topología: solo nodos con Pods listos aceptan el tráfico, y no se hace SNAT → el Pod ve la IP real del cliente externo (crítico para logs de acceso, rate limiting, geolocalización).

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué objetos participan en que un `curl api.default` desde un Pod llegue a otro Pod. Explicar la diferencia operacional entre los 5 tipos de Service. |
| Operativa | Exponer una app por ClusterIP y consumirla por FQDN. Diagnosticar en < 2 min "no responde" leyendo `endpoints` y labels. |
| Arquitectónica | Elegir Service type por caso (interno vs externo, con/sin VIP, con/sin preservación de IP cliente). Justificar cuándo Headless es necesario. |

## Entregables

- Una app desplegada en un cluster `kind` accesible por nombre DNS (`<svc>.<ns>.svc.cluster.local`) desde un Pod cliente.
- Diagnóstico escrito de los 3 escenarios de "mi Service no responde" (ver evaluación).
- Los dos `tests/validate.sh` de las actividades deben pasar.

## Criterios de evaluación

- Capacidad de **explicar los 3 escenarios de "mi Service no responde"** sin consultar docs:
  1. `kubectl get endpoints <svc>` → vacío → selector/label mismatch o Pods no listos.
  2. `endpoints` tiene backends pero `curl` falla → `targetPort` incorrecto o Pod no escucha ese puerto.
  3. `endpoints` y puerto correctos pero `curl` cuelga → `NetworkPolicy` bloquea o el Pod cliente usa el nombre corto cuando el namespace es otro.
- Capacidad de elegir el tipo correcto para 3 casos dados (app interna microservicio, Postgres stateful, redirección a RDS externo).
- Capacidad de leer un `kubectl describe svc` y señalar `Selector`, `Endpoints`, `Session Affinity`, `External Traffic Policy`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-clusterip-and-nodeport/`.
3. Reproduce `examples/03-coredns-resolution/` (necesitarás el cluster del ejemplo 1).
4. Haz `activities/01-expose-api-via-clusterip/`.
5. Lee `examples/02-headless-stateful/` como preview (volveremos en `k8s-06`).
6. Haz `activities/02-debug-no-endpoints/`.
7. Responde la evaluación sin consultar.

## Siguiente

→ `k8s-05-config-secrets-env-volumes-basics`: inyectar configuración y secretos al workload que ya sabes exponer y descubrir.
