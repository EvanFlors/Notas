# TEMPLATE — plat-08-02-write-minimal-custom-plugin

> Plantilla **modelo** del plugin `service-health`. No es la única forma correcta; es un esqueleto defendible que valida el ejercicio.

## Estructura

```
/tmp/plat-08-plugin/
├── package.json
├── README.md
├── TEMPLATE.md               ← este archivo
└── src/
    ├── index.ts
    ├── plugin.ts
    ├── routes.ts
    └── components/
        └── ServiceHealthCard/
            ├── ServiceHealthCard.tsx
            └── index.ts
```

## Enganche en `packages/app/src/App.tsx` del workspace Backstage

```tsx
import { ServiceHealthPage } from '@internal/plugin-service-health';

// Dentro de <FlatRoutes>:
<Route path="/service-health" element={<ServiceHealthPage />} />
```

Y en el sidebar (`packages/app/src/components/Root/Root.tsx`):

```tsx
import HeartIcon from '@material-ui/icons/Favorite';
// ...
<SidebarItem icon={HeartIcon} to="service-health" text="Health" />
```

## Decisión: backend propio vs `proxy.endpoints`

Para `service-health` la decisión depende de qué API se consulte:

- **Opción A (barata) — `proxy.endpoints`:** si el servicio de health interno expone HTTP con un token de servicio, basta con:

  ```yaml
  # app-config.yaml
  proxy:
    endpoints:
      '/service-health':
        target: https://health.acme.internal
        headers:
          Authorization: Bearer ${SERVICE_HEALTH_TOKEN}
  ```

  Y desde el componente: `fetch('/api/proxy/service-health/status/<component>')`.

- **Opción B — plugin backend propio:** si necesitas agregar varias fuentes, cachear, o aplicar lógica de negocio. Entonces en el frontend:

  ```ts
  const baseUrl = await discoveryApi.getBaseUrl('service-health');
  const res = await fetchApi.fetch(`${baseUrl}/status/${component}`);
  ```

**Elección modelo:** empezar por A. Promover a B solo cuando aparece una de las tres razones (agregación, cache, lógica).

## Checklist mínimo del esqueleto

- [x] `package.json` con `backstage.role = frontend-plugin`.
- [x] `react` en `peerDependencies`.
- [x] `src/plugin.ts` usa `createPlugin` + `createRoutableExtension`.
- [x] `src/routes.ts` crea `rootRouteRef` con `createRouteRef`.
- [x] Componente usa `Page`, `Header`, `Content` de `@backstage/core-components`.
- [x] `src/index.ts` exporta `serviceHealthPlugin` y `ServiceHealthPage`.
