# plat-08 — Ecosistema de plugins y plugin propio

## Identificación

- **ID:** `plat-08-plugins-ecosystem-and-custom-plugin`
- **Curso:** `platform-engineering`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `plat-04` (software catalog), `plat-05` (software templates). Entender que un Backstage "catálogo-only" es un wiki tipado y que los **plugins** son la "capa de contexto" alrededor del catálogo.

## Objetivo

Aprovechar los plugins **oficiales** de Backstage para traer dentro del portal el contexto operativo que ya vive disperso (Kubernetes, GitHub Actions, Argo CD, PagerDuty, Grafana), y aprender el **ciclo completo** de un plugin propio: scaffolding con `backstage-cli`, estructura **frontend + backend**, consumo de APIs externas vía `discoveryApi` + **proxy**, versionado y upgrade.

Al terminar el módulo deberías poder:

1. Enumerar los **3 plugins** que más valor agregan primero a un Backstage recién instalado y justificar el orden.
2. Instalar y configurar los plugins de **Kubernetes**, **GitHub Actions** y **Argo CD** a nivel de `app-config.yaml`, `catalog-info.yaml` (anotaciones) y árbol frontend (`EntityPage`).
3. Crear un **plugin frontend propio** con `backstage-cli create` que lea datos del catálogo y los renderice en una Card dentro de `EntityPage`.
4. Explicar cuándo necesitas un **plugin backend** aparte y por qué `discoveryApi` + proxy evita credenciales en el navegador.
5. Articular el **ciclo de upgrade**: los plugins siguen el versionado del `@backstage/core-*` y romper esa alineación paga coste técnico lineal con el tiempo.

## Alcance

Este módulo cubre:

- **Plugins oficiales** curados: Kubernetes, GitHub Actions, Argo CD, PagerDuty/Opsgenie, Grafana (dashboards embebidos), Cost Insights, TechInsights (base para scorecards de `plat-10`), Catalog Graph, API Docs.
- **Plugins comunitarios** útiles: Sentry, Datadog, SonarQube, Snyk, Vault.
- **Patrón de anotación** (`backstage.io/kubernetes-id`, `github.com/project-slug`, `argocd/app-name`, `pagerduty.com/integration-key`, `grafana/dashboard-selector`): cómo el plugin descubre a qué recursos externos pertenece una entidad del catálogo.
- **Scaffolding** con `backstage-cli create` → `plugins/<name>/`.
- **Estructura de un plugin**: `src/plugin.ts` (routable), `src/components/`, `src/api/` (clientes), tests Jest.
- **Frontend-only vs frontend + backend**: cuándo basta llamar a una API con token OAuth del usuario y cuándo necesitas un backend que inyecte secretos de servicio.
- **`discoveryApi`** del core: cómo el frontend descubre dónde vive un plugin backend (`http://localhost:7007/api/<plugin>`).
- **Proxy configuration** (`proxy.endpoints`): el patrón más barato para "mi plugin solo necesita GET a un endpoint HTTP de un sistema interno con un token guardado en env".
- **Versionado y distribución**: npm private registry, workspaces, `yarn tsc` + `yarn test` como gates mínimos.
- **Ciclo de upgrade**: `backstage-cli versions:bump`, por qué quedarse 6+ meses atrás es doloroso.

Lo que **no** cubre:

- Backstage **básico** (eso vive en `plat-04` y `plat-05`).
- Scorecards sobre TechInsights → `plat-10`.
- Self-service con Crossplane → `plat-09`.
- Deploy production-grade de Backstage (DB externa, auth, multi-tenant) → `plat-12`.

Este módulo es **mayoritariamente lectura y walkthrough**. Las dos actividades son **estructurales**: en la 01 integras configuración y anotaciones sin levantar un cluster; en la 02 esqueletas un plugin propio y validas que la estructura mínima está presente. Para quien tenga `node + yarn + Backstage` localmente, el walkthrough se puede ejecutar en vivo, pero los validadores **no lo exigen** y hacen `SKIP` graceful si falta tooling.

## Materiales

- **`theory/lesson.md`** — lección profunda con 11 secciones.
- **`examples/`** — tres walkthroughs:
  - `01-k8s-plugin-config/` — fragmentos de `app-config.yaml`, anotación `backstage.io/kubernetes-id`, árbol de `EntityKubernetesContent`.
  - `02-github-actions-plugin/` — anotación `github.com/project-slug`, token GitHub con proxy, tarjeta de workflows en `EntityPage`.
  - `03-custom-plugin-boilerplate/` — anatomía de un plugin generado por `backstage-cli create`: `package.json`, `src/plugin.ts`, `src/components/ExampleComponent/`.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-wire-essential-plugins/` — producir `WIRING.md` con el plan de 3 plugins y los fragmentos de configuración + anotaciones necesarios.
  - `02-write-minimal-custom-plugin/` — scaffoldear la estructura mínima de un plugin propio en `/tmp/plat-08-plugin`, incluyendo `package.json`, `src/plugin.ts` y un componente React tipado.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un Backstage sin plugins "es un wiki tipado". Diferenciar plugin frontend-only, frontend+backend y proxy-only. |
| Operativa | Aplicar anotaciones correctas en `catalog-info.yaml` para 3 plugins oficiales. Configurar un bloque `proxy.endpoints` sin exponer secretos al cliente. |
| Arquitectónica | Diseñar un plugin propio mínimo (nombre, routable extension, componente, API cliente). Decidir si necesita backend. Elegir qué 3 plugins oficiales instalar primero. |

## Criterios de evaluación

- Identifica los **3 plugins** de mayor valor inicial (orden razonable: Kubernetes → GitHub Actions → Argo CD **o** PagerDuty, defendible).
- Nombra correctamente las anotaciones de catálogo para K8s, GitHub Actions y Argo CD.
- Distingue cuándo un plugin **necesita** backend propio (secretos de servicio, agregación, cache) vs cuándo basta un `proxy.endpoints`.
- Entiende el papel de `discoveryApi` y por qué el navegador **no** debe conocer URLs internas.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- `WIRING.md` con plan de 3 plugins + fragmentos de configuración (sale de la actividad `01-wire-essential-plugins`).
- Esqueleto de plugin propio en `/tmp/plat-08-plugin/` con `package.json`, `src/plugin.ts` y componente (sale de la actividad `02-write-minimal-custom-plugin`).

## Siguiente módulo

→ `plat-09-self-service-infra-crossplane-and-templates` — habilitar self-service real con Crossplane y templates.
