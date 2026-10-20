# k8s-04 — Teoría: Services y DNS

> 12 secciones. Lee de corrido una vez; vuelve a cada sección cuando una actividad te empuje.

---

## 1. El problema que resuelve un Service

Los Pods son **efímeros y reemplazables**. Un Deployment puede reciclar un Pod en cualquier momento: `livenessProbe` fallando, nodo drenándose, rollout, scale-down. Cada Pod recibe su propia IP (del CNI), y cuando el Pod muere, esa IP desaparece. Hardcodear IPs de Pods en un cliente HTTP sería garantía de 500s a los pocos minutos.

Un `Service` resuelve ese problema introduciendo una **abstracción estable** encima de un conjunto cambiante de Pods: nombre fijo, IP virtual fija (opcional), y una regla que dice "los backends son los Pods que matchean estas labels". El cliente le habla al Service; `kube-proxy` y CoreDNS se encargan del resto.

**Idea central:** un Service es un contrato de direccionamiento, no un proceso. No corre nada en ningún nodo. Es una entrada en `etcd` que materializa reglas de red en todos los nodos.

---

## 2. Los cinco tipos: cuándo usar cada uno

| Tipo | VIP interno | Alcanzable desde | Caso típico |
|------|:-----------:|------------------|-------------|
| `ClusterIP` (default) | sí | solo dentro del cluster | microservicio interno |
| `NodePort` | sí | cualquier IP de nodo:`30000-32767` | demo, cluster bare metal sin LB |
| `LoadBalancer` | sí | LB del cloud (public o internal) | app pública en EKS/GKE/AKS |
| `ExternalName` | **no** | DNS CNAME a hostname externo | puente a RDS, servicio externo |
| Headless (`clusterIP: None`) | **no** | DNS devuelve A-records de Pods | StatefulSet, service discovery peer-to-peer |

Reglas prácticas:

- Por **default** siempre `ClusterIP`.
- `NodePort` casi siempre es un paso intermedio ("quiero probarlo rápido desde fuera"). En producción prefieres `LoadBalancer` o `Ingress`/`Gateway API`.
- `ExternalName` es útil para encapsular dependencias externas detrás de un nombre interno (`db.default.svc.cluster.local` → `prod-postgres.c123.us-east-1.rds.amazonaws.com`), **sin** NAT ni proxy; es un CNAME puro.
- Headless es para cuando necesitas la IP individual de cada backend (StatefulSets, clientes gRPC con client-side LB, bases de datos distribuidas).

---

## 3. El contrato invisible: labels y selectores

Un Service no apunta a un Deployment ni a un ReplicaSet. Apunta a **labels**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api            # <-- cualquier Pod con esta label es backend
  ports:
    - port: 80          # puerto en el VIP
      targetPort: 8080  # puerto en el Pod
```

El controller de endpoints (parte del `kube-controller-manager`) observa los Pods del namespace, filtra por el selector y mantiene un `EndpointSlice` con las IPs reales.

**Consecuencia práctica:** si cambias las labels del Deployment pero no las del Service (o viceversa), el `endpoints` queda vacío sin ningún error en el objeto Service. Es el bug #1 de este módulo y la razón por la que `kubectl get endpoints <svc>` es tu primer reflejo al depurar.

---

## 4. Endpoints vs EndpointSlices

`Endpoints` (plural, legacy) es un único objeto con **todas** las IPs del Service. En un cluster con 5.000 pods detrás de un Service, cada cambio de un Pod reescribe un objeto gigante que todos los `kube-proxy` del cluster vuelven a procesar. No escala.

`EndpointSlices` (GA desde K8s 1.21) fragmenta en slices de hasta 100 endpoints. Cada cambio toca solo una slice. Son el default moderno; `Endpoints` se mantiene por compatibilidad.

Observa ambos:

```bash
kubectl get endpoints api
kubectl get endpointslices -l kubernetes.io/service-name=api
```

El label `kubernetes.io/service-name` es el pegamento entre un Service y sus slices.

---

## 5. `kube-proxy`: cómo el VIP se vuelve tráfico real

`kube-proxy` corre en **cada nodo**. Observa Services y EndpointSlices del apiserver y programa el data plane local. Tiene tres modos:

- **iptables** (default): instala una cadena DNAT por Service; el balanceo es aleatorio ponderado por probabilidad. Muy portable, no requiere kernel especial, pero no escala linealmente — con decenas de miles de reglas el apply se nota.
- **IPVS**: usa el load balancer del kernel Linux (`ipvsadm`); soporta algoritmos (`rr`, `lc`, `wlc`, `sh`) y escala mejor en clusters grandes.
- **eBPF** (vía **Cilium**): puede reemplazar enteramente a `kube-proxy`. Las decisiones de balanceo ocurren en programas eBPF enganchados al socket o al TC. Más performante y observable.

En `kind` el default es `iptables`. En EKS puedes elegir; en GKE Dataplane v2 es eBPF.

---

## 6. CoreDNS y el modelo de nombres

CoreDNS corre como un Deployment en `kube-system` y es apuntado por el `/etc/resolv.conf` de todos los Pods. Un Pod ve algo como:

```
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

Esto implica:

- **FQDN canónico** de un Service: `<svc>.<ns>.svc.cluster.local`.
- Dentro del **mismo namespace** puedes usar el nombre corto: `api`.
- Desde **otro namespace**: `api.other-ns` (CoreDNS completará con `svc.cluster.local`).
- `ndots:5` significa: si el nombre tiene menos de 5 puntos, intenta primero el `search path`. Por eso `curl api.default` funciona (prueba `api.default.svc.cluster.local`).

