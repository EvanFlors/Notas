# Starter — gl-03-01-least-privilege-variables

Produces 2 archivos: `variables.yml` (documentación estructurada) y `.gitlab-ci.yml` (pipeline que las consume).

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/01-group-vs-project-var/` y `02-protected-and-masked/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-03-01
   cd /tmp/gl-03-01
   ```
3. Escribe `variables.yml` con **las 6 variables mínimas** listadas en el README (`INTERNAL_REGISTRY_URL`, `DOCKER_HUB_READER_TOKEN`, `STG_API_KEY`, `PROD_DEPLOY_ROLE_ARN`, `PROD_API_KEY`, `GCP_SA_JSON`). Cada entrada con: `name`, `scope`, `environment_scope`, `type`, `protected`, `masked`, `example_value`, `justification`.
4. Verifica que es YAML válido:
   ```bash
   python3 -c "import yaml,sys; yaml.safe_load(open('variables.yml'))" && echo OK
   ```
5. Escribe `.gitlab-ci.yml` con los 3 jobs mínimos (`deploy-dev`, `deploy-stg`, `deploy-prod`) y `stages: [deploy]`. Cada job con su `environment:` y referencias a las variables correspondientes (usa `$VAR_NAME` en los `script:`).
6. Verifica:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))" && echo OK
   ```
7. Valida:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/03-variables-and-secrets-protected-and-masked/activities/01-least-privilege-variables/tests/validate.sh /tmp/gl-03-01
   ```
8. Compara con `../solution/` para autoevaluarte.

## Nunca pongas valores reales

Para los `example_value` sensibles usa placeholders:
- `dummy-stg-token-xxxxxxxx`
- `arn:aws:iam::123456789012:role/REPLACE-ME`
- `REPLACE_IN_GITLAB_UI`

El validador no inspecciona si los valores son dummy o no, pero la actividad lo exige por disciplina: nunca commiter secretos reales, ni siquiera en documentación.

## Esqueleto sugerido para `variables.yml`

```yaml
variables:
  - name: INTERNAL_REGISTRY_URL
    scope: group
    environment_scope: "*"
    type: variable
    protected: false
    masked: false
    example_value: "registry.internal.acme.com"
    justification: "URL del registry interno..."
  # ... 5 variables mas
```

## Esqueleto sugerido para `.gitlab-ci.yml`

```yaml
stages:
  - deploy

deploy-dev:
  stage: deploy
  image: alpine:3.20
  environment:
    name: development
  rules:
    - if: $CI_COMMIT_BRANCH
  script:
    - echo "Pulling from $INTERNAL_REGISTRY_URL"

deploy-stg:
  stage: deploy
  image: alpine:3.20
  environment:
    name: staging
  rules:
    - if: $CI_COMMIT_BRANCH == "staging"
  script:
    - echo "Using STG_API_KEY (masked)"
    - echo "Using DOCKER_HUB_READER_TOKEN (masked)"

deploy-prod:
  stage: deploy
  image: alpine:3.20
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  script:
    - echo "Deploy role $PROD_DEPLOY_ROLE_ARN"
    - echo "Using PROD_API_KEY"
    - echo "GCP SA at $GCP_SA_JSON (file-type)"
```
