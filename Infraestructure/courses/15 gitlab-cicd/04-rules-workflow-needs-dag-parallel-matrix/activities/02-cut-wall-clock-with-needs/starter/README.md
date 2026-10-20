# Starter — gl-04-02-cut-wall-clock-with-needs

Esta actividad es **independiente**: no hay repo clonado ni runner. Tu entregable son un `.gitlab-ci.yml` reescrito y un `WALL-CLOCK.md` justificando la ganancia.

## Pasos

1. Lee `../README.md` y recorre `examples/02-dag-with-needs/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-04-02
   cd /tmp/gl-04-02
   ```
3. Crea `.gitlab-ci.yml` con 6 jobs (`build-amd64`, `build-arm64`, `lint`, `unit-tests`, `integration-tests`, `deploy-stg`) y declara `needs:` según la tabla "depende realmente de" del enunciado.
4. Crea `WALL-CLOCK.md` con cálculo lineal vs DAG, cifras explícitas y al menos una decisión justificada.
5. Valida:
   ```bash
   python3 -c "import yaml,sys; yaml.safe_load(open('/tmp/gl-04-02/.gitlab-ci.yml'))"
   bash <ruta-repo>/courses/gitlab-cicd/04-rules-workflow-needs-dag-parallel-matrix/activities/02-cut-wall-clock-with-needs/tests/validate.sh /tmp/gl-04-02
   ```
6. Compara con `../solution/` para autoevaluarte.

## Esqueleto sugerido (opcional)

```yaml
stages: [build, test, deploy]

build-amd64:
  stage: build
  script: echo "build amd64"

build-arm64:
  stage: build
  script: echo "build arm64"

lint:
  stage: test
  needs: []     # linter no depende de nada
  script: echo "lint"

unit-tests:
  stage: test
  needs: ["..."]
  script: echo "unit"

integration-tests:
  stage: test
  needs: ["...", "..."]
  script: echo "integration"

deploy-stg:
  stage: deploy
  needs: ["..."]   # ¡sólo las deps reales!
  script: echo "deploy stg"
```

Rellena los `...` con los nombres de los jobs correctos según la tabla del enunciado.
