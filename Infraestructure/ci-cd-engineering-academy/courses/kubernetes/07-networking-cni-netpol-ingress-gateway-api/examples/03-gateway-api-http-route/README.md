# Ejemplo 03 — Gateway API: GatewayClass / Gateway / HTTPRoute

## Concepto que demuestra

Instalar los **CRDs** de Gateway API y escribir los tres recursos tipados: `GatewayClass`, `Gateway`, `HTTPRoute`. Separación clara de roles (plataforma vs app).

Mantiene el ejemplo **ligero**: por default **no** instala un controller completo — solo valida que los CRDs están y que los manifiestos son aceptados por el API server. Si pasas `WITH_CONTROLLER=1`, instala **Envoy Gateway** y hace tráfico end-to-end.

## Objetivo

- Instalar los CRDs oficiales de Gateway API (standard channel).
- Definir `GatewayClass`, `Gateway`, `HTTPRoute` válidos.
- Entender cómo el `status` reporta `Accepted` / `Programmed` / `ResolvedRefs`.
- (Opcional) ver tráfico real con Envoy Gateway.

## Prerrequisitos

- `kind` y `kubectl` instalados.
- Docker corriendo.
- Para modo controller (`WITH_CONTROLLER=1`): puertos 80/8443 libres y Helm instalado.

## Archivo del ejemplo

`files/run-demo.sh`.

## Ejecución

```bash
# Solo CRDs + manifiestos:
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/examples/03-gateway-api-http-route/files/run-demo.sh

# Con Envoy Gateway real (requiere Helm):
WITH_CONTROLLER=1 bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/examples/03-gateway-api-http-route/files/run-demo.sh
```

El script (modo ligero):

1. Crea cluster `k8s07-gwapi` (si no existe).
2. Instala CRDs del standard channel de Gateway API (`v1.1.0`).
3. Aplica un `GatewayClass` apuntando a un controller "example" (no instala el controller — es ilustrativo).
4. Aplica un `Gateway` en namespace `gateway-system` y un `HTTPRoute` en namespace `app`.
5. Muestra `kubectl describe` y los `conditions` del status.

## Resultado esperado (modo ligero)

```
gatewayclasses.gateway.networking.k8s.io   OK (CRD instalada)
gateways.gateway.networking.k8s.io          OK (CRD instalada)
httproutes.gateway.networking.k8s.io        OK (CRD instalada)

GatewayClass/example  Accepted=Unknown (no controller present)
Gateway/eg            Accepted=Unknown
HTTPRoute/web         ParentRefs: eg (no se puede attach sin controller)
```

Esto es **lo esperado** sin controller — los manifiestos existen y son válidos; nadie los implementa.

## Interpretación

- Un **CRD** sin controller es solo almacenamiento estructurado. El tráfico necesita que alguien lea el objeto y actúe.
- Separación de roles:
  - `GatewayClass` → quien administra el cluster (plataforma).
  - `Gateway` → equipo de plataforma / networking.
  - `HTTPRoute` → equipo de la app, en su propio namespace, adjuntando al Gateway shared.
- Para producción se usa cert-manager + un controller completo + policies.

## Errores frecuentes

- "no matches for kind HTTPRoute": no instalaste los CRDs.
- "spec.parentRefs: forbidden": el `Gateway` referenciado no permite attaches desde ese namespace (`allowedRoutes.namespaces`).
- "no ready endpoints": falta el controller real.

## Limpieza

```bash
kind delete cluster --name k8s07-gwapi
```
