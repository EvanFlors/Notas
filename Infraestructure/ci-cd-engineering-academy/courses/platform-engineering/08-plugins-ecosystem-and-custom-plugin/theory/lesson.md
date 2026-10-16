# plat-08 — Lección: ecosistema de plugins y plugin propio

> 11 secciones. Mayoritariamente conceptual + walkthrough. Prerrequisito: `plat-04` y `plat-05`.

---

## 1. Por qué un Backstage sin plugins es un "wiki tipado"

Un Backstage recién instalado con solo el `catalog` plugin te da esto: una **lista** de componentes, APIs, resources y systems, con un modelo de ownership. Útil, pero **estático**. No sabe si tu `Component` está deployado, no sabe si su último build pasó, no sabe si hay una alerta activa, no sabe cuánto cuesta correrlo.

Los **plugins** son la capa que convierte ese inventario estático en un **portal operativo**: cada tab de `EntityPage` suma una fuente de verdad externa (K8s, GHA, Argo CD, PagerDuty, Grafana, Datadog, Sentry…) **sin obligar al developer a cambiar de pestaña**.

> **Idea clave:** el valor de Backstage es **lineal con el número de plugins integrados**, hasta un punto. Sin plugins, Backstage es un wiki tipado. Con 10+ plugins mal mantenidos, es una pesadilla de upgrade. El sweet spot inicial son **3–5 plugins** bien configurados.

---

## 2. El patrón universal: anotación en `catalog-info.yaml`

Casi todos los plugins oficiales descubren datos externos por **anotaciones** en la entidad del catálogo. Es el acoplamiento más barato:

```yaml
# catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  annotations:
    github.com/project-slug: acme/checkout-service        # GH Actions plugin
    backstage.io/kubernetes-id: checkout-service          # K8s plugin
    argocd/app-name: checkout-service-prod                # Argo CD plugin
    pagerduty.com/integration-key: ${PD_INTEGRATION_KEY}  # PagerDuty plugin
    grafana/dashboard-selector: "folderTitle='Checkout'"  # Grafana plugin
spec:
  type: service
  lifecycle: production
  owner: team-checkout
```

Esto te da trazabilidad **sin tocar código del servicio**: la relación `componente ↔ workloads K8s ↔ workflows CI ↔ Argo app ↔ oncall ↔ dashboards` vive **en el repo del servicio**, versionada, revisable por PR.

---

## 3. Los plugins oficiales que más retorno dan (y en qué orden)

Orden empírico, defendible:

1. **Kubernetes** (`@backstage/plugin-kubernetes`): "¿está mi servicio corriendo? ¿cuántos pods? ¿con qué imagen?". Elimina el 80 % del `kubectl get pods` que developers hacen a ciegas.
2. **GitHub Actions** (`@backstage/plugin-github-actions`): "¿pasó el último build?". Convierte el badge perdido en el README en un tab en el portal.
3. **Argo CD** (`@roadiehq/backstage-plugin-argo-cd`): "¿la última commit está en producción?". Cierra el loop deploy ↔ catálogo.
4. **PagerDuty / Opsgenie** (`@pagerduty/backstage-plugin`): "¿quién está de guardia ahora?". Vital para incidentes.
5. **Grafana** (`@k-phoen/backstage-plugin-grafana`): dashboards embebidos como tab.
6. **Cost Insights** (`@backstage/plugin-cost-insights`): visibilidad de gasto por `Component` (requiere adaptador propio al cloud).
7. **TechInsights** (`@backstage-community/plugin-tech-insights`): base para scorecards de `plat-10`.
8. **Catalog Graph** (`@backstage/plugin-catalog-graph`): ya suele venir, visualiza relaciones.

Comunitarios: **Sentry**, **Datadog**, **SonarQube**, **Snyk**, **Vault**. Útiles si tu stack los tiene; evita instalarlos "por si acaso".

**Regla de oro:** instala un plugin solo si tienes un sistema real detrás que ya se consulta a diario. Instalar un plugin de Argo CD cuando no usas Argo CD es ruido.

---

## 4. Plugin frontend-only vs frontend + backend vs proxy-only

Tres topologías. Hay que entenderlas antes de decidir cómo integrar un plugin propio.

### 4.1 Frontend-only

El plugin vive **solo** en el bundle del navegador. Llama al API externa directamente (p. ej. GitHub con el token del usuario autenticado vía OAuth).

