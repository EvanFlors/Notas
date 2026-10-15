# k8s-07 — Networking en Kubernetes: CNI, NetworkPolicy, Ingress y Gateway API

> Lectura profunda. 12 secciones. ~3 h de lectura + exploración. Lee de corrido una vez; vuelve con los ejemplos abiertos.

---

## 1. El modelo de red de Kubernetes

Kubernetes impone **tres reglas** sobre cualquier implementación de red del cluster:

1. **Todo Pod puede alcanzar a todo Pod sin NAT** dentro del cluster, independientemente del nodo.
2. **Todo nodo puede alcanzar a todo Pod sin NAT**.
3. La **IP que un Pod ve de sí mismo** es la misma que ven los demás Pods.

Esto se llama a veces el "flat network model". Sus consecuencias:

- **No hay NAT entre Pods** (el VIP del Service sí hace rewrite, pero Pod-a-Pod directo no).
- Es un modelo **default-open**: sin NetworkPolicy, **cualquier Pod puede conectar con cualquier otro Pod** en cualquier namespace.
- La **separación lógica** por namespace **no es** separación de red; es solo scoping del API.

Esto se decidió así porque simplifica muchísimo el modelo mental de desarrollo (los Pods "se ven todos"), pero **contradice el principio de least-privilege** y es la razón por la que `NetworkPolicy` existe.

**Verifica el default-open:**

```bash
kubectl run c1 --image=busybox:1.36 -- sleep 3600
kubectl run c2 --image=busybox:1.36 -- sleep 3600
kubectl get pod c1 -o jsonpath='{.status.podIP}'
# luego: kubectl exec c2 -- wget -qO- <IP de c1>:... — pasa.
```

Para que esas reglas se cumplan, alguien tiene que programar la red del nodo. Ese "alguien" es un **plugin CNI**.

---

## 2. CNI: Container Network Interface

**CNI** (Container Network Interface) es una especificación de la **CNCF** para que un runtime de contenedores (containerd, CRI-O) le pida a un plugin que configure la red de un Pod cuando se crea, y que la limpie cuando el Pod se destruye.

El flujo es:

```
kubelet --(CRI)--> containerd --(CNI exec)--> plugin CNI (binario en /opt/cni/bin)
                                                 |
                                                 +-- crea veth, asigna IP, agrega rutas
                                                 +-- opcionalmente aplica NetworkPolicy
                                                 +-- opcionalmente anuncia la IP a otros nodos
```

En la práctica un "CNI" en K8s es más que el binario: es un **plugin + un controller cluster-wide** que resuelve también:

- **IPAM** (quién asigna qué subred/IP a cada Pod en cada nodo).
- **Pod-to-Pod routing entre nodos** (overlay como VXLAN/Geneve, o routing nativo BGP).
- **NetworkPolicy enforcement**.
- A veces: **reemplazo de `kube-proxy`** (iptables/IPVS → eBPF), **observabilidad L7**, **service mesh**.

### Plugins populares

| Plugin | Routing Pod-to-Pod | NetworkPolicy | eBPF | Reemplaza kube-proxy | Notas |
|--------|--------------------|---------------|------|----------------------|-------|
| **Calico** | BGP nativo o VXLAN | Sí (completo + extensiones) | Opcional (dataplane eBPF) | Opcional | Muy maduro, usado on-prem y en managed. |
| **Cilium** | VXLAN/Geneve o routing nativo | Sí (+ CiliumNetworkPolicy L7) | **Sí (nativo)** | **Sí** (`kubeProxyReplacement`) | eBPF end-to-end; observabilidad vía Hubble. |
| **Flannel** | VXLAN simple | **No** (solo con Calico encima) | No | No | Minimalista; útil para labs/edge. |
| **AWS VPC CNI** | IPs del VPC asignadas al Pod | Sí (vía Calico/CiliumPolicy addon o SecurityGroupPolicy) | Parcial | No | IPs "reales" del VPC → routeables desde fuera del cluster. |
| **GKE Dataplane v2** | Basado en Cilium | Sí (NetworkPolicy + FQDN) | Sí | Sí | Default en GKE Autopilot. |
| **kindnet** | Simple bridge + routes | **No** | No | No | Default en `kind`. Útil para labs sin policy. |

