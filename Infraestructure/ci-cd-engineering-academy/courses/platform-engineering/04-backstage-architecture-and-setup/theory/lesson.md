# plat-04 — Lección: Backstage, arquitectura y setup

> 10 secciones. Mezcla conceptual + operativa. Prerrequisito: `plat-03`.

---

## 1. Backstage NO es una app descargable — es un framework

El error de framing más común: *"instalemos Backstage"*. No existe tal cosa como "instalar Backstage" en el sentido de bajar un binario o un contenedor con la UI final. Backstage es un **framework** de Node/TypeScript que te permite **construir tu propio IDP**.

El punto de entrada canónico es:

```bash
npx @backstage/create-app@latest
```

Que te pregunta un nombre y genera **un monorepo nuevo** con:

```
my-backstage/
├── app-config.yaml                  # config base
├── app-config.local.yaml.example    # dev overrides template
├── app-config.production.yaml       # prod overrides
├── backstage.json                   # version pin
├── catalog-info.yaml                # tu propio Backstage registrado en si mismo
├── package.json                     # workspace raiz (yarn workspaces)
├── packages/
│   ├── app/                         # frontend React (SPA, Material UI v5)
│   │   ├── src/App.tsx
│   │   ├── public/
│   │   └── package.json
│   └── backend/                     # backend Node (Express antes, Backend System 1.0 ahora)
│       ├── src/index.ts
│       └── package.json
└── plugins/                         # tus plugins custom; empieza vacio
```

El valor es que ese repo **es tuyo**: lo versionas, lo auditas, lo deployas y lo mantienes como cualquier otro servicio. No hay "Backstage" en producción — hay "tu Backstage".

> **Consecuencia operativa:** actualizar Backstage no es `apt-get upgrade`; es *bump* de versiones en `package.json` + `yarn install` + leer el **migration guide** del release correspondiente. Es trabajo de ingeniería recurrente.

---

## 2. Los tres paquetes del monorepo

### 2.1 `packages/app` — frontend

- **React SPA** con **Material UI** (v5+ en releases recientes).
- Composición declarativa de **plugins frontend** vía `@backstage/plugin-*` o plugins propios en `plugins/<name>/`.
- El layout, el routing (`FlatRoutes`), los themes y el AppRouter se componen en `App.tsx`.
- Build: `yarn workspace app build` → bundle estático servido por el backend o un CDN.

### 2.2 `packages/backend` — backend

- Node.js. Hasta ~2023 era un `backend.ts` imperativo que importaba cada plugin a mano. Desde **Backend System 1.0** se declara con `createBackend()` + `features` (ver §6).
- Expone endpoints HTTP para: catálogo, scaffolder, auth, techdocs, proxy, permissions, discovery (`/api/<plugin>`).
- Sirve también el bundle estático del frontend en producción.
- Build: `yarn workspace backend build && yarn workspace backend start`.

### 2.3 `plugins/` — tus plugins

- Vacío al principio. Se puebla con `npx @backstage/cli new` (plugin frontend, backend, o librería compartida).
- Cada plugin es un paquete npm aislado con su propio `package.json`, convive en el monorepo vía **yarn workspaces**.
- Esto permite distribuirlos como paquetes internos en un npm registry privado si creces.

---

## 3. `app-config.yaml` — configuración por capas

Backstage carga la config con un **merge en cascada**:

```
app-config.yaml                         (base, commiteada)
  + app-config.<env>.yaml               (por entorno, p.ej. production)
    + app-config.local.yaml             (dev local; en .gitignore)
      + variables de entorno            (${VAR_NAME})
```

Ejemplo mínimo (`app-config.yaml`):

```yaml
app:
  title: Scaffolded Backstage App
  baseUrl: http://localhost:3000

organization:
  name: My Company

backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007
  database:
    client: better-sqlite3            # dev; swap to pg in prod
    connection: ':memory:'
  cors:
    origin: http://localhost:3000

auth:
  providers:
    guest: {}                         # dev only

catalog:
  rules:
    - allow: [Component, API, Resource, System, Domain, User, Group, Location]
  locations:
    - type: file
      target: ../../catalog-info.yaml
```

Override para prod (`app-config.production.yaml`):

```yaml
app:
  baseUrl: https://backstage.example.com

backend:
  baseUrl: https://backstage.example.com
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: 5432
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}

auth:
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
```

El binario `backstage-cli` acepta `--config` múltiples veces:

```bash
backstage-cli package start --config ../../app-config.yaml \
                            --config ../../app-config.production.yaml
```

> **Regla práctica:** nunca commitees secretos en `app-config*.yaml`. Usa `${VAR}` y resuélvelos desde el entorno (K8s Secrets, Vault injection, etc.).

---

## 4. Storage: SQLite para dev, Postgres para prod

