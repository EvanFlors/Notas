# Recursos — plat-08

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia (las URLs y versiones cambian).

## Oficiales (Backstage)

- **Sitio oficial**: `https://backstage.io/`
- **Plugins directory**: `https://backstage.io/plugins`
- **Plugin development overview**: `https://backstage.io/docs/plugins/`
- **Create a plugin (frontend)**: `https://backstage.io/docs/plugins/create-a-plugin`
- **Backend plugin (New Backend System)**: `https://backstage.io/docs/backend-system/`
- **Discovery API**: `https://backstage.io/docs/plugins/call-existing-api`
- **Proxy plugin (`proxy-backend`)**: `https://backstage.io/docs/plugins/proxying`

## Plugins oficiales clave (walkthrough del módulo)

- **Kubernetes plugin**: `https://backstage.io/docs/features/kubernetes/`
- **GitHub Actions plugin**: `https://github.com/backstage/community-plugins/tree/main/workspaces/github-actions`
- **Argo CD plugin (Roadie)**: `https://roadie.io/backstage/plugins/argo-cd/`
- **PagerDuty plugin**: `https://github.com/PagerDuty/backstage-plugin`
- **Grafana plugin (K-Phoen)**: `https://github.com/K-Phoen/backstage-plugin-grafana`
- **Cost Insights**: `https://backstage.io/docs/features/cost-insights/`
- **TechInsights**: `https://backstage.io/docs/features/tech-insights/`
- **Catalog Graph**: `https://backstage.io/docs/features/software-catalog/plugins`
- **API Docs**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-api`

## Plugins comunitarios (verificar mantenimiento)

- Sentry, Datadog, SonarQube, Snyk, Vault — ver `https://backstage.io/plugins` filtrando por categoría.

## Anotaciones de catálogo

- **Well-known annotations**: `https://backstage.io/docs/features/software-catalog/well-known-annotations`

## Versionado y upgrade

- **`backstage-cli versions:bump`**: `https://backstage.io/docs/tooling/cli/commands#versionsbump`
- **Release schedule**: `https://backstage.io/docs/releases/`
- **Upgrade helper**: `https://backstage.github.io/upgrade-helper/`

## Distribución de plugins internos

- **Publishing plugins**: `https://backstage.io/docs/plugins/publish-private`
- **Verdaccio** (registry privado para dev interno): `https://verdaccio.org/`
- **GitHub Packages npm**: `https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry`

## Lecturas

- "You probably don't need a Backstage plugin" — buscar posts recientes del CNCF TAG App Delivery sobre el patrón proxy-only vs plugin propio.
- **Backstage Community discussions**: `https://github.com/backstage/backstage/discussions`
- **Spotify Backstage YouTube** (release notes y walkthroughs): canal oficial de Spotify Engineering.

## Checklist de verificación requerida en Fase 4

- Versión actual del **core de Backstage** y última release estable.
- Estado del **New Backend System** (ya es default o aún opt-in).
- Versión actual del **plugin de Kubernetes** y si cambió el formato de anotaciones.
- Vigencia del plugin **Argo CD de Roadie** vs alternativas comunitarias.
- Lista actualizada de plugins **archivados / sin mantenimiento** (ocurre cada release).