**Punto crítico para este módulo**: `kind` viene con `kindnet` por default. `kindnet` **no enforce NetworkPolicy**. Si pruebas una `NetworkPolicy` en un cluster kind "pelado", **todo el tráfico pasa** aunque la policy diga lo contrario. Hay que:

- Crear el cluster `kind` con `disableDefaultCNI: true` + instalar Calico o Cilium, o
- Dejar el default y encima instalar Calico/Cilium (que reemplaza o complementa el dataplane).

Los ejemplos y actividades de este módulo lo hacen explícito.

---

## 3. kube-proxy y los Services

Un **Service** en K8s es un VIP virtual + reglas de balanceo contra los Pods seleccionados por labels. Las reglas las programa **`kube-proxy`** en cada nodo. Modos:

- **iptables** (default): cada Service se materializa como una cadena iptables; el balanceo es random probabilístico. Escala razonablemente bien hasta miles de Services.
- **IPVS**: hash tables en kernel; mejor latencia y features de LB en clusters grandes.
- **eBPF (reemplazo de kube-proxy)**: Cilium puede desactivar `kube-proxy` y reemplazar su función con programas eBPF conectados a tc/XDP; mucho más eficiente y con mejor observabilidad.

**Un Service no es un endpoint HTTP** — es un VIP L4. No sabe de rutas HTTP, de hostnames, de TLS. Para hablar "externo-a-cluster" con esas abstracciones hace falta otra capa: **Ingress** o **Gateway API**.

---

## 4. NetworkPolicy: el modelo

`NetworkPolicy` es un recurso **namespaced** del API `networking.k8s.io/v1` que define qué tráfico puede entrar (`ingress`) y salir (`egress`) de un conjunto de Pods seleccionado por labels.

**Clave absoluta: es un modelo aditivo "default-allow hasta que haya alguna policy, luego default-deny para esa dimensión".**

Reglas exactas:

- Si **ningún** `NetworkPolicy` **selecciona** un Pod en una dimensión (ingress o egress), **todo** el tráfico de esa dimensión está permitido.
- En cuanto **algún** `NetworkPolicy` selecciona a ese Pod en una dimensión, **solo lo listado** en la unión de todas las policies aplicables está permitido; el resto se bloquea.
- Las policies **se suman** (OR lógico): si tengo dos policies que me seleccionan y una permite ingress desde `role=db-client` y otra desde `role=metrics`, el Pod acepta de ambas.

**Patrón `default-deny`** (el idioma profesional):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: app
spec:
  podSelector: {}             # selecciona TODOS los Pods del namespace
  policyTypes: ["Ingress", "Egress"]
  # sin ingress: ni egress: -> todo bloqueado para ambos sentidos
