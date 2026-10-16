# Ejemplo 01 — Kubernetes plugin: configuración mínima

> Lectura y walkthrough. Sin ejecución obligatoria. Si tienes Backstage levantado localmente y acceso a un cluster, los fragmentos funcionan tal cual.

## 1. Qué resuelve el plugin

El plugin **Kubernetes** (`@backstage/plugin-kubernetes`) responde dentro de la `EntityPage` a la pregunta más frecuente del desarrollador:

> *"¿Mi servicio está corriendo? ¿Con qué imagen? ¿Cuántos pods? ¿Algún crash loop?"*

Antes del plugin, la respuesta vivía detrás de `kubectl get pods -n <ns> -l app=<svc>` o de un dashboard de Lens. Con el plugin, es un tab más del portal, con el mismo contexto de ownership que el catálogo ya conoce.

## 2. Las tres piezas que hay que tocar

```
┌───────────────────────────────┐    ┌────────────────────────────┐    ┌───────────────────────────┐
│ app-config.yaml               │    │ catalog-info.yaml (repo    │    │ packages/app/src/         │
│ (cluster + auth strategy)     │    │ del servicio: anotación)   │    │ EntityPage.tsx (tab)      │
└──────────────┬────────────────┘    └─────────────┬──────────────┘    └─────────────┬─────────────┘
               │                                   │                                 │
               └────────────────► plugin de Kubernetes ◄──────────────────────────────┘
                                       (frontend + backend)
```

Si **cualquiera** de las tres falta, el plugin "no muestra nada" **sin error visible**. Es el fallo nº 1 reportado en issues.

## 3. `app-config.yaml` (fragmento)

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - name: prod-eu
          url: https://kube.prod-eu.acme.internal
          authProvider: 'serviceAccount'
          serviceAccountToken: ${K8S_PROD_EU_TOKEN}
          skipTLSVerify: false
          caData: ${K8S_PROD_EU_CA}
        - name: stage-eu
          url: https://kube.stage-eu.acme.internal
          authProvider: 'serviceAccount'
          serviceAccountToken: ${K8S_STAGE_EU_TOKEN}
          caData: ${K8S_STAGE_EU_CA}
  customResources:
    - group: 'argoproj.io'
      apiVersion: 'v1alpha1'
      plural: 'rollouts'
```

Puntos:

- **`${K8S_PROD_EU_TOKEN}`** → nunca literal. Siempre env var del backend.
- **`serviceAccount`** con RBAC mínimo (`get`/`list`/`watch` sobre `pods`, `deployments`, `services`, `ingresses`). **No** `cluster-admin`.
- **`customResources`** amplía qué CRDs se muestran (ejemplo: Argo Rollouts).

## 4. `catalog-info.yaml` del servicio (fragmento)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  annotations:
    backstage.io/kubernetes-id: checkout-service
    # Opcional: refinar namespaces
    backstage.io/kubernetes-namespace: checkout
    # Opcional: filtrar por label-selector arbitrario
    # backstage.io/kubernetes-label-selector: 'app=checkout,component=api'
spec:
  type: service
  lifecycle: production
  owner: team-checkout
```

Y, el **error silencioso favorito**: el workload en el cluster debe llevar el label correspondiente.

```yaml
# deployment.yaml
metadata:
  labels:
    backstage.io/kubernetes-id: checkout-service
```

Si falta ese label, el plugin consulta al cluster, no encuentra workloads para `checkout-service` y muestra "No resources" **sin indicarte** que el problema está en el label.

## 5. `EntityPage.tsx` (fragmento)

```tsx
import { EntityKubernetesContent } from '@backstage/plugin-kubernetes';

const serviceEntityPage = (
  <EntityLayout>
    <EntityLayout.Route path="/" title="Overview">
      {overviewContent}
    </EntityLayout.Route>
    <EntityLayout.Route path="/kubernetes" title="Kubernetes">
      <EntityKubernetesContent refreshIntervalMs={30000} />
    </EntityLayout.Route>
  </EntityLayout>
);
```

Ese `<EntityLayout.Route>` es el tab que aparece en `/catalog/default/component/checkout-service/kubernetes`.

## 6. Qué comprobar si no aparece nada

Lista de verificación (en orden):

1. ¿El `authProvider` resuelve? `curl -k -H "Authorization: Bearer $K8S_PROD_EU_TOKEN" $URL/api/v1/namespaces`.
2. ¿La SA tiene RBAC para listar pods en el namespace?
3. ¿El workload lleva el label `backstage.io/kubernetes-id`?
4. ¿La anotación de la entidad coincide **exactamente** con el valor del label (case-sensitive)?
5. ¿Backend logs: `plugin:kubernetes` sin errores de connect/timeout?

## 7. Nada más por hoy

El plugin de Kubernetes es el primero que casi todo el mundo instala porque el retorno percibido es inmediato. Para los otros (GH Actions, Argo CD), el patrón es idéntico: **config + anotación + tab**. Sigue al ejemplo 02.
