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
      import('./components/ServiceHealthCard').then(m => m.ServiceHealthCard),
    mountPoint: rootRouteRef,
  }),
);
