# Ejemplo 03 — Backend System 1.0: `createBackend`, features, módulos

> Lectura y análisis. El patrón nuevo que reemplazó el `backend.ts` imperativo histórico.

## 1. Antes vs después

### Patrón legacy (hasta ~2023)

`packages/backend/src/index.ts` era un script de 300 líneas:

```typescript
// LEGACY — no uses esto en nuevos proyectos
const app = express();
const envRouter = PromiseRouter();
app.use('/api/catalog', await catalog(/* deps a mano */));
app.use('/api/scaffolder', await scaffolder(/* deps */));
app.use('/api/auth', await auth(/* deps */));
// ... 20 plugins mas, cada uno con su createRouter
app.listen(7007);
```

Problemas: añadir un plugin tocaba `index.ts`, `plugins/<name>.ts` (archivo de registro) y a veces `package.json`. Reordenar dependencias era frágil. Testear plugins aislados era imposible sin arrancar todo.

### Patrón nuevo — Backend System 1.0

```typescript
// packages/backend/src/index.ts
import { createBackend } from '@backstage/backend-defaults';

const backend = createBackend();

// Nucleos
backend.add(import('@backstage/plugin-app-backend/alpha'));
backend.add(import('@backstage/plugin-proxy-backend/alpha'));

// Auth
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-guest-provider'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));

// Catalog
backend.add(import('@backstage/plugin-catalog-backend/alpha'));
backend.add(
  import('@backstage/plugin-catalog-backend-module-github/alpha'),
);
backend.add(
  import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'),
);

// Scaffolder, TechDocs
backend.add(import('@backstage/plugin-scaffolder-backend/alpha'));
backend.add(
  import('@backstage/plugin-scaffolder-backend-module-github/alpha'),
);
backend.add(import('@backstage/plugin-techdocs-backend/alpha'));

// Permissions
backend.add(import('@backstage/plugin-permission-backend/alpha'));
backend.add(
  import('@backstage/plugin-permission-backend-module-allow-all-policy'),
);

// Search
backend.add(import('@backstage/plugin-search-backend/alpha'));
backend.add(import('@backstage/plugin-search-backend-module-pg/alpha'));
backend.add(import('@backstage/plugin-search-backend-module-catalog/alpha'));
backend.add(import('@backstage/plugin-search-backend-module-techdocs/alpha'));

backend.start();
```

Cada `backend.add(...)` carga una **feature** autodescriptiva. El framework:

1. Resuelve el DAG de dependencias entre features.
2. Instancia los servicios core (`logger`, `config`, `database`, `httpRouter`, `scheduler`, ...).
3. Inicializa cada feature en orden topológico, inyectando lo que pide.
4. Arranca el server.

## 2. Servicios core inyectables

Todas las features declaran qué servicios necesitan vía `deps`:

| Servicio | Para qué |
|----------|----------|
| `coreServices.logger` | logging estructurado |
| `coreServices.config` | lectura del `app-config` merged |
| `coreServices.database` | handle Knex a Postgres/SQLite |
| `coreServices.httpRouter` | registrar rutas HTTP |
| `coreServices.scheduler` | tareas periódicas (cron) |
| `coreServices.auth` | tokens entre backend plugins |
| `coreServices.discovery` | localizar otros backends |
| `coreServices.permissions` | consultar policy |
| `coreServices.cache` | KV in-memory o Redis |
| `coreServices.lifecycle` | hooks de shutdown graceful |

## 3. Crear un módulo custom

Caso típico: añadir un procesador propio al catálogo (p. ej. un provider que lee entidades desde una API interna).