Backstage persiste estado en una **DB relacional**. Cada plugin con backend declara su propio schema con migraciones (Knex). En dev, SQLite in-memory basta y es rapidísimo. En prod, usar **Postgres** por tres razones:

1. **Concurrencia**: SQLite no sobrevive a múltiples instancias del backend.
2. **Backups**: operar PG es cosa resuelta (RDS, Cloud SQL, operadores K8s).
3. **Observabilidad**: logs/metrics/slow queries en PG son estándar.

Config típica en `app-config.production.yaml`:

```yaml
backend:
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: 5432
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: backstage_plugin_${pluginId}  # opcional: DB por plugin
```

Las migraciones corren automáticamente al arrancar el backend. Si tu release pipeline no corre migraciones manualmente, Backstage lo hará solo al primer `start`.

---

## 5. Auth: `guest`, GitHub, Google, Okta, LDAP, SAML

El framework de auth soporta múltiples **providers** declarados en `auth.providers.<name>`. Cada provider resuelve un identidad externa a un **usuario del catálogo** (kind `User`).

Para dev:

```yaml
auth:
  providers:
    guest: {}
```

→ cualquiera entra como "guest". **Solo dev.**

Para GitHub OAuth:

```yaml
auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
```

Pasos a nivel GitHub:

1. GitHub → Settings → Developer settings → OAuth Apps → New OAuth App.
2. Homepage URL: `http://localhost:3000`.
3. Authorization callback URL: `http://localhost:7007/api/auth/github/handler/frame`.
4. Copiar **Client ID** + **Client secret** a variables de entorno.
5. Exportar un **PAT** (o GitHub App token) como `GITHUB_TOKEN` para que el `integrations.github` del catálogo pueda leer repos.

> En este curso, cualquier token/clave que aparezca en documentación es un **placeholder** (`ghp_xxxx_placeholder_do_not_use`). Nunca commitees secretos reales.

Providers productivos típicos: **Google OIDC**, **Okta**, **Microsoft Entra ID**, **SAML**, **LDAP**. Cada uno requiere su app registration externa + bloque en `auth.providers`.

---

## 6. Backend System 1.0 — el patrón nuevo

Hasta ~2023, `packages/backend/src/index.ts` era un script imperativo de ~300 líneas que importaba cada plugin, construía un `createRouter`, montaba el Express app. Mantenerlo era doloroso: añadir un plugin implicaba editar 3 archivos.

**Backend System 1.0** reemplaza eso por un patrón declarativo:

```typescript
// packages/backend/src/index.ts
import { createBackend } from '@backstage/backend-defaults';

const backend = createBackend();

backend.add(import('@backstage/plugin-app-backend/alpha'));
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));
backend.add(import('@backstage/plugin-catalog-backend/alpha'));
backend.add(import('@backstage/plugin-scaffolder-backend/alpha'));
backend.add(import('@backstage/plugin-techdocs-backend/alpha'));
backend.add(import('@backstage/plugin-proxy-backend/alpha'));
backend.add(import('@backstage/plugin-permission-backend/alpha'));

backend.start();
```

Cada módulo es una **feature** autodescriptiva: declara qué servicios consume (`logger`, `database`, `config`, `httpRouter`), qué extensiona (p. ej. "añade un `GithubOrgEntityProvider` al catálogo") y en qué orden. Backstage resuelve el DAG de inicialización.

Para extensionar un plugin desde tu backend:

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import { catalogProcessingExtensionPoint } from '@backstage/plugin-catalog-node/alpha';

export const myCustomProcessor = createBackendModule({
  pluginId: 'catalog',
  moduleId: 'my-custom-processor',
  register(env) {
    env.registerInit({
      deps: { catalog: catalogProcessingExtensionPoint },
      async init({ catalog }) {
        catalog.addProcessor(new MyCustomProcessor());
      },
    });
  },
});
```

> **Por qué importa:** este patrón es el que todos los plugins oficiales ya adoptaron. Si creas Backstage hoy y lo primero que tocas es `index.ts` imperativo, probablemente estás leyendo un tutorial viejo.

---

## 7. Permissions framework (overview)

Opcional, pero crucial a escala. Permite reglas como:

- *"Solo el owner (Group X) puede editar la entidad `Component:api-foo`."*
- *"Solo miembros del grupo platform-team pueden ejecutar el template `aws-rds`."*
- *"Nadie fuera de prod-oncall puede ver entidades con label `confidential=true`."*

Se configura habilitando `permission-backend` + un **PermissionPolicy** custom en TS que recibe la query (quién, qué acción, qué recurso) y responde `ALLOW`/`DENY`/`CONDITIONAL`. Las `CONDITIONAL` se materializan como filtros SQL del lado del backend (no filtrar en memoria con 100k entidades).

En este módulo lo mencionamos; la implementación detallada queda para módulos avanzados.

---

## 8. Deploy en Kubernetes vía Helm

El chart oficial de la comunidad vive en `https://github.com/backstage/charts`. Se instala así:

