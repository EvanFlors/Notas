# REFERENCE — plat-04-01-local-backstage-with-github-auth

> Modelo razonado. No es la única respuesta correcta.

## Sección A — create-app y estructura del repo

Comando:

```bash
# Requisito: node >= 20
npx @backstage/create-app@latest
# Nombre: my-backstage
```

Resultado — monorepo gestionado con **yarn workspaces**:

```
my-backstage/
├── app-config.yaml                # base, commiteada
├── app-config.local.yaml          # overrides locales (en .gitignore)
├── app-config.production.yaml     # overrides prod
├── backstage.json                 # pin del framework
├── catalog-info.yaml              # Backstage registrado en si mismo
├── package.json                   # workspaces root
├── packages/
│   ├── app/                       # frontend React (SPA, Material UI)
│   └── backend/                   # backend Node (Backend System 1.0)
├── plugins/                       # vacio al inicio
└── Dockerfile                     # multi-stage para la imagen prod
```

**Por qué un repo**: Backstage es un framework, no una app. Tu repo *es* tu Backstage. Lo versionas, lo upgradgeas, lo deployas como cualquier otro servicio.

## Sección B — Merge por capas de `app-config`

Orden de resolución:

```
1. app-config.yaml                      ← base commiteada
2. app-config.<env>.yaml                ← ej. app-config.production.yaml
3. app-config.local.yaml                ← overrides locales (git-ignored)
4. --config CLI flags                   ← en orden
5. ${VAR_NAME} resolucion               ← ultima fase
```

Reglas:

- Deep-merge por clave.
- Listas se **reemplazan** completas (gotcha).
- Variables faltantes → arranque falla.

Ejemplo de override productivo:

```yaml
# app-config.yaml (dev)
backend:
  database:
    client: better-sqlite3
    connection: ':memory:'

# app-config.production.yaml
backend:
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: 5432
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
```

## Sección C — Auth GitHub

### Pasos a nivel GitHub

1. GitHub → Settings → Developer settings → OAuth Apps → **New OAuth App**.
2. Homepage URL: `http://localhost:3000`.
3. Authorization callback URL: `http://localhost:7007/api/auth/github/handler/frame`.
4. Guardar **Client ID** y **Client Secret** en env vars locales (nunca en `app-config.yaml`).
5. Crear un **Personal Access Token** (o GitHub App) con scope `repo` + `read:org` para que `integrations.github` pueda leer catalog-infos. Guardarlo como `GITHUB_TOKEN`.

### Config

```yaml
# app-config.yaml
auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

### Variables de entorno (placeholders — no son reales)

```bash
# app-config.local.yaml alternativa: export directo (jamas commitees valores reales)
export AUTH_GITHUB_CLIENT_ID='Iv1.xxxx_placeholder'
export AUTH_GITHUB_CLIENT_SECRET='xxxxx_placeholder_do_not_use'
export GITHUB_TOKEN='ghp_xxxx_placeholder_do_not_use'
```

**Seguridad**: en este documento jamás aparece un token real. Todos los valores llevan `placeholder`.

## Sección D — Postgres en producción

Overlay productivo:

```yaml
# app-config.production.yaml
backend:
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: 5432
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      ssl: { rejectUnauthorized: false }
```

Env vars requeridas:

- `POSTGRES_HOST`
- `POSTGRES_PORT` (default 5432)
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

**Por qué**:

- SQLite in-memory no sobrevive a múltiples réplicas del backend (cada pod tiene su DB).
- SQLite en disco rompe con `rwx` compartido entre pods.
- Postgres managed (RDS, Cloud SQL, Aiven) resuelve backups, HA, upgrades.
- Las **migraciones Knex** corren automáticas al `backend.start()`. Cada plugin tiene su schema.

Opcional: `database: backstage_plugin_${pluginId}` para separar DB por plugin.

## Sección E — Diagrama de componentes

```
                   ┌──────────────┐
                   │   Browser    │
                   └──────┬───────┘
                          │
                     http://localhost:3000
                          │
          ┌───────────────▼───────────────┐
          │  packages/app  (React SPA)    │
          │  - App.tsx                    │
          │  - plugins frontend           │
          └──────┬────────────────────────┘
                 │  /api/*
                 │  http://localhost:7007
                 ▼
          ┌─────────────────────────────┐
          │  packages/backend (Node)    │
          │  createBackend()            │
          │   .add(app-backend)         │
          │   .add(auth-backend) ─────┐ │
          │   .add(catalog-backend)   │ │
          │   .add(scaffolder-...)    │ │
          │   .add(permission-...)    │ │
          └──────┬──────────────────┬─┘ │
                 │                  │   │
                 ▼                  │   │
         ┌─────────────────┐        │   │
         │   SQLite (dev)  │        │   │
         │   Postgres(prod)│        │   │
         └─────────────────┘        │   │
                                    │   │   OAuth redirect
                                    │   └─────────────────┐
                                    ▼                     ▼
                           ┌─────────────────┐    ┌────────────────┐
                           │ integrations.   │    │  GitHub OAuth  │
                           │ github (API)    │    │  App           │
                           │ (reads repos    │    │  (clientId +   │
                           │  for catalog)   │    │   clientSecret)│
                           └─────────────────┘    └────────────────┘
```

Flujo auth GitHub:

1. Browser → `GET http://localhost:3000`
2. User clicks "Sign in with GitHub" → `GET /api/auth/github/start`
3. Backend 302 → GitHub OAuth consent
4. User aprueba → GitHub 302 → `GET /api/auth/github/handler/frame?code=…`
5. Backend intercambia `code` → `access_token` con GitHub
6. Backend crea sesión (JWT en cookie) → responde al frame
7. Frontend recibe identidad → carga catálogo

## Puntos a repetir

- Backstage no se instala, se **construye**.
- Secretos **nunca** en `app-config.yaml`. Siempre `${VAR}`.
- SQLite = dev. Postgres = prod. No negociable en multi-replica.
- OAuth callback URL exacta importa: diferente puerto o esquema → rompe.
- `app-config.local.yaml` está en `.gitignore` por una razón. No lo saques.
