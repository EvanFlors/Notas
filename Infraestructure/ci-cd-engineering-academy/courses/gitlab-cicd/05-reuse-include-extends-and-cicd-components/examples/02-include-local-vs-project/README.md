# Ejemplo 02 — `include: local` vs `project` vs `remote` vs `template`

> Lectura y análisis. Mismo pipeline servido con las 4 variantes de `include:` para fijar el criterio de elección.

## 1. Caso base

El equipo `web/` tiene este `.gitlab-ci.yml`:

```yaml
stages: [test, build, deploy]

test:
  stage: test
  image: node:20-alpine
  script: [npm ci, npm test]

build:
  stage: build
  image: node:20-alpine
  script: [npm run build]
  artifacts:
    paths: [dist/]

deploy:
  stage: deploy
  image: curlimages/curl
  script: [curl -X POST "$DEPLOY_HOOK"]
```

Queremos reutilizar `test` + `build` (`deploy` cambia por entorno).

## 2. Variante A — `include: local:` (mismo repo)

Partimos el archivo:

```
web/
├── .gitlab-ci.yml
└── .gitlab/ci/
    └── node-common.yml
```

`.gitlab/ci/node-common.yml`:
```yaml
.node-base:
  image: node:20-alpine

test:
  extends: .node-base
  stage: test
  script: [npm ci, npm test]

build:
  extends: .node-base
  stage: build
  script: [npm run build]
  artifacts:
    paths: [dist/]
```

`.gitlab-ci.yml`:
```yaml
stages: [test, build, deploy]

include:
  - local: .gitlab/ci/node-common.yml

deploy:
  stage: deploy
  image: curlimages/curl
  script: [curl -X POST "$DEPLOY_HOOK"]
```

**Cuándo**: dividir un archivo que ya pesa demasiado dentro del mismo repo. **Costo**: cero, nada versionado, cambia con el mismo commit del consumidor.

## 3. Variante B — `include: project:` (otro repo del mismo grupo)

Movemos `node-common.yml` al repo `platform/ci-shared`:

```
platform/ci-shared/
└── jobs/
    └── node-common.yml
```

El consumidor `web/.gitlab-ci.yml`:
```yaml
stages: [test, build, deploy]

include:
  - project: 'platform/ci-shared'
    ref: 'v1.4.0'        # tag inmutable, NUNCA 'main' en prod
    file: '/jobs/node-common.yml'

deploy:
  stage: deploy
  image: curlimages/curl
  script: [curl -X POST "$DEPLOY_HOOK"]
```

**Cuándo**: hasta ~5 repos del mismo grupo. **Costo**: necesita permiso de lectura al proyecto fuente; sin `ref:` fijo, cualquier push rompe consumidores.

**Trampa frecuente**: no tiene `inputs`. Si `node-common.yml` espera `NODE_VERSION`, el consumidor lo descubre leyendo el YAML del proveedor. Para contrato, pasa al componente.

## 4. Variante C — `include: remote:` (URL pública)

```yaml
include:
  - remote: 'https://example.com/ci/node.yml'
```

**Cuándo**: casi nunca en 2026. Si el YAML es público y versionado, publícalo como componente. Si es privado, usa `include: project:`.

**Problemas**: sin ref (`main` implícito del hosting), sin contrato, sin disponibilidad garantizada (DNS cae → tus pipelines caen).

## 5. Variante D — `include: template:` (templates oficiales)

Para scanners de seguridad:

```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Jobs/Code-Quality.gitlab-ci.yml
```

**Cuándo**: siempre que exista un template oficial para lo que necesitas. GitLab los versiona con la plataforma; no requieren `ref:`. Lista completa: `https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/gitlab/ci/templates`.

## 6. Resumen comparativo

| Variante | Contrato (`inputs`) | Versionado | Visibilidad | Recomendado para |
|----------|---------------------|------------|-------------|------------------|
| `local` | No | Commit del repo | Interno al repo | Partir archivos grandes. |
| `project` | No | `ref:` (tag/branch/SHA) | Grupo | 2–5 consumidores cercanos. |
| `remote` | No | Ninguno estable | Público | **Nada en 2026** (legacy). |
| `template` | No (ya versionado por GitLab) | Versión de GitLab | Universal | Scanners oficiales. |
| **component** (ejemplo 03) | **Sí (`spec:inputs:`)** | **Tag SemVer** | Catalog (grupo/público) | **>5 consumidores o cross-grupo.** |

## 7. Qué leer después

- `../03-cicd-component-publish-and-consume/` — subir el nivel: contrato tipado, versionado, Catalog.
