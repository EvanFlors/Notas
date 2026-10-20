# Recursos — plat-04

Referencias oficiales y lecturas de apoyo. Verificar vigencia (Backstage libera semanalmente).

## Oficiales (Backstage / CNCF)

- **Sitio oficial**: `https://backstage.io/`
- **Getting started**: `https://backstage.io/docs/getting-started/`
- **Docs**: `https://backstage.io/docs/`
- **Repo monorepo**: `https://github.com/backstage/backstage`
- **CNCF project page**: `https://www.cncf.io/projects/backstage/`

## create-app y estructura del repo

- **create-app**: `https://backstage.io/docs/getting-started/create-an-app/`
- **Monorepo layout**: `https://backstage.io/docs/overview/architecture-overview/`
- **Upgrade helper (diffs entre releases)**: `https://backstage.github.io/upgrade-helper/`

## Configuración

- **app-config structure**: `https://backstage.io/docs/conf/`
- **Writing config**: `https://backstage.io/docs/conf/writing/`
- **Reading config**: `https://backstage.io/docs/conf/reading/`
- **Defining values (env vars)**: `https://backstage.io/docs/conf/defining/`

## Backend System 1.0

- **Overview**: `https://backstage.io/docs/backend-system/`
- **Architecture**: `https://backstage.io/docs/backend-system/architecture/index`
- **Building backends**: `https://backstage.io/docs/backend-system/building-backends/index`
- **Creating modules**: `https://backstage.io/docs/backend-system/architecture/modules`
- **Migration guide (legacy → new)**: `https://backstage.io/docs/backend-system/building-backends/migrating`

## Auth

- **Auth overview**: `https://backstage.io/docs/auth/`
- **GitHub provider**: `https://backstage.io/docs/auth/github/provider`
- **Google OIDC**: `https://backstage.io/docs/auth/google/provider`
- **Okta**: `https://backstage.io/docs/auth/okta/provider`
- **Microsoft Entra**: `https://backstage.io/docs/auth/microsoft/provider`

## Database

- **Postgres setup**: `https://backstage.io/docs/getting-started/configuration/#install-and-configure-postgresql`

## Permissions

- **Permission framework**: `https://backstage.io/docs/permissions/overview`
- **Writing a policy**: `https://backstage.io/docs/permissions/writing-a-policy`

## Deploy / Helm chart

- **Chart repo**: `https://github.com/backstage/charts`
- **Chart docs**: `https://github.com/backstage/charts/tree/main/charts/backstage`
- **Deployment overview**: `https://backstage.io/docs/deployment/`
- **Docker build**: `https://backstage.io/docs/deployment/docker`

## Alternativa: CNOE

- **CNOE site**: `https://cnoe.io/`
- **idpbuilder**: `https://github.com/cnoe-io/idpbuilder`
- **Reference implementation**: `https://github.com/cnoe-io/reference-implementation-aws`

## Comparativa

- **Backstage vs Port vs OpsLevel vs Cortex** — buscar "IDP tool comparison" en blogs de Thoughtworks / Humanitec / Port.
- **"When NOT to pick Backstage"** — Humanitec blog, varias ediciones.

## Checklist Fase 4 (verificar antes de impartir)

- Versión actual del framework (`backstage.json` scaffold por default).
- Status del Backend System 1.0 (ya hay `backend-system/2.0`? consultar roadmap).
- Chart version actual + breaking changes del values schema.
- Node LTS vigente (actualmente 20 / 22 soportados).
- Último migration guide (upgrade-helper).
