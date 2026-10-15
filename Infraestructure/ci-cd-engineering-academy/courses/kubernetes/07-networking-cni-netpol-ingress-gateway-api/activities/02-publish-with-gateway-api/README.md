# Actividad 02 — Publicar una app con Gateway API (manifiestos)

## 1. Identificación

- **ID:** `k8s-07-02-publish-with-gateway-api`
- **Tecnología:** `kubernetes`
- **Módulo:** `07-networking-cni-netpol-ingress-gateway-api`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Vas a publicar la app `shop-web` del namespace `app` usando **Gateway API** con separación de responsabilidades:

- **Plataforma** administra un `GatewayClass` + un `Gateway` compartido en el namespace `gateway-system` escuchando en el puerto 80.
- **Equipo de la app** define un `HTTPRoute` en el namespace `app` que:
  - Se adjunta al Gateway `shared` del namespace `gateway-system`.
  - Hostname: `shop.example.local`.
  - Dos reglas con path matching:
    - `PathPrefix /api` → Service `shop-api:8080`
    - `PathPrefix /`    → Service `shop-web:80`
  - Incluye un filtro `RequestHeaderModifier` que agrega `X-Route-By: gateway-api` a toda request.

El bootstrap deja todo lo necesario **menos** los recursos Gateway API: tú los escribes. **Esta actividad valida los manifiestos** (schema del API + estructura + status conditions) **sin requerir tráfico real** (porque un controller en kind es pesado y variable).

## 3. Objetivos

- Instalar los CRDs de Gateway API en un cluster kind.
- Escribir y aplicar `GatewayClass`, `Gateway` y `HTTPRoute` válidos (los acepta el API server).
- Entender `allowedRoutes.namespaces` y por qué un `HTTPRoute` en `app` necesita permiso del `Gateway` para adjuntarse.
- Agregar un filtro `RequestHeaderModifier`.

## 4. Prerrequisitos

- `kind`, `kubectl` instalados.
- `docker` corriendo.
- Puertos: ninguno externo (la actividad valida manifiestos, no tráfico).

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/02-publish-with-gateway-api/starter/bootstrap.sh
```

Esto crea el cluster `k8s07-act2`, instala los **CRDs** de Gateway API (`v1.1.0`), crea namespaces `gateway-system` y `app`, y despliega los Services `shop-web` y `shop-api`. Deja plantillas en `/tmp/k8s07-act2/manifests/`:

- `10-gatewayclass.yaml`
- `20-gateway.yaml`
- `30-httproute.yaml`

### 5.2 Escribe los manifiestos

Pistas de **cada archivo** (están también en los TODO del YAML):

- **`GatewayClass`** (cluster-scoped):
  - name: `example`
  - `spec.controllerName`: `example.com/not-installed` (texto libre; no hace falta controller real).
- **`Gateway`** (namespace `gateway-system`):
  - name: `shared`
  - `gatewayClassName: example`
  - un `listener`:
    - name: `http`, protocol: `HTTP`, port: `80`.
    - `allowedRoutes.namespaces.from: Selector` + `selector.matchLabels.gateway-access: "yes"` (así solo namespaces etiquetados pueden adjuntar).
- **`HTTPRoute`** (namespace `app`):
  - name: `shop`
  - `parentRefs`: `[ { name: shared, namespace: gateway-system } ]`
  - `hostnames: ["shop.example.local"]`
  - 2 reglas:
    - matches path PathPrefix `/api` → backendRef `shop-api` port 8080.
    - matches path PathPrefix `/`    → backendRef `shop-web` port 80.
  - filtro de tipo `RequestHeaderModifier` en al menos una regla, que `add` el header `X-Route-By: gateway-api`.

**IMPORTANTE**: para que el `HTTPRoute` tenga permiso de adjuntarse al Gateway `shared`, tienes que **etiquetar** el namespace `app` con `gateway-access=yes`:

```bash
kubectl label namespace app gateway-access=yes --overwrite
```

Aplica tus manifiestos:

```bash
kubectl apply -f /tmp/k8s07-act2/manifests/
```

### 5.3 Verifica a ojo

```bash
kubectl get gatewayclass
kubectl -n gateway-system describe gateway shared
kubectl -n app describe httproute shop
```

Mira la sección `Status` del HTTPRoute: debe haber `parents[0].parentRef` apuntando a `shared/gateway-system`. Como no hay controller real, verás `Accepted=Unknown` o condiciones vacías — eso es esperado.

### 5.4 Valida

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/02-publish-with-gateway-api/tests/validate.sh
```

El validador comprueba:

- CRDs instaladas.
- Los 3 recursos presentes con los nombres correctos.
- Campos clave (listener puerto 80 HTTP, allowedRoutes Selector, hostnames, dos reglas con PathPrefix `/api` y `/`, filtro `RequestHeaderModifier` con `X-Route-By: gateway-api`).
- Namespace `app` etiquetado con `gateway-access=yes`.

## 6. Resultado esperado

- `GatewayClass/example`, `Gateway/shared` (ns gateway-system), `HTTPRoute/shop` (ns app) existen.
- Validator reporta `RESULT: N/N checks OK.`.

## 7. Criterios de aceptación

- [ ] CRDs Gateway API instaladas.
- [ ] GatewayClass con el nombre pedido.
- [ ] Gateway en `gateway-system` con listener HTTP:80 y `allowedRoutes: Selector`.
- [ ] HTTPRoute en `app` con hostnames correctos, 2 reglas con PathPrefix esperados, filtro `RequestHeaderModifier` con el header.
- [ ] Namespace `app` etiquetado.

## 8. Validación

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/02-publish-with-gateway-api/tests/validate.sh
```

Si falta `kind`/`kubectl`/`docker` → `SKIP` con exit 0.

## 9. Preguntas de reflexión

1. ¿Por qué no basta con que el `HTTPRoute` apunte al `Gateway`? ¿Qué papel juega `allowedRoutes.namespaces`?
2. ¿Qué dos cosas gana la separación `Gateway` ↔ `HTTPRoute` frente a un único `Ingress` por app?
3. Si quisieras **TLS**, ¿qué cambia en el `Gateway`? ¿Qué recurso extra necesitas?
4. ¿Qué estrategia usarías para **canary release** entre dos versiones del backend con Gateway API?
5. ¿Qué controller elegirías para producción y por qué (Envoy Gateway, Istio Gateway, Contour, Cilium Gateway API)?

## 10. Extensiones

- **E1** — Añade un segundo HTTPRoute en el mismo namespace `app` para `otra-ruta.example.local`.
- **E2** — Reconfigura para usar `TLS` en el listener (necesitas un Secret TLS; cert autofirmado).
- **E3** — Instala **Envoy Gateway** real (ver ejemplo 03 con `WITH_CONTROLLER=1`) y verifica tráfico `curl` end-to-end.

## 11. Limpieza

```bash
kind delete cluster --name k8s07-act2
rm -rf /tmp/k8s07-act2
```