```typescript
// plugins/catalog-backend-module-my-provider/src/module.ts
import {
  createBackendModule,
  coreServices,
} from '@backstage/backend-plugin-api';
import { catalogProcessingExtensionPoint } from '@backstage/plugin-catalog-node/alpha';
import { MyEntityProvider } from './MyEntityProvider';

export const catalogModuleMyProvider = createBackendModule({
  pluginId: 'catalog',
  moduleId: 'my-provider',
  register(env) {
    env.registerInit({
      deps: {
        catalog: catalogProcessingExtensionPoint,
        logger: coreServices.logger,
        config: coreServices.config,
        scheduler: coreServices.scheduler,
      },
      async init({ catalog, logger, config, scheduler }) {
        const provider = new MyEntityProvider({ logger, config });

        catalog.addEntityProvider(provider);

        await scheduler.scheduleTask({
          id: 'my-provider-refresh',
          frequency: { minutes: 10 },
          timeout: { minutes: 2 },
          fn: () => provider.refresh(),
        });
      },
    });
  },
});
```

Y en `packages/backend/src/index.ts`:

```typescript
backend.add(import('@internal/plugin-catalog-backend-module-my-provider'));
```

## 4. Extension points — contratos entre plugins

Un plugin oficial expone **extension points** (interfaces TS) que los módulos pueden implementar. Ejemplos:

- `catalogProcessingExtensionPoint` → añadir `EntityProvider`, `CatalogProcessor`.
- `scaffolderActionsExtensionPoint` → registrar `TemplateAction` custom.
- `techdocsBuildsExtensionPoint` → cambiar builder/generator.
- `authProvidersExtensionPoint` → añadir provider OAuth custom.
- `permissionPolicyExtensionPoint` → inyectar PermissionPolicy.

El contrato es TS puro, versionado con el plugin. Esto es lo que permite que el core sea delgado y que la mayoría del valor viva en plugins/modules.

## 5. Patrón "override con módulo"

Si un plugin tiene un default (p. ej. `allow-all` PermissionPolicy) y quieres cambiarlo:

```typescript
// packages/backend/src/index.ts
backend.add(import('@backstage/plugin-permission-backend/alpha'));

// En vez del allow-all:
backend.add(import('@internal/plugin-permission-backend-module-my-policy'));
```

El `my-policy` registra tu `PermissionPolicy` en el extension point, pisando el default. Nada más en `index.ts` cambia.

## 6. Testing de módulos

El framework provee `startTestBackend` para tests de integración aislados:

```typescript
import { startTestBackend } from '@backstage/backend-test-utils';

const { server } = await startTestBackend({
  features: [
    catalogPlugin,
    catalogModuleMyProvider,
    // mock de servicios core: logger, config, database (SQLite tmp)
  ],
});

const res = await request(server).get('/api/catalog/entities');
expect(res.status).toBe(200);
```

Correr tests de un módulo sin levantar el 90 % restante del backend es exactamente lo que el patrón legacy no permitía.

## 7. Checklist antes de añadir un `backend.add(...)`

- [ ] ¿Es un plugin oficial? Está en `@backstage/plugin-*`.
- [ ] ¿Importa de `/alpha`? Backstage marca APIs no estables así; úsalo pero sé consciente.
- [ ] ¿Depende de otro módulo? (p. ej. `module-github-provider` requiere `auth-backend`).
- [ ] ¿Tiene config asociada en `app-config.yaml`? Revísala en los docs del plugin.
- [ ] ¿Trae env vars? Documéntalas en tu README interno.

## 8. Antipatterns

1. **Mezclar patrones**: no uses `backend.ts` imperativo nuevo si el resto es Backend System 1.0. Migra entero.
2. **Añadir rutas HTTP a mano con `app.use(...)`**: en Backend System 1.0 se registran vía `coreServices.httpRouter.use(router)`. Si necesitas Express directo, probablemente debas hacer un plugin.
3. **Compartir estado global entre módulos**: cada módulo recibe sus deps vía `init`. Nada de `let myThing` module-level.
4. **Olvidar `scheduler` para tareas periódicas**: no uses `setInterval` — en multi-replica se duplica. El scheduler tiene lock distribuido vía DB.
