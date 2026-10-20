# Ejemplo 02 — Anatomía de `app-config.yaml` y merge por capas

> Lectura y análisis. Entender el orden exacto en el que Backstage resuelve la config evita el 80 % de los bugs de "funciona en local, no en prod".

## 1. El orden de merge (importante)

Backstage carga configs en este orden y hace **deep-merge** (los overrides pisan solo las claves que redefinen):

```
1. app-config.yaml                      ← base, siempre primero
2. app-config.<env>.yaml                ← ej. app-config.production.yaml si NODE_ENV=production
3. app-config.local.yaml                ← overrides locales (en .gitignore)
4. --config flags en linea de comandos  ← en el orden dado
5. ${VAR_NAME} resolution               ← ultimo paso
```

Reglas:

- Un valor en (2) pisa el de (1). Un valor en (3) pisa el de (2). Etcétera.
- Si una clave es una **lista**, el override **reemplaza** la lista entera (no concatena). Es un *gotcha* clásico.
- Las variables `${VAR}` se resuelven al final; faltan → error al arrancar.

## 2. Config base anotada

```yaml
# app-config.yaml
app:
  title: Scaffolded Backstage App     # titulo visible
  baseUrl: http://localhost:3000      # URL publica del frontend

organization:
  name: My Company                    # mostrado en header

backend:
  baseUrl: http://localhost:7007      # URL publica del backend
  listen:
    port: 7007                        # puerto donde escucha el server
    host: 0.0.0.0                     # 0.0.0.0 en container, 127.0.0.1 dev local
  csp:
    connect-src: ["'self'", 'http:', 'https:']
  cors:
    origin: http://localhost:3000     # debe coincidir con app.baseUrl
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: better-sqlite3            # dev; 'pg' en prod
    connection: ':memory:'

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}          # PAT o GitHub App token (placeholder: ghp_xxxx_placeholder)

proxy:
  '/test':
    target: 'https://example.com'
    changeOrigin: true

techdocs:
  builder: 'local'                    # 'external' en prod (CI builds, S3 serving)
  generator:
    runIn: 'docker'                   # 'local' si tienes mkdocs instalado
  publisher:
    type: 'local'                     # 'awsS3' | 'googleGcs' | 'azureBlobStorage' en prod

auth:
  providers:
    guest: {}                         # dev only

scaffolder:
  # defaultAuthor, defaultCommitMessage, etc.

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, API, Resource, System, Domain, User, Group, Location]
  locations:
    - type: file
      target: ../../catalog-info.yaml
```

## 3. Override de producción

```yaml
# app-config.production.yaml
app:
  baseUrl: https://backstage.example.com

backend:
  baseUrl: https://backstage.example.com
  listen:
    port: 7007
    host: 0.0.0.0
  cors:
    origin: https://backstage.example.com
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: 5432
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      ssl: { rejectUnauthorized: false }

auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}

techdocs:
  builder: 'external'
  publisher:
    type: 'awsS3'
    awsS3:
      bucketName: ${TECHDOCS_S3_BUCKET}
      region: ${AWS_REGION}
```

## 4. Override local (dev personal)

```yaml
# app-config.local.yaml  (NUNCA commitees)
auth:
  providers:
    github:
      development:
        clientId: 'Iv1.xxxx_placeholder'
        clientSecret: 'xxxxx_placeholder'

integrations:
  github:
    - host: github.com
      token: 'ghp_xxxx_placeholder_do_not_use'
```

## 5. Comando real para arrancar con overrides

```bash
# Dev local (usa app-config.yaml + app-config.local.yaml por default)
yarn dev

# Simular production localmente
yarn workspace backend start \
  --config ../../app-config.yaml \
  --config ../../app-config.production.yaml
```

En el contenedor de prod, el `CMD` del Dockerfile:

```dockerfile
CMD ["node", "packages/backend", \
     "--config", "app-config.yaml", \
     "--config", "app-config.production.yaml"]
```

## 6. Variables de entorno — convención Backstage

```
AUTH_<PROVIDER>_CLIENT_ID / _CLIENT_SECRET
GITHUB_TOKEN
POSTGRES_HOST / POSTGRES_PORT / POSTGRES_USER / POSTGRES_PASSWORD
TECHDOCS_S3_BUCKET / AWS_REGION
BACKEND_SECRET          # token simetrico para auth entre backend plugins
```

Fuente recomendada: **External Secrets Operator** (K8s) → Secret → `envFrom.secretRef` del Deployment.

## 7. Validar config

```bash
yarn backstage-cli config:print --frontend         # ver que ve el frontend
yarn backstage-cli config:print                    # ver merged final
yarn backstage-cli config:check                    # validar schema
```

Esto evita bugs sutiles como: *"baseUrl en app es http pero en backend es https → OAuth callback rompe"*.

## 8. Checklist antes de deploy a prod

- [ ] `app.baseUrl` y `backend.baseUrl` apuntan al dominio público real.
- [ ] `cors.origin` coincide con `app.baseUrl` (incluyendo esquema y puerto).
- [ ] `database.client = pg` y connection apunta a managed PG.
- [ ] Ningún secreto literal en el YAML — todo vía `${VAR}`.
- [ ] `auth.environment = production` y el provider real está declarado.
- [ ] `techdocs.publisher` apunta a storage persistente.
- [ ] `integrations.github.token` existe (sin él el catálogo no lee repos).