- **Cuándo:** la API externa soporta CORS, autentica al **usuario**, y no requiere secretos de servicio.
- **Riesgo:** cualquier secret que pongas en `app-config.yaml` **llegará al navegador**. No es un sitio para API keys.

### 4.2 Proxy-only (sin plugin backend propio)

Backstage trae un `proxy-backend` genérico. Configuras `proxy.endpoints` en `app-config.yaml` y el frontend llama a `/api/proxy/<path>`. El backend reenvía al sistema externo inyectando headers (token) desde `${ENV_VAR}` que **sí** vive en el servidor.

```yaml
# app-config.yaml
proxy:
  endpoints:
    '/pagerduty':
      target: https://api.pagerduty.com
      headers:
        Authorization: Token token=${PAGERDUTY_TOKEN}
```

- **Cuándo:** el plugin solo necesita hacer `GET`/`POST` a una API con un token de servicio y mostrar el resultado.
- **Es el patrón más barato.** Mucho código de plugin propio puede evitarse así.

### 4.3 Frontend + backend propio

El plugin trae un **backend module** (`@backstage/backend-plugin-api`) que corre dentro del `backend` de Backstage. El frontend lo descubre con `discoveryApi.getBaseUrl('<plugin-id>')`.

- **Cuándo:** necesitas agregar datos de **varios** sistemas, cachear, aplicar reglas de negocio, o emitir eventos. También si el proxy genérico no cubre tu caso (p. ej. firma de requests, paginación compleja).
- **Coste:** más código, más tests, más superficie de upgrade.

> **Heurística:** empieza por **proxy-only**. Promueve a plugin backend solo cuando el proxy ya no basta.

---

## 5. Scaffolding con `backstage-cli`

El flujo canónico (desde la raíz de un workspace Backstage ya creado con `npx @backstage/create-app`):

```bash
# Frontend plugin
yarn new --select plugin
# Pregunta: id del plugin → 'service-health'
# Genera: plugins/service-health/

# Backend plugin (opcional, si lo necesitas)
yarn new --select backend-plugin
# Genera: plugins/service-health-backend/
```

Lo que te crea (frontend):

```
plugins/service-health/
├── package.json
├── README.md
├── src/
│   ├── index.ts            # export público
│   ├── plugin.ts           # createPlugin + routable extension
│   ├── routes.ts
│   ├── components/
│   │   └── ExampleComponent/
│   │       ├── ExampleComponent.tsx
│   │       └── index.ts
│   └── setupTests.ts
├── dev/
│   └── index.tsx           # app standalone para dev
└── tsconfig.json
```

El `yarn new` resuelve correctamente la versión de todos los `@backstage/*` según la versión del core del workspace. Esto es importante: **nunca** mezcles versiones de core manualmente.

---

## 6. Anatomía mínima de `src/plugin.ts`

```ts
import {
  createPlugin,
  createRoutableExtension,
} from '@backstage/core-plugin-api';

import { rootRouteRef } from './routes';

export const serviceHealthPlugin = createPlugin({
  id: 'service-health',
  routes: {
    root: rootRouteRef,
  },
});

export const ServiceHealthPage = serviceHealthPlugin.provide(
  createRoutableExtension({
    name: 'ServiceHealthPage',
    component: () =>
      import('./components/ExampleComponent').then(m => m.ExampleComponent),
    mountPoint: rootRouteRef,
  }),
);
```

Tres piezas:

- **`createPlugin`** registra el plugin con un `id` único.
- **`createRoutableExtension`** expone un **componente página** que la app principal monta en una ruta (`/service-health`).
- **`rootRouteRef`** es la referencia estable que la app usa para enlazar.

El plugin se registra desde `packages/app/src/App.tsx`:

```tsx
import { ServiceHealthPage } from '@internal/plugin-service-health';
// ...
<Route path="/service-health" element={<ServiceHealthPage />} />
```

Para que aparezca como **tab** dentro de `EntityPage` necesitas un `EntityServiceHealthContent` adicional (`createRoutableExtension` + condición sobre `isKind('component')`).

---

## 7. Consumo de APIs externas: `discoveryApi` + fetchApi

El patrón canónico para llamar a tu backend plugin (o al proxy) desde el frontend:

```ts
import { createApiRef, DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

export const serviceHealthApiRef = createApiRef<ServiceHealthApi>({
  id: 'plugin.service-health.service',
});

export class ServiceHealthClient implements ServiceHealthApi {
  constructor(
    private readonly discoveryApi: DiscoveryApi,
    private readonly fetchApi: FetchApi,
  ) {}

  async getHealth(componentName: string) {
    const baseUrl = await this.discoveryApi.getBaseUrl('service-health');
    const res = await this.fetchApi.fetch(`${baseUrl}/health/${componentName}`);
    if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
    return res.json();
  }
}
```

