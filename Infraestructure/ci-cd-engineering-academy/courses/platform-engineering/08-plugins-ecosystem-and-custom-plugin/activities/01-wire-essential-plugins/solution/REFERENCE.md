# REFERENCE — plat-08-01-wire-essential-plugins

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Elección y justificación (modelo)

**Top 3**, por orden de instalación:

1. **Kubernetes** (`@backstage/plugin-kubernetes`). Resuelve *"¿mi servicio está corriendo?"*. Es la pregunta que developers ya se hacen 10 veces al día y hoy responden con `kubectl` a ciegas. Retorno percibido inmediato en la primera visita al portal.
2. **GitHub Actions** (`@backstage-community/plugin-github-actions`). Resuelve *"¿pasó el último build?"*. Trae al portal el único feedback de CI que developers ya respetaban (el badge del README). Barato de instalar porque el `integrations.github` suele existir ya para catalog discovery.
3. **Argo CD** (`@roadiehq/backstage-plugin-argo-cd`). Resuelve *"¿la última commit está en producción?"*. Cierra el loop deploy ↔ catálogo. Lo pongo tercero porque muchas orgs aún no usan Argo CD en todos los servicios; si en la tuya no está, cámbialo por **PagerDuty** (*"¿quién está de guardia?"*).

Alternativas defendibles: `pagerduty`, `grafana`, `tech-insights`. Evito `cost-insights` como top-3 porque requiere un adaptador cloud propio y el ROI inicial es menor.

## Sección B — Configuración (`app-config.yaml`) (modelo)

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
          caData: ${K8S_PROD_EU_CA}
```

```yaml
integrations:
  github:
    - host: github.com
      apps:
        - $include: github-app-credentials.yaml
```

```yaml
# Argo CD vía proxy (patrón Roadie)
proxy:
  endpoints:
    '/argocd/api':
      target: https://argocd.acme.internal/api/v1/
      changeOrigin: true
      headers:
        Cookie: ${ARGOCD_AUTH_TOKEN}

argocd:
  username: ${ARGOCD_USERNAME}
  password: ${ARGOCD_PASSWORD}
  appLocatorMethods:
    - type: 'config'
      instances:
        - name: argoInstance1
          url: https://argocd.acme.internal
```

## Sección C — Anotaciones (`catalog-info.yaml`) (modelo)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  annotations:
    backstage.io/kubernetes-id: checkout-service
    backstage.io/kubernetes-namespace: checkout
    github.com/project-slug: acme/checkout-service
    argocd/app-name: checkout-service-prod
spec:
  type: service
  lifecycle: production
  owner: team-checkout
```

## Sección D — `EntityPage.tsx` (modelo)

```tsx
import { EntityKubernetesContent } from '@backstage/plugin-kubernetes';
import {
  EntityGithubActionsContent,
  isGithubActionsAvailable,
} from '@backstage-community/plugin-github-actions';
import {
  EntityArgoCDOverviewCard,
  isArgocdAvailable,
} from '@roadiehq/backstage-plugin-argo-cd';

const serviceEntityPage = (
  <EntityLayout>
    <EntityLayout.Route path="/kubernetes" title="Kubernetes">
      <EntityKubernetesContent refreshIntervalMs={30000} />
    </EntityLayout.Route>
    <EntityLayout.Route path="/ci-cd" title="CI/CD" if={isGithubActionsAvailable}>
      <EntityGithubActionsContent />
    </EntityLayout.Route>
    <EntityLayout.Route path="/argocd" title="Argo CD" if={isArgocdAvailable}>
      <EntityArgoCDOverviewCard />
    </EntityLayout.Route>
  </EntityLayout>
);
```

## Sección E — Decisión de auth (modelo)

| Plugin | Modo de auth | Por qué |
|--------|--------------|---------|
| Kubernetes | `service-account` | El cluster no soporta OAuth del usuario; necesitamos una SA con RBAC mínimo (`get`/`list` sobre pods/deployments). |
| GitHub Actions | `github-app` | GitHub App instalado en la org da tokens efímeros con permisos finos; el PEM nunca llega al navegador y la rotación la gestiona GitHub. |
| Argo CD | `proxy-token` | Argo CD expone API HTTP con cookie session; el patrón `proxy.endpoints` inyecta el token del backend sin exponerlo al cliente. `discoveryApi` no aplica porque usamos proxy genérico, no plugin backend propio. |

## Sección F (opcional) — Verificación post-instalación

1. `curl -k -H "Authorization: Bearer $K8S_PROD_EU_TOKEN" $K8S_URL/api/v1/namespaces` → 200.
2. Visitar `/catalog/default/component/<svc>/kubernetes` → ver al menos 1 pod listado.
3. Visitar `/ci-cd` → ver último workflow run.
4. Visitar `/argocd` → ver estado `Synced / Healthy`.
5. Backend logs: sin errores de `plugin:kubernetes`, `plugin:github-actions`, `plugin:argo-cd`.
