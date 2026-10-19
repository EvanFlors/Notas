# Starter — gl-08-01-pipeline-with-scanners

Esta actividad es **independiente**. Produces `.gitlab-ci.yml` + `NOTES.md`.

## Pasos

1. Lee `../README.md` y recorre `../../examples/01-enable-all-security-templates/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-08-scanners
   cd /tmp/gl-08-scanners
   ```
3. Escribe `.gitlab-ci.yml` con:
   - `stages:` incluyendo `test`.
   - `workflow:rules` para evitar pipelines duplicados.
   - `include:` con al menos 5 `template: Jobs/*.gitlab-ci.yml`.
   - `variables:` con al menos una de `SAST_EXCLUDED_PATHS`, `DS_EXCLUDED_PATHS`, `CS_IMAGE`.
4. Verifica sintaxis:
   ```bash
   python3 -c 'import yaml; yaml.safe_load(open(".gitlab-ci.yml"))'
   ```
5. Escribe `NOTES.md` con las secciones:
   - `## Por que include:template`
   - `## Required vs advisory`
   - `## Bloqueo por severidad`
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/08-security-scanners-registry-and-supply-chain/activities/01-pipeline-with-scanners/tests/validate.sh /tmp/gl-08-scanners
   ```

## Esqueleto sugerido

```yaml
stages:
  - build
  - test
  - deploy

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

include:
  - template: Jobs/SAST.gitlab-ci.yml
  # ... completa 4 mas

variables:
  SAST_EXCLUDED_PATHS: "spec,test,tests,tmp,vendor,.venv,node_modules"
```
