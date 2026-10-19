# REFERENCE — gl-08-01-pipeline-with-scanners

> Una **referencia** razonada. No es la única respuesta correcta.

---

## `.gitlab-ci.yml`

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
  - template: Jobs/Secret-Detection.gitlab-ci.yml
  - template: Jobs/Dependency-Scanning.gitlab-ci.yml
  - template: Jobs/Container-Scanning.gitlab-ci.yml
  - template: Jobs/SAST-IaC.gitlab-ci.yml

variables:
  SECURE_LOG_LEVEL: "info"
  SAST_EXCLUDED_PATHS: "spec,test,tests,tmp,vendor,.venv,node_modules"
  DS_EXCLUDED_PATHS: "spec,test,tests,tmp"
  CS_IMAGE: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"

build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:v1.21.0-debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
        --context "$CI_PROJECT_DIR"
        --dockerfile "$CI_PROJECT_DIR/Dockerfile"
        --destination "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
```

## `NOTES.md`

```markdown
# Notas — gl-08-01

## Por que include:template y no copiar el YAML

Los templates viven en `gitlab-org/gitlab` y evolucionan por release. Copiar
congela el scanner en una version concreta; `include:template:` resuelve en
el server contra la ultima version disponible. Para un fix critico de SAST
publicado hoy, la unica accion requerida es correr un nuevo pipeline.

## Required vs advisory

Para una API Python en prod:

- **Required** (fallan el pipeline en MR):
  - Secret-Detection (si hay un secreto, es siempre un stop-ship).
  - SAST (Semgrep contra codigo propio).
  - Dependency-Scanning (CVEs en requirements.txt).
- **Advisory** (reportan pero no bloquean):
  - Container-Scanning (muchos CVEs vienen de la base image; se mitigan por rebuild semanal).
  - SAST-IaC (si hay poca IaC, el ruido domina).

## Bloqueo por severidad

En plan Ultimate: `Settings -> Merge requests -> Merge checks -> Require
approval if High/Critical vulnerabilities introduced`. En Free/Premium:
job custom que lee `gl-sast-report.json` con `jq` y falla si existe algun
finding `severity: Critical|High` nuevo respecto a target branch.
```
