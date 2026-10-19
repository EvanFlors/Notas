# Solución de referencia — gl-02-01

> Usa esta referencia **después** de haber intentado la actividad. El validador comprueba estructura, no identidad textual: tu solución puede diferir y seguir siendo correcta.

## `.gitlab-ci.yml` propuesto

```yaml
# Port of .github/workflows/hello.yml to GitLab CI/CD.
# Equivalent trigger: push to main + merge requests.
workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

stages:
  - lint
  - test
  - build

default:
  tags: [saas-linux-small-amd64]

lint-shell:
  stage: lint
  image: koalaman/shellcheck-alpine:stable
  script:
    - shellcheck scripts/*.sh || true

pytest:
  stage: test
  image: python:3.12
  script:
    - pip install -r requirements.txt
    - pytest -q

build-tarball:
  stage: build
  script:
    - mkdir -p dist
    - tar -czf dist/app.tgz .
  artifacts:
    paths:
      - dist/app.tgz
    expire_in: 1 week
```

## Decisiones y por qué

1. **`workflow:rules:` arriba, no `rules:` por job.** El equivalente de `on:` de GHA es un filtro de pipeline *entero*; `workflow:` es la traducción correcta. Si cada job filtrara por su cuenta, duplicarías la lógica y correrías el riesgo de que algunos jobs se creen y otros no.
2. **`stages:` explícito.** El default (`[.pre, build, test, deploy, .post]`) no tiene `lint`, así que lo declaramos.
3. **`default: tags: [saas-linux-small-amd64]`.** En `gitlab.com` SaaS esto es *idiomático*: todos los jobs heredan y no hay que repetir. En self-managed podrías cambiarlo a `[docker, linux]`.
4. **`image:` solo donde aporta valor.** `lint-shell` usa una imagen con `shellcheck` preinstalado; `pytest` usa `python:3.12`; `build-tarball` no necesita imagen especial y hereda la default del runner.
5. **No `actions/checkout`.** GitLab clona el repo automáticamente en cada job (configurable con `GIT_STRATEGY`).
6. **`artifacts:`** reemplaza `upload-artifact`. `expire_in: 1 week` evita acumular storage.
7. **Sin `only/except`.** Deprecados — `rules:` moderno.

## Diferencias de modelo que no son obvias

- En GHA cada `step` es un bloque independiente con su propio reporting. En GitLab `script:` es *un* bloque; se recomienda que cada comando sea una línea de la lista para que la UI los muestre separados.
- `needs: [lint]` en GHA ordena jobs. En GitLab, aquí, lo da `stages:`. Si quisieras un DAG (p. ej. `build-tarball` depende solo de `pytest`), añadirías `needs: [pytest]` — eso es `gl-04`.

## Checklist de autoevaluación

- [ ] Tu YAML parsea con `python3 -c 'import yaml; yaml.safe_load(open("/tmp/gl-02-01/.gitlab-ci.yml"))'`.
- [ ] Tienes 3 stages y ≥3 jobs.
- [ ] Al menos un job con `image:`.
- [ ] Cero ocurrencias de `only:` / `except:`.
- [ ] Mencionas `main` o `merge_request` en el filtro.
- [ ] Nombres de job descriptivos.