Clave: **el navegador nunca conoce la URL interna** del backend. Pregunta a `discoveryApi` y recibe algo como `http://localhost:7007/api/service-health` (dev) o `https://backstage.acme.internal/api/service-health` (prod). Esto hace el plugin **portable** entre entornos sin tocar código.

---

## 8. Versionado y distribución de plugins internos

Dos escenarios:

### 8.1 Plugin interno dentro del mismo workspace

Es el default del `yarn new`: queda en `plugins/<name>/` del workspace y se consume con workspace resolution (`@internal/plugin-<name>`). Fácil, pero no se puede compartir entre workspaces.

### 8.2 Plugin interno distribuido vía npm private registry

Para multi-workspace (p. ej. varias instancias de Backstage internas, o compartir con otros equipos):

- Publica como `@acme/plugin-<name>` en un **registro privado** (Verdaccio, GitHub Packages, Artifactory).
- Pinea el rango de versiones del core de Backstage que soportas en `peerDependencies`.
- CI del plugin: `yarn tsc && yarn test && yarn build && yarn pack`.
- Semver estricto: romper la API del plugin = **major** bump.

Antipatrón: copiar el plugin a mano entre workspaces. Diverge en días.

---

## 9. El ciclo de upgrade: por qué quedarte atrás **duele**

Backstage libera versión del core **cada semana** y mantiene una ventana corta de compatibilidad. Los plugins oficiales siguen esa cadencia.

El flujo canónico:

```bash
yarn backstage-cli versions:bump
yarn install
yarn tsc
yarn test
```

`versions:bump` alinea **todos** los `@backstage/*` del workspace a la última versión compatible. Si lo corres cada 2–4 semanas, el delta es trivial. Si lo corres cada 6 meses, acumulas:

- Deprecations que ya se eliminaron.
- Breaking changes en el **New Backend System** (los plugins backend tienen una migración activa desde `createRouter` legacy a `createBackendModule`).
- Plugins de terceros que ya solo soportan el core nuevo.

> **Regla:** incluye `versions:bump` en el **sprint cycle** del equipo de plataforma. No lo trates como "tarea de limpieza".

Para plugins propios: cada vez que haces `versions:bump`, el plugin propio debe seguir compilando y pasar sus tests. Si no, se vuelve lastre.

---

## 10. Antipatterns y errores comunes

- **Instalar plugin "por si acaso"**: cada plugin es un acoplamiento a una fuente externa. Instala solo si vas a configurarlo bien y a mantenerlo.
- **Secretos en `app-config.yaml` sin `${ENV_VAR}`**: ese fichero se **envía al cliente** en partes; cualquier string literal termina en el bundle. Usa siempre `${...}` y `app-config.production.yaml` con `.includeIf`.
- **Anotaciones de catálogo mal escritas**: `backstage.io/kubernetes-id` sin label `backstage.io/kubernetes-id=<valor>` en el workload K8s → plugin no muestra nada. El error silencioso favorito.
- **Plugin backend que esquiva `discoveryApi`**: hardcoding de `http://localhost:7007/...` en el frontend. Rompe en el primer deploy.
- **No usar `peerDependencies`**: el plugin resuelve su propia copia de `@backstage/core-plugin-api` y rompe el context de React en runtime. Deben ir en `peerDependencies`, no en `dependencies`.
- **Fork de plugin oficial para añadir una Card**: 99 % de las veces se arregla con composición en el frontend (envolver el componente oficial). Forkear es la última opción.

---

## 11. Resumen operativo

- Plugins = **capa de contexto** sobre el catálogo. Sin ellos, Backstage es un wiki tipado.
- Patrón universal: **anotación en `catalog-info.yaml`** descubre recursos externos.
- Orden de instalación defendible: **K8s → GH Actions → Argo CD** (los 3 que tocan "¿funciona?", "¿compila?", "¿deployó?").
- Tres topologías de plugin: **frontend-only**, **proxy-only**, **frontend + backend**. Empieza por proxy; promueve si no basta.
- Scaffolding: `yarn new --select plugin` (nunca copiar a mano).
- `discoveryApi` evita que el navegador conozca URLs internas.
- **Upgrade cada 2–4 semanas** con `backstage-cli versions:bump`. Dejarlo acumular tiene coste cuadrático.