```bash
helm repo add backstage https://backstage.github.io/charts
helm repo update

helm install backstage backstage/backstage \
  --namespace backstage --create-namespace \
  --values values.yaml
```

Un `values.yaml` mínimo real:

```yaml
backstage:
  image:
    registry: ghcr.io
    repository: my-org/backstage
    tag: 'v2025.10.01'

  extraEnvVars:
    - name: POSTGRES_HOST
      valueFrom:
        secretKeyRef: { name: backstage-pg, key: host }
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef: { name: backstage-pg, key: user }
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef: { name: backstage-pg, key: password }
    - name: AUTH_GITHUB_CLIENT_ID
      valueFrom:
        secretKeyRef: { name: backstage-gh, key: client-id }
    - name: AUTH_GITHUB_CLIENT_SECRET
      valueFrom:
        secretKeyRef: { name: backstage-gh, key: client-secret }

ingress:
  enabled: true
  host: backstage.example.com
  className: nginx
  tls:
    - secretName: backstage-tls
      hosts: [backstage.example.com]

postgresql:
  enabled: false   # usamos PG externo (RDS/Cloud SQL)

serviceMonitor:
  enabled: true    # si corres Prometheus Operator
```

Puntos a mirar siempre:

- **Imagen**: tú construyes el contenedor desde tu monorepo (`yarn build:all && yarn build-image`). El chart no incluye imagen por default.
- **Secretos**: nunca inline. `secretKeyRef` + External Secrets Operator / Vault / SOPS.
- **DB**: `postgresql.enabled=false` + managed PG en prod. El subchart de Postgres sirve para demos.
- **Ingress**: TLS obligatorio; GitHub OAuth no funciona en HTTP a dominio público.
- **Observability**: `serviceMonitor` + logs estructurados + traces (ver cursos `prometheus-grafana` y `opentelemetry`).

---

## 9. Política de upgrade — es trabajo recurrente

Backstage libera **cada semana**. Cada release puede traer:

- Deprecations (warnings al compilar).
- Breaking changes (migration guide obligatorio).
- Nuevos plugins oficiales.
- Bugfixes y perf.

Flujo recomendado:

1. `yarn backstage-cli versions:bump` → sube todos los paquetes `@backstage/*` a la versión más nueva compatible.
2. Leer el **upgrade-helper diff** (`https://backstage.github.io/upgrade-helper/`) → te muestra el diff que *create-app* generaría hoy, para ver cambios en `App.tsx` / `index.ts` / `app-config.yaml` que tienes que mergear manualmente.
3. Correr tests (`yarn test:all`) y `yarn tsc` para pillar breakage.
4. Lanzar local, probar flujos clave.
5. PR → merge → deploy canario.

Equipos que **no** mantienen esta cadencia terminan con un Backstage de hace 12 meses, con 400 commits de deuda y una migración "big bang" dolorosa.

> **Regla:** reservar al menos 1 día cada 2 semanas para el upgrade. Cuesta menos amortizado.

---

## 10. Alternativa: CNOE pre-ensamblada

**CNOE** (Cloud Native Operational Excellence) es un *reference stack* bendecido por la CNCF que incluye:

- **Backstage** (sí, el mismo framework).
- **Argo CD** para GitOps.
- **Crossplane** para self-service de infra.
- **Argo Workflows** para ejecución asíncrona.
- **Keycloak** para auth.
- **External Secrets Operator**.

Y un bootstrapper (`idpbuilder`) que te monta todo en un Kind local en minutos.

Trade-off vs Backstage self-hosted:

| Dimensión | Backstage DIY | CNOE preassembled |
|-----------|---------------|-------------------|
| Tiempo al primer "hola mundo" | 1–3 días | 30 min |
| Flexibilidad | Total | Alta pero opinionada |
| Mantenimiento | Tú upgrdas todo | CNOE releasea stacks completos |
| Curva | Node/TS + K8s + plugins | K8s + CNOE conventions |
| Buena fit | Org con platform team ≥ 3 ingenieros | PoC, orgs pequeñas, equipos K8s-first |

Elegir CNOE no te libra de aprender Backstage — todavía escribirás `catalog-info.yaml`, templates, plugins custom. Solo te libra del *bootstrap* operacional.

Decisión en una línea:

> *Si vas a construir plataforma durante 3+ años con equipo dedicado, Backstage DIY. Si quieres validar la hipótesis "necesitamos un IDP" en 2 semanas sin comprometer una app propia, CNOE.*

---

## Punto a repetir hasta que suene aburrido

> Backstage **no se instala, se construye**. Tu repo Backstage es un servicio más de tu organización, con su CI, sus upgrades semanales, su on-call. Esto es lo que hace que el valor acumule con el tiempo — y lo que hace que un platform team sin disciplina lo abandone en 6 meses.