Para un Service **headless**, CoreDNS devuelve **A-records por cada Pod**:

```
$ nslookup web.default.svc.cluster.local
10.244.0.5
10.244.0.6
10.244.0.7
```

Y para un Pod individual en un `StatefulSet`:

```
$ nslookup web-0.web.default.svc.cluster.local
10.244.0.5
```

Esa es la identidad estable que StatefulSets dan y que un ClusterIP ocultaría.

---

## 7. `sessionAffinity`: pegar un cliente a un Pod

Por default el balanceo es por conexión. Si quieres que un mismo cliente caiga siempre en el mismo Pod (p. ej. para una sesión HTTP sin cookie compartida), usa:

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3h
```

Caveats:

- No sobrevive a cambio de IP del cliente (móviles, NAT corporativo).
- No es cookie-based (eso es trabajo de Ingress/Gateway, no de L4).
- Puede desbalancear si pocas IPs generan mucho tráfico.

---

## 8. `externalTrafficPolicy`: Cluster vs Local

Aplica a `NodePort` y `LoadBalancer`. Define qué pasa con tráfico **externo** que entra por un nodo.

- `Cluster` (default): el nodo que recibe puede reenviar a un Pod de otro nodo. Hace **SNAT** → el Pod ve la IP del nodo, **no la del cliente real**. Balancea mejor pero pierdes trazabilidad.
- `Local`: el nodo solo acepta si tiene un Pod listo del Service. **No** hace SNAT → el Pod ve la IP del cliente. Si un nodo no tiene Pod, los paquetes se descartan (el LB del cloud debe hacer health-check al puerto).

Cuándo importa `Local`:

- Logs de acceso con IP real.
- Rate limiting por IP.
- Geolocalización.
- Deny-list / allow-list por IP.

En kind no verás un LB real, pero el flag es idéntico.

---

## 9. Preview: Headless + StatefulSet

Los `StatefulSet` requieren un `Service` **headless** (`clusterIP: None`) para dar identidad DNS por Pod. Minimal:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
      name: http
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web          # <-- obligatorio, debe apuntar a un headless Service
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
```

Cada Pod recibe un nombre predecible (`web-0`, `web-1`, `web-2`) y un DNS predecible (`web-0.web.default.svc.cluster.local`). El profundo de StatefulSet llega en `k8s-06`.

---

## 10. Receta de depuración "mi Service no responde"

Trabaja en orden; no saltes pasos:

```bash
# 1) ¿Existe el VIP?
kubectl get svc <svc>

# 2) ¿Hay backends?  <-- paso clave
kubectl get endpoints <svc>
# Si está vacío: selector / labels no matchean, o Pods no listos.

# 3) ¿El selector es el correcto?
kubectl describe svc <svc> | grep -i selector

# 4) ¿Qué Pods matchearían ese selector?
kubectl get pods -l <key>=<value>

# 5) ¿Los Pods están Ready?  Un Pod NotReady no entra en endpoints.
kubectl get pods -l <key>=<value> -o wide

# 6) ¿Llega la petición? Levanta un cliente de debug:
kubectl run -i --rm --tty debug \
  --image=nicolaka/netshoot --restart=Never -- bash
# dentro del Pod:
curl -v http://<svc>.<ns>.svc.cluster.local:<port>
nslookup <svc>.<ns>.svc.cluster.local
```

Si `endpoints` tiene IPs pero `curl` falla, el bug es `targetPort` incorrecto, el Pod no escucha realmente ese puerto, o hay un `NetworkPolicy` bloqueando.

---

## 11. Lo que un Service NO hace (y por qué existe Ingress / Gateway API)

Un Service es L4: TCP/UDP/SCTP. No entiende HTTP, no termina TLS, no mira el `Host:` ni el path. Para eso existen:

- **Ingress** (legacy pero vivo): un objeto HTTP + reglas por host/path + controller (nginx, Traefik, HAProxy).
- **Gateway API** (sucesor estable): separa roles (`GatewayClass`, `Gateway`, `HTTPRoute`), más expresivo.

Los veremos a fondo en `k8s-07`. Hasta entonces: Service para comunicación **dentro** del cluster; Ingress/Gateway para HTTP **desde fuera**.

---

## 12. Antipatrones comunes

- **Hardcodear la IP de un Pod**: el Pod muere, tu config muere con él. Siempre nombre DNS.
- **Confundir `port` y `targetPort`**: `port` es el puerto del VIP (lo que escribes en `curl svc:XX`); `targetPort` es el puerto del contenedor. No tienen por qué coincidir.
- **Usar `NodePort` como "ingress casero" en producción**: te atas al rango 30000–32767 y expones puertos en todos los nodos.
- **Suponer que `ClusterIP` es alcanzable desde fuera**: no lo es. Es para tráfico este-oeste.
- **Olvidar que las labels son el contrato**: cambiar labels del Deployment "para refactorizar" rompe los Services silenciosamente.
- **Pensar que un Service balancea HTTP**: no, balancea conexiones L4. Dos requests sobre la misma conexión keep-alive caen en el mismo Pod.
- **Usar `externalTrafficPolicy: Local` sin pensar en los health-checks** del LB externo: nodos sin Pod no deben recibir tráfico.
- **Esperar que `ExternalName` haga NAT**: no hace. Es puro CNAME; si tu cliente no respeta `Host:`, el servidor externo lo rechazará.
