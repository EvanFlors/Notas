# plat-04 — Backstage: arquitectura y setup

## Identificación

- **ID:** `plat-04-backstage-architecture-and-setup`
- **Curso:** `platform-engineering`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `plat-03` (IDP landscape). Nociones básicas de Node.js/TypeScript. Para la actividad 02, nociones básicas de Kubernetes y Helm (`k8s-02` o superior).

## Objetivo

Instalar Backstage localmente y **entender su arquitectura** como *framework* (no como app descargable). Al terminar deberías poder: justificar por qué cada repo Backstage es "tu propia app"; nombrar los componentes core (`packages/app` frontend, `packages/backend` backend, `plugins/*`); configurar `app-config.yaml` por entorno; conectar auth GitHub; y defender *Backstage self-hosted vs CNOE preassembled*.

## Alcance

Este módulo cubre:

- **Backstage es un framework**: el flujo oficial es `npx @backstage/create-app` que genera un monorepo con tu nombre. No se "instala Backstage"; se **crea** tu Backstage.
- **Estructura del monorepo**: `packages/app` (frontend React), `packages/backend` (backend Node.js), `plugins/*` (plugins propios), `app-config*.yaml` (configuración por entorno).
- **Configuración por capas**: `app-config.yaml` → `app-config.local.yaml` (dev local, en `.gitignore`) → `app-config.production.yaml` (overrides de prod). El cargador de config hace merge en orden.
- **Storage**: SQLite in-memory para desarrollo, **Postgres** recomendado para producción (schema por plugin, migraciones automáticas).
- **Auth**: `guest` para dev; **GitHub / Google / Okta / LDAP / SAML** para prod. Config vive en `auth.providers.<name>` + variables de entorno.
- **Permissions framework**: capa opcional para RBAC fino (quién ve qué entidad, quién ejecuta qué template).
- **Backend System 1.0**: el patrón nuevo (features como `createBackendModule`, inyección de dependencias). Reemplaza el patrón legacy "backend.ts imperativo".
- **Deploy en K8s**: chart oficial de la comunidad (`backstage/backstage` en el repo `backstage/charts`), valores clave (image, postgresql, ingress, extraEnvVars para secretos).
- **Política de upgrade**: Backstage libera semanalmente; breaking changes frecuentes documentados en migration guides. No upgradear = acumular deuda.
- **CNOE como alternativa**: *reference implementation* pre-ensamblada (Backstage + Argo CD + Crossplane + Keycloak + Argo Workflows) con un `idpbuilder` que te monta todo en Kind. Trade-off: menos ingeniería inicial, más opinionamiento.

Lo que **no** cubre (se verá después):

- Modelado profundo del catálogo (`catalog-info.yaml`, kinds, relaciones) → `plat-05`.
- Templates / scaffolder → `plat-06`.
- TechDocs → `plat-07`.
- Plugins (instalar y escribir uno propio) → `plat-08`.

Las dos actividades son **independientes** entre sí. Pueden hacerse como *walkthrough* documental si no tienes `node 20+`, `docker` o `helm` en tu máquina — los validadores detectan la ausencia de herramientas y hacen SKIP limpio, pidiendo únicamente el entregable Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`**:
  - `01-create-app-and-run/` — walkthrough comentado de `npx @backstage/create-app`, qué genera, cómo lanzarlo.
  - `02-app-config-structure/` — anatomía de `app-config.yaml` y el merge por capas.
  - `03-backend-system-1/` — patrón Backend System 1.0, `createBackendModule`, inyección de dependencias.
- **`activities/`** (independientes):
  - `01-local-backstage-with-github-auth/` — producir `BACKSTAGE-SETUP.md` que documenta create-app + capas de config + auth GitHub + Postgres + diagrama de componentes. Si hay `node 20+` opcionalmente se corre `create-app`.
  - `02-k8s-deploy-via-helm/` — producir `HELM-DEPLOY.md` + `values.yaml` del chart oficial. Si hay `helm` opcionalmente se renderiza el chart (dry-run).
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué Backstage es un framework, no una app. Enumerar los paquetes del monorepo y qué hace cada uno. |
| Operativa | Levantar un Backstage local con auth GitHub + Postgres (al menos documentado si no hay runtime). Preparar un `values.yaml` del chart oficial para deploy en K8s. |
| Arquitectónica | Comparar Backstage self-hosted vs CNOE pre-ensamblada y defender la elección con costos reales. |

## Criterios de evaluación

- Describe la salida de `npx @backstage/create-app` (3 paquetes, scripts clave, puertos por defecto).
- Explica el orden de merge de `app-config*.yaml`.
- Lista 3 providers de auth soportados y dónde se configuran.
- Nombra 2 breaking changes históricos de Backstage y por qué la política de upgrade es parte del trabajo.
- Entrega las 2 actividades con sus validadores en verde (o SKIP limpio por falta de herramientas).

## Entregables

- `BACKSTAGE-SETUP.md` con el walkthrough de create-app + config + auth GitHub + Postgres + diagrama.
- `HELM-DEPLOY.md` + `values.yaml` listos para `helm install` (aunque no se ejecute).

## Siguiente módulo

→ `plat-05-software-catalog-deep` — modelar el software de la organización con el catálogo de Backstage.
