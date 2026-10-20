# Starter — gl-02-01

## Qué hay aquí

- `.github/workflows/hello.yml` — el workflow origen de GitHub Actions que debes **portar** a `.gitlab-ci.yml`.

## Paso a paso recomendado

1. Lee `hello.yml` y anota mentalmente el mapping:
   - `on: push + pull_request` → `workflow:rules:` con `$CI_PIPELINE_SOURCE` o un `rules:` por job.
   - `jobs.lint`, `jobs.test`, `jobs.build` → tres jobs en GitLab, cada uno con `stage:`.
   - `needs: [lint]` / `needs: [test]` → en GitLab el orden lo da `stages:` (sin `needs:` aún; `needs:` real es `gl-04`).
   - `container: python:3.12` → `image: python:3.12`.
   - `actions/checkout@v4` → **no se necesita**: GitLab clona el repo automáticamente en cada job.
   - `actions/upload-artifact` → en GitLab es `artifacts:` del job (puedes omitirlo en esta actividad; no lo exige el validador).
2. Crea `/tmp/gl-02-01/.gitlab-ci.yml` con tu port.
3. Corre `bash tests/validate.sh /tmp/gl-02-01`.

## Pistas que no son trampa

- `stages:` como lista explícita de 3 strings.
- `script:` siempre lista.
- Un job sin `image:` hereda del `default:` si lo hay — es idiomático.
- Para disparar en push a `main` y en MR:
  ```yaml
  workflow:
    rules:
      - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      - if: '$CI_COMMIT_BRANCH == "main"'
  ```