```

Encima de esto se **abren** reglas específicas:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: app
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**Observa**: hasta no permitir DNS saliente, cualquier Pod del namespace falla incluso para resolver `kubernetes.default`. Es el error #1 al introducir default-deny y lo veremos en los ejemplos.

### Selectores

- `podSelector`: labels de Pods del **mismo** namespace.
- `namespaceSelector`: labels del namespace (K8s inyecta automáticamente el label `kubernetes.io/metadata.name=<nombre>` → usable para targetear namespaces por nombre).
- `ipBlock`: CIDR + `except`; útil para egress a internet con exclusiones de rangos internos.
- Combinar `namespaceSelector` + `podSelector` **en el mismo item** = AND lógico (Pod con esos labels **en** un namespace con esos labels). Separarlos en items distintos = OR.

### Puertos

Siempre se especifican por **puerto del Pod destino**, no del Service. Puedes nombrar puertos (`name: http`) y el enforcement los resuelve.

### Lo que `NetworkPolicy` **no** hace

- No valida identidad L7 (ni headers, ni JWTs, ni rutas HTTP). Para eso: Gateway API con policies L7, o service mesh.
- No reemplaza mTLS. Son capas ortogonales.
- No se aplica si tu CNI no lo soporta. Si tu CNI es `kindnet`/`flannel`, tus policies son **papel mojado**.

---

## 5. Ingress: la primera iteración de L7 en K8s

**Ingress** (`networking.k8s.io/v1`) fue el primer recurso oficial para publicar servicios HTTP(S) al exterior con hostnames y rutas:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts: ["app.example.local"]
      secretName: web-tls
  rules:
    - host: app.example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

Un **ingress controller** (ingress-nginx, Traefik, HAProxy, etc.) observa estos recursos y los traduce a su configuración interna (nginx.conf, etc.).

### Problemas conocidos de Ingress

- **Spec minimalista**: cualquier cosa interesante (rate limit, auth, redirects, canary, mTLS backends) se hace vía **annotations específicas del controller**. Esto rompe portabilidad: la misma Ingress "corre" distinto en nginx vs Traefik vs Contour.
- **No tiene tipos para TCP/UDP/gRPC/TLS passthrough de forma estándar** (algunos controllers lo meten como ConfigMap/CRD extra).
- **Un único recurso** mezcla preocupaciones de plataforma (qué LB, qué cert manager, qué clase) con preocupaciones de la app (qué host, qué path).
- **Extensibilidad vía annotations** es un lenguaje stringly-typed sin schema.

Por eso en 2023 Gateway API alcanzó GA.

---

## 6. Gateway API: el sucesor

**Gateway API** (`gateway.networking.k8s.io`) separa responsabilidades en **tres recursos** tipados:

- **`GatewayClass`** (cluster-scoped): registra qué controller implementa esta clase (p. ej. "envoy-gateway", "istio", "contour"). Lo instala quien administra el cluster.
- **`Gateway`** (namespaced): instancia de un listener. Define puertos, protocolos, TLS, qué namespaces/rutas pueden adjuntarse. Lo crea el **equipo de plataforma**.
- **`HTTPRoute`** (+ `TCPRoute`, `TLSRoute`, `GRPCRoute`): rutas que se adjuntan a un Gateway. Lo crea el **equipo de la app** en su propio namespace.

Separación de roles:

```
Infra admin  →  instala CRDs + GatewayClass (una vez)
Platform team →  crea Gateway "shared-https" en ns `gateway-system`,
                  con listener :443 y certs, políticas de attach por namespace
App team      →  crea HTTPRoute en su namespace, apuntando al Gateway shared
```

**Ejemplo mínimo:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
  namespace: gateway-system
spec:
  gatewayClassName: envoy
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: eg-tls
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
  namespace: app
spec:
  parentRefs:
    - name: eg
      namespace: gateway-system
  hostnames: ["app.example.local"]
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 80
```

### Qué gana la Gateway API frente a Ingress

- **Tipos de ruta por protocolo** (`HTTPRoute`, `TCPRoute`, `TLSRoute`, `GRPCRoute`) con schemas propios.
- **Matching rico** nativo (headers, query params, methods, weights para traffic splitting).
- **Separación de roles clara** por recurso: no todos tocan el mismo YAML.
- **Extensibilidad estructurada**: `filters` y policy attachment en lugar de annotations stringly-typed.
- **Status detallado** (`parentRefs` reporta attach status, conditions).
- **Portabilidad real** entre implementaciones conformes (conformance suite oficial).

### Controllers populares

- **ingress-nginx**: solo Ingress (soporte experimental de Gateway API).
- **Envoy Gateway**: oficial del proyecto Envoy; implementación Gateway API first-class.
- **Traefik**: Ingress y Gateway API.
- **Contour** (VMware): Envoy debajo; Gateway API fuerte.
- **Istio Gateway** (parte de mesh): Gateway API primera clase si usas Istio.
- **Cilium Gateway API**: integrado al CNI eBPF.

### Cuándo migrar

Si estás arrancando un cluster hoy, **arranca con Gateway API**. Si ya tienes Ingresses funcionando, migra gradualmente: la Gateway API y los Ingresses pueden coexistir en el mismo cluster y controller (p. ej. ingress-nginx soporta ambos). No hay prisa, pero la dirección del ecosistema es inequívoca.

