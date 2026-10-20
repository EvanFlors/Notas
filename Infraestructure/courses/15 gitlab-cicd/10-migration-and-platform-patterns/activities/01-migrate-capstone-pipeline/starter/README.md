# Starter — gl-10-01-migrate-capstone-pipeline

Esta actividad es **independiente**. Entregas dos archivos escritos por ti.

## Pasos

1. Lee `../README.md` y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-10-migration
   cd /tmp/gl-10-migration
   ```
3. Crea `.gitlab-ci.yml` con, al menos:
   - `stages:` y `workflow:`.
   - 3 jobs (lint/test/build).
   - `parallel: matrix:` en el job de test.
   - `needs:` para construir DAG.
   - `id_tokens:` con `aud:` en el job que despliega.
   - `rules:` filtrando por `$CI_COMMIT_BRANCH == "main"` donde corresponda.
   - `image:` declarado.
4. Crea `MIGRATION-ADR.md` con las 6 secciones:
   - `# ADR ...` + `## Estado` + `## Contexto` + `## Decisión` + `## Consecuencias` + `## Alternativas descartadas`.
   - Mapping GHA↔GitLab (tabla o lista).
   - Mención de CI/CD Component / catálogo interno.
   - Plan de dual-run con criterios de corte.
   - Trust policy nueva (bloque de código) con pinning por `project_path`/`ref_type`/`ref`.
   - 2+ alternativas descartadas.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/10-migration-and-platform-patterns/activities/01-migrate-capstone-pipeline/tests/validate.sh /tmp/gl-10-migration
   ```
6. Compara con `../solution/REFERENCE.md`.

> El validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Esqueleto sugerido del `.gitlab-ci.yml`

```yaml
stages: [lint, test, build]

default:
  image: node:20

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

lint:
  stage: lint
  script:
    - npm ci
    - npm run lint

test:
  stage: test
  needs: [lint]
  parallel:
    matrix:
      - NODE_VERSION: ["18", "20"]
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm test -- --coverage

build-and-push:
  stage: build
  needs: [test]
  image: docker:27
  services: [docker:27-dind]
  id_tokens:
    AWS_ID_TOKEN:
      aud: https://gitlab.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  script:
    # OIDC a AWS vía ID Token (ver ADR)
    - echo "assume-role-with-web-identity..."
    - echo "docker build && docker push..."
```

## Esqueleto sugerido del ADR

```markdown
# ADR 010 — Migración my-org/api-checkout de GHA a GitLab

## Estado
Propuesto

## Contexto
<por qué migramos, constraints: compliance, catálogo interno, etc.>

## Decisión

### Mapping GHA → GitLab
| GHA | GitLab |
|-----|--------|
| `on: push/pull_request` | `workflow: rules:` |
| `strategy.matrix` | `parallel: matrix` |
| `aws-actions/configure-aws-credentials` | `id_tokens:` + `aws sts assume-role-with-web-identity` |
| `${{ github.sha }}` | `$CI_COMMIT_SHA` |

### Trust policy AWS (nueva)
```json
{
  "StringEquals": {
    "gitlab.com:aud": "https://gitlab.com",
    "gitlab.com:project_path": "my-org/api-checkout",
    "gitlab.com:ref_type": "branch",
    "gitlab.com:ref": "main"
  }
}
```

### CI/CD Component
<qué bloque promovemos al catálogo interno, con qué contrato>

### Plan de dual-run
<2–4 semanas de solape, criterios de corte>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: *big-bang* sin dual-run
- Por qué no: ...
### Alt B: inline del `aws sts` en cada job sin componente
- Por qué no: ...
```
