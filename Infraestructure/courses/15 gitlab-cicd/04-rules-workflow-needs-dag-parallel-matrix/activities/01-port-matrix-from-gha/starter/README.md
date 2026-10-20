# Starter — gl-04-01-port-matrix-from-gha

Esta actividad es **independiente**: no hay repo clonado ni runner. Tu entregable es un `.gitlab-ci.yml` escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo (especialmente `03-parallel-matrix`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-04-01
   cd /tmp/gl-04-01
   ```
3. Crea `.gitlab-ci.yml` con:
   - `workflow:` top-level (al menos: MR, main, no duplicar en branch con MR abierto).
   - `test:` con `parallel: matrix:` expandiendo exactamente **6 combinaciones** (recuerda: `exclude` de GHA se expresa como entradas separadas).
   - `rules:` por job con `if:` **y** `changes:`.
4. Valida:
   ```bash
   python3 -c "import yaml,sys; yaml.safe_load(open('/tmp/gl-04-01/.gitlab-ci.yml'))"
   bash <ruta-repo>/courses/gitlab-cicd/04-rules-workflow-needs-dag-parallel-matrix/activities/01-port-matrix-from-gha/tests/validate.sh /tmp/gl-04-01
   ```
5. Compara con `../solution/.gitlab-ci.yml` para autoevaluarte.

## Plantilla sugerida (opcional)

```yaml
# .gitlab-ci.yml

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

stages:
  - test

test:
  stage: test
  image: python:$PY_VERSION
  tags:
    - $OS_TAG
  parallel:
    matrix:
      # Rellena aquí las entradas que expanden a 6 combinaciones.
      # Pista: hay un valor de py (3.11) que NO corre en linux-arm64.
      #        hay una entrada extra (3.13, macos).
      - PY_VERSION: ["..."]
        OS_TAG: ["..."]
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - "src/**/*"
        - "tests/**/*"
        - "pyproject.toml"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        - "src/**/*"
        - "tests/**/*"
        - "pyproject.toml"
  script:
    - python --version
    - pip install -e .[test]
    - pytest -q
```

> No copies esta plantilla sin pensar: faltan las entradas de `matrix:`. Esa es la parte didáctica del ejercicio.