---

## 7. TLS: cómo se materializa

### En Ingress

Un `Secret` tipo `kubernetes.io/tls` guarda `tls.crt` + `tls.key`. El Ingress lo referencia por `secretName`. El controller termina TLS allí.

### En Gateway API

El `Gateway` tiene un `listener` con `tls.certificateRefs: [{name: ...}]` — mismo tipo de Secret.

### Cert manager en producción

En labs usamos **cert autofirmado** (one-liner con `openssl`). En producción se instala **cert-manager** (operator) con un `ClusterIssuer` que resuelve ACME (Let's Encrypt) o un CA interno, y los certs se auto-renuevan. Esto lo tratamos en profundidad en `k8s-16`.

### mTLS

- **mTLS entre cliente externo y Gateway**: configurable con filtros Gateway API o annotations.
- **mTLS entre Pods dentro del cluster**: para eso se usa **service mesh** (Istio, Linkerd, Cilium Service Mesh). Es ortogonal a NetworkPolicy: la policy decide **quién puede conectarse**, la mesh decide **con qué identidad criptográfica**.

---

## 8. DNS avanzado y CoreDNS

CoreDNS es el DNS server del cluster. Vive como Deployment en `kube-system` y resuelve:

- Nombres de Services: `svc.<ns>.svc.cluster.local` (y shortcuts por `search` paths).
- Nombres de Pods: con headless Services.
- Lookups externos: forward a los nameservers del nodo (`/etc/resolv.conf`).

El archivo `Corefile` (ConfigMap `coredns` en `kube-system`) es una pipeline de **plugins**:

```
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa { pods insecure fallthrough in-addr.arpa ip6.arpa }
    prometheus :9153
    forward . /etc/resolv.conf { max_concurrent 1000 }
    cache 30
    loop
    reload
    loadbalance
}
```

Plugins útiles:

- `rewrite`: reescribir nombres (útil para split-horizon DNS).
- `hosts`: hardcode entries (lab, override temporal).
- `template`: respuestas sintéticas por patrón.
- `forward`: enviar queries externas a resolvers específicos.

**NodeLocal DNSCache**: DaemonSet que corre un cache DNS local por nodo, elimina SNAT para queries DNS y descarga a CoreDNS. Casi siempre vale la pena en producción.

---

## 9. Patrón integral: default-deny + Gateway API

Un cluster bien diseñado típicamente aplica:

1. **CNI con enforcement** (Calico/Cilium).
2. **`default-deny` por namespace** (plantilla replicada al crear ns).
3. **Allow DNS saliente** (siempre).
4. **Allows específicos** (app → DB, app → cache, app → APIs externas por FQDN si CNI lo soporta).
5. **Gateway (shared) en `gateway-system`** con TLS y certs cert-manager.
6. **HTTPRoutes por app** en su namespace, con headers/match ricos.
7. **Políticas Gateway API** (p. ej. rate limit, auth) adjuntas.
8. **(opcional) Service mesh** para mTLS automático y L7 interno.

Esto da **least-privilege en red** sin perder velocidad de desarrollo.

---

## 10. Depurar networking

**Síntomas y por dónde empezar:**

| Síntoma | Primera sospecha | Comandos |
|---------|------------------|----------|
| "Mi app no resuelve DNS" después de meter netpol | Falta allow DNS egress | `kubectl exec pod -- nslookup kubernetes.default`; `kubectl describe netpol -n app` |
| "Pod a → Pod b timeout" | NetworkPolicy restrictiva o CNI roto | `kubectl exec a -- nc -zv b 8080`; `kubectl get netpol -A`; logs del CNI |
| "Ingress devuelve 404" | Host o path no coincide, controller distinto | `kubectl describe ingress`; `kubectl logs -n ingress-nginx ...`; headers de la request |
| "Ingress devuelve 503" | Service sin endpoints o backend caído | `kubectl get endpoints`; `kubectl get pods -l app=...` |
| "Gateway API no funciona" | Falta controller o CRDs | `kubectl get gatewayclass`; `kubectl describe gateway`; condition `Accepted` + `Programmed` |
| "TLS no funciona" | Secret ausente, cert expirado, host mismatch | `openssl s_client -connect host:443`; `kubectl get secret web-tls -o yaml` |
| "Service balancea raro" | `externalTrafficPolicy: Local` sin Pods en el nodo que recibe | `kubectl describe svc`; distribución de Pods por nodo |

**Herramientas útiles:**

- `kubectl exec pod -- wget/curl/nc/dig` dentro del Pod.
- `kubectl debug node/<node>` para shell en el nodo.
- Pod efímero `nicolaka/netshoot` con tcpdump/ss/dig/mtr.
- Para Cilium: `cilium monitor`, `hubble observe`.
- Para Calico: `calicoctl`.
- Para Gateway API: `kubectl describe httproute` + `conditions`.

---

## 11. Errores clásicos y antipatrones

1. **Probar NetworkPolicy en kindnet** y creer que "funcionan". No funcionan: no hay enforcement. Verifica con `kubectl exec` desde otro Pod si realmente se bloquea.
2. **Default-deny sin allow DNS**. La app no arranca, parece "crash loop" pero es un timeout de DNS. Siempre allow `UDP/53` y `TCP/53` al kube-dns.
3. **Olvidar `namespaceSelector` + `podSelector` en el mismo item**. Si quieres "pods con label X en namespace Y" **tiene que ir en el mismo item**; si los pones separados estás diciendo "pods con X en cualquier namespace **O** cualquier pod en ns con Y".
4. **Usar Ingress annotations para rate limit/auth/canary** cuando ya hay Gateway API con filtros tipados; estás acumulando deuda de portabilidad.
5. **Un único Ingress gigante** por cluster con rutas de varias apps en el mismo namespace de infra: viola separación de responsabilidades. Gateway API resuelve esto con `allowedRoutes.namespaces`.
6. **Service `LoadBalancer` directo a cada app** en lugar de un ingress/gateway compartido: pagas N IPs públicas y pierdes gestión central de TLS/WAF.
7. **mTLS "implementado" con NetworkPolicy**. No es mTLS, es filtro L3/L4. Son cosas distintas.
8. **No pensar en egress**: default-deny de ingress sin cerrar egress deja al Pod exfiltrando a cualquier parte.

---

## 12. Preguntas de evaluación

Responde sin re-leer:

1. ¿Qué cumplen las "tres reglas" del modelo de red K8s? ¿Por qué eso es default-open?
2. ¿Qué hace un CNI y por qué `kindnet` no es apto para probar NetworkPolicy?
3. Si un Pod no está seleccionado por ninguna NetworkPolicy ingress, ¿qué entra? Si está seleccionado por una policy ingress que no lista a nadie, ¿qué entra?
4. Escribe el YAML mínimo de `default-deny` para ingress y egress en un namespace.
5. ¿Por qué un `default-deny` **rompe DNS**? ¿Qué regla la arregla y cuántos puertos involucra?
6. Diferencia entre `namespaceSelector` + `podSelector` en el **mismo** item vs items **separados** dentro de un `from:`. Ejemplo de cada uno.
7. Enumera 3 limitaciones concretas de Ingress que Gateway API resuelve.
8. ¿Qué separa `GatewayClass` de `Gateway` de `HTTPRoute`? ¿Quién crea cada uno típicamente?
9. ¿Por qué un `Service: LoadBalancer` por app es peor que un `Gateway` compartido en 3 dimensiones (costo, operación, seguridad)?
10. Diseña (bulleted) la política de red para un namespace `shop` con: `web` (frontend), `api` (backend), `postgres` (DB), `redis` (cache). Quién habla con quién, dónde se abre egress a internet, qué permite DNS.
11. ¿Por qué mTLS y NetworkPolicy son capas distintas? ¿Cuál me dice **quién** puede conectar y cuál me dice **con qué identidad**?
12. Si una HTTPRoute no aparece aceptada en `status.parents[0].conditions`, enumera 4 cosas que puedes mirar antes de pedir ayuda.
