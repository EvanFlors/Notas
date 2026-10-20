# Ejemplo 03 — Anatomía de un plugin propio generado por `backstage-cli`

> Lectura y walkthrough. Documenta el **output** real de `yarn new --select plugin` para que puedas reconocer cada archivo cuando lo veas en tu workspace.

## 1. Cómo se genera

Desde la raíz de un workspace Backstage (creado con `npx @backstage/create-app`):

```bash
yarn new --select plugin
# Enter plugin ID: service-health
```

Resultado:

```
plugins/service-health/
├── README.md
├── package.json
├── tsconfig.json
├── dev/
│   └── index.tsx
├── src/
│   ├── index.ts
│   ├── plugin.ts
│   ├── routes.ts
│   ├── setupTests.ts
│   └── components/
│       └── ExampleComponent/
│           ├── ExampleComponent.tsx
│           ├── ExampleFetchComponent.tsx
│           └── index.ts
└── tests/
```

El CLI resuelve **automáticamente** las versiones de `@backstage/core-plugin-api`, `@backstage/core-components`, `react`, etc. para que **coincidan** con el core del workspace. Nunca editarlas a mano.

## 2. `package.json` esencial

```json
{
  "name": "@internal/plugin-service-health",
  "version": "0.1.0",
  "main": "src/index.ts",
  "types": "src/index.ts",
  "license": "Apache-2.0",
  "backstage": {
    "role": "frontend-plugin",
    "pluginId": "service-health",
    "pluginPackages": ["@internal/plugin-service-health"]
  },
  "scripts": {
    "start": "backstage-cli package start",
    "build": "backstage-cli package build",
    "lint": "backstage-cli package lint",
    "test": "backstage-cli package test",
    "clean": "backstage-cli package clean"
  },
  "dependencies": {
    "@backstage/core-components": "^0.17.0",
    "@backstage/core-plugin-api": "^1.10.0",
    "@backstage/theme": "^0.6.0",
    "@material-ui/core": "^4.12.4",
    "@material-ui/icons": "^4.11.3",
    "react-use": "^17.4.0"
  },
  "peerDependencies": {
    "react": "^17 || ^18"
  },
  "devDependencies": {
    "@backstage/cli": "^0.30.0",
    "@backstage/core-app-api": "^1.15.0",
    "@backstage/test-utils": "^1.7.0",
    "@testing-library/jest-dom": "^6.4.2",
    "@testing-library/react": "^14.2.0",
    "@types/node": "^20.0.0",
    "msw": "^1.3.3"
  },
  "files": ["dist"]
}
```

Observa:

- **`"role": "frontend-plugin"`** declara el tipo de package al `backstage-cli`.
- **`react` en `peerDependencies`**: evita múltiples copias de React en runtime (el error "Invalid hook call" clásico).
- **`"main": "src/index.ts"`** durante dev; el build genera `dist/`.

## 3. `src/plugin.ts`

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

## 4. `src/components/ExampleComponent/ExampleComponent.tsx` (resumen)

```tsx
import React from 'react';
import { Content, Header, Page } from '@backstage/core-components';

export const ExampleComponent = () => (
  <Page themeId="tool">
    <Header title="Service Health" subtitle="Ejemplo de plugin propio" />
    <Content>
      <p>Reemplazar por el componente real que llame a tu backend / proxy.</p>
    </Content>
  </Page>
);
```

Tipado React + componentes **oficiales de Backstage** (`Page`, `Header`, `Content`) para heredar look & feel, dark mode, breakpoints, etc.

## 5. `src/index.ts`

```ts
export { serviceHealthPlugin, ServiceHealthPage } from './plugin';
```

Es la **única superficie pública** del plugin. Todo lo que no se exporte aquí, no existe para los consumidores.

## 6. Enganche en `packages/app/src/App.tsx`

```tsx
import { ServiceHealthPage } from '@internal/plugin-service-health';
// ...
<Route path="/service-health" element={<ServiceHealthPage />} />
```

Y en `packages/app/src/components/Root/Root.tsx` un `SidebarItem` apuntando a `/service-health` si quieres entrada en el sidebar.

## 7. Qué **no** incluye el boilerplate (y hay que añadir)

- **API cliente** (`src/api/`): si llamas a tu backend plugin o al proxy.
- **`createApiFactory`** en el registro de APIs (`App.tsx`): para que `discoveryApi` + `fetchApi` lleguen al cliente.
- **`EntityServiceHealthContent`**: si quieres aparecer como tab dentro de `EntityPage` en vez de página standalone.

Esos son los pasos que `yarn new` **no** sabe inferir porque dependen de tu intención. La actividad 02 pide producir el esqueleto generado + al menos **un** archivo adicional (`src/api/types.ts`) para ejercitar la decisión.
