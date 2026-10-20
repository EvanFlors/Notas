# Ejemplo 03 — GKE Ingress clásico vs Gateway API

> Lectura y análisis. Sin ejecución. Objetivo: entender cuándo usar cada API y qué objetos vive detrás.

## 1. Ingress clásico — qué materializa Google

Manifiesto:

```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: checkout-cert
  namespace: checkout
spec:
  domains:
    - checkout.example.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: checkout-ingress
  namespace: checkout
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: "checkout-cert"
    kubernetes.io/ingress.global-static-ip-name: "checkout-ip"
spec:
  rules:
    - host: checkout.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: checkout-svc
                port:
                  number: 80
```

Lo que Google crea bajo el capó:

- **Global HTTP(S) Load Balancer** anycast.
- **Forwarding rule** sobre la IP estática global `checkout-ip`.
- **Target HTTPS proxy** con el **SSL certificate** emitido por Google (ACME contra Let's Encrypt o el emisor interno de Google — verificar vigente).
- **URL map** con las rutas declaradas.
- **Backend service** apuntando al NEG (Network Endpoint Group) del `Service checkout-svc`.
- **Health check** sobre el puerto del backend.

El tiempo de materialización inicial es de **5–10 min**. La emisión del certificado managed puede tardar más (requiere que el DNS ya apunte a la IP).

## 2. Gateway API — qué materializa Google

Manifiesto (equivalente):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: checkout-gw
  namespace: checkout
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        options:
          networking.gke.io/pre-shared-certs: checkout-cert
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: checkout-route
  namespace: checkout
spec:
  parentRefs:
    - name: checkout-gw
  hostnames:
    - checkout.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: checkout-svc
          port: 80
```

Materializa **los mismos recursos** de Google Cloud Load Balancing bajo el capó, pero con una API más expresiva y vendor-neutral.

## 3. Tabla de GatewayClass disponibles (ejemplos típicos — verificar vigente)

| GatewayClass | Qué LB crea | Alcance |
|--------------|-------------|---------|
| `gke-l7-global-external-managed` | Global External HTTP(S) LB | Internet, anycast global |
| `gke-l7-regional-external-managed` | Regional External HTTP(S) LB | Internet, regional |
| `gke-l7-rilb` | Regional Internal HTTP(S) LB | VPC-interno |
| `gke-l7-gxlb-mc` | Multi-cluster Gateway | Fleet, varios clusters |

## 4. Diferencias prácticas: Ingress vs Gateway API

| Dimensión | Ingress (`networking.k8s.io/v1`) | Gateway API (`gateway.networking.k8s.io/v1`) |
|-----------|----------------------------------|---------------------------------------------|
| Multi-tenant | Pobre (cada Ingress tiende a su LB) | Bueno (`Gateway` compartido + `HTTPRoute` por tenant) |
| Separación de roles | Mezclada en un objeto | Separada: `Gateway` (infra) vs `HTTPRoute` (dev) |
| Splits por peso | Vía annotations propietarias de GCE | Nativo (`backendRefs.weight`) |
| Match por header | Vía annotations | Nativo (`matches.headers`) |
| Managed cert | `ManagedCertificate` + annotation | `pre-shared-certs` option o CertManager |
| Portabilidad | Mínima (annotations son GCE-specific) | Alta (API estándar; implementación es Google) |
| Estado | Soportado, mantenido | Recomendado para proyectos nuevos |

## 5. BackendConfig y FrontendConfig (solo Ingress clásico)

Settings extra para el LB se declaran con CRDs de Google:

```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: checkout-backend
  namespace: checkout
spec:
  timeoutSec: 30
  cdn:
    enabled: true
  securityPolicy:
    name: cloud-armor-policy-checkout
---
apiVersion: cloud.google.com/v1
kind: FrontendConfig
metadata:
  name: checkout-frontend
  namespace: checkout
spec:
  redirectToHttps:
    enabled: true
  sslPolicy: tls-1-2-modern
```

Se enlazan al `Service` del backend con annotations:

```yaml
metadata:
  annotations:
    cloud.google.com/backend-config: '{"default":"checkout-backend"}'
    cloud.google.com/neg: '{"ingress":true}'
```

En Gateway API, equivalentes se expresan con `GCPBackendPolicy` y `GCPGatewayPolicy` (CRDs del proveedor Google), que anotan `Gateway` y `HTTPRoute`.

## 6. Preguntas de autocomprobación

1. ¿Por qué el **certificado managed** tarda más que el resto del LB en estar listo?
2. En un cluster multi-tenant con 20 equipos, ¿por qué Gateway API escala mejor que Ingress clásico?
3. ¿Dónde se declara "redirect HTTP → HTTPS" en Ingress clásico? ¿Y en Gateway API?
4. ¿Qué pasa si borras el `Ingress` sin borrar primero el `ManagedCertificate`?
5. Si quieres **Cloud CDN** sobre tu Ingress, ¿qué objeto declaras y con qué annotation lo enlazas al `Service`?
