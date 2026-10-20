# Ejemplo 01 — `environment:` con URL y aparicion en la UI

## Objetivo

Ver el minimo `.gitlab-ci.yml` que convierte un script de deploy en un **objeto Deployment** del dominio GitLab.

## El `.gitlab-ci.yml` minimo

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  script:
    - echo "Compilando artefacto para $CI_COMMIT_SHORT_SHA"
    - mkdir -p dist && echo "ok" > dist/index.html
  artifacts:
    paths:
      - dist/

deploy_staging:
  stage: deploy
  script:
    - echo "Subiendo dist/ a https://staging.example.com"
  environment:
    name: staging
    url: https://staging.example.com
    deployment_tier: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

## Que pasa en GitLab cuando esto corre

1. El job `deploy_staging` termina en verde.
2. GitLab crea (si no existe) el objeto `Environment` llamado `staging`.
3. GitLab registra un objeto `Deployment` con:
   - `iid`: auto-incremental dentro del environment.
   - `ref`: `main` (porque la rule lo filtra a default branch).
   - `sha`: el commit desplegado.
   - `user`: quien lanzo el pipeline.
   - `status`: `success`.
   - `environment.url`: `https://staging.example.com`.

## Donde se ve en la UI

- **Operate > Environments** — lista `staging` con el link `View deployment`.
- Dentro del environment, pestana **Deployments** — historial con `Re-deploy` y `Rollback` por entrada.
- En el **Merge Request** (si aplica), widget "View app" apunta a la URL.
- La API lo devuelve: `GET /projects/:id/environments` y `GET /projects/:id/deployments`.

## Que pasaria sin `environment:`

El script correria igual y publicaria el artefacto, pero:

- No habria entrada en **Operate > Environments**.
- No habria boton de `Rollback`.
- El MR no mostraria "View app".
- Las metricas DORA (`deployment_frequency`) no lo contarian.
- El dia que alguien pregunte "¿que sha hay en staging ahora mismo?" tendrias que leer logs.

## Variantes utiles

- **URL dinamica por rama**: `url: https://${CI_COMMIT_REF_SLUG}.staging.example.com`.
- **`deployment_tier`**: valores validos `production | staging | testing | development | other`. Afecta como la UI agrupa y como las metricas DORA clasifican.
- **`environment:` como string corto**: `environment: staging` es equivalente a `environment: { name: staging }` sin url.

## Lectura recomendada

- `../../theory/lesson.md` §1-3 (modelo, keywords, deployments como historia).
