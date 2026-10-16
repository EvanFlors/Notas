# Ejemplo 01 — `npx @backstage/create-app`: qué genera y cómo lanzarlo

> Lectura y análisis. Si tienes `node >= 20`, puedes ejecutar los comandos; si no, el walkthrough es suficiente.

## 1. El comando

```bash
# Requiere node >= 20 (Backstage sigue el LTS de Node)
node --version   # debe mostrar v20.x o v22.x
npx @backstage/create-app@latest
```

El wizard pregunta un nombre (p. ej. `my-backstage`). Luego descarga ~1.5 GB de dependencias (`yarn install`) y deja el repo listo para arrancar.

> **Si falla con `EBADENGINE`**: tu Node es demasiado viejo. Instala Node 20 vía `nvm install 20` o `brew install node@20`.

## 2. Qué genera

```
my-backstage/
├── app-config.yaml                # config base (commiteada)
├── app-config.local.yaml          # overrides locales (en .gitignore)
├── app-config.production.yaml     # overrides prod
├── backstage.json                 # pin de version del framework
├── catalog-info.yaml              # Backstage registrado en si mismo
├── package.json                   # yarn workspaces raiz
├── packages/
│   ├── app/                       # frontend React
│   │   ├── public/                # index.html, favicon, logos
│   │   ├── src/
│   │   │   ├── App.tsx            # composicion de rutas + plugins
│   │   │   ├── apis.ts            # API factories (identity, discovery, ...)
│   │   │   ├── components/        # Root, Header, SidebarItems
│   │   │   └── index.tsx          # entrypoint
│   │   └── package.json
│   └── backend/
│       ├── src/
│       │   └── index.ts           # Backend System 1.0: createBackend + add(...)
│       └── package.json
├── plugins/                       # vacio al principio
├── Dockerfile                     # multi-stage build de la imagen
├── examples/                      # catalog-entities de muestra
└── yarn.lock
```

## 3. Arrancar en dev

```bash
cd my-backstage
yarn dev
```

Levanta **dos procesos** en paralelo:

- Frontend en `http://localhost:3000` (webpack dev server con HMR).
- Backend en `http://localhost:7007` (Node + ts-node-dev).

El frontend hace proxy a `/api/*` → `localhost:7007/api/*`. Logueado como "guest" ves el catálogo con los ejemplos sembrados.

## 4. Diagrama de componentes (fresh install)

```
      Browser
         │
         ▼
┌───────────────────────────┐
│ packages/app (React SPA)  │  localhost:3000
│  - App.tsx                │
│  - plugins frontend       │
│  - APIs (DiscoveryApi, …) │
└──────────┬────────────────┘
           │  /api/*
           ▼
┌───────────────────────────┐
│ packages/backend (Node)   │  localhost:7007
│  createBackend()          │
│   .add(app-backend)       │  ← sirve el bundle del frontend en prod
│   .add(auth-backend)      │  ← /api/auth/*
│   .add(catalog-backend)   │  ← /api/catalog/*
│   .add(scaffolder-backend)│  ← /api/scaffolder/*
│   .add(techdocs-backend)  │  ← /api/techdocs/*
│   .add(proxy-backend)     │  ← /api/proxy/*
│   .add(permission-backend)│  ← /api/permission/*
└──────────┬────────────────┘
           │
           ▼
    ┌────────────┐
    │  SQLite    │  (dev: in-memory; prod: Postgres)
    │ in-memory  │
    └────────────┘
```

## 5. Lo que NO verás todavía

- **Plugins propios**: `plugins/` está vacío. `npx @backstage/cli new` los añade cuando los necesites.
- **Auth real**: el provider por default es `guest`. GitHub/Google/Okta exigen app registration + env vars.
- **Catalog entities reales**: los `examples/` son demo. En prod, el catálogo se puebla desde GitHub orgs vía providers (ver `plat-05`).
- **Templates**: hay un par de demo. Se profundiza en `plat-06`.

## 6. Antipatterns comunes al primer `create-app`

1. **Commitear `app-config.local.yaml`** con secretos de dev. El `.gitignore` ya lo excluye — no lo saques.
2. **Modificar `backend/src/index.ts` como si fuera un Express app**. Es Backend System 1.0; añade `features`, no monta routers a mano.
3. **Correr `yarn dev` como daemon en una VM compartida**. Es dev; para "prod en el laptop" usa `yarn build:all && yarn workspace backend start`.
4. **Hacer `git init` con los `node_modules`**. El `.gitignore` también los excluye — verifica tras `yarn install`.

## 7. Siguiente paso natural

Leer el ejemplo 02 (`../02-app-config-structure`) para entender cómo se ajusta `app-config` por entorno, y el 03 (`../03-backend-system-1`) para el patrón del backend.
