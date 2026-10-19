# Ejemplo 02 — Review App por Merge Request

## Objetivo

Ver el patron canonico de Review Apps: un environment efimero por MR, con URL dinamica, `on_stop:` y `auto_stop_in:`.

## El `.gitlab-ci.yml`

```yaml
stages:
  - build
  - review

build:
  stage: build
  script:
    - mkdir -p dist && echo "mr-$CI_MERGE_REQUEST_IID" > dist/index.html
  artifacts:
    paths:
      - dist/
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

review:
  stage: review
  needs: [build]
  script:
    - echo "Desplegando preview para MR !$CI_MERGE_REQUEST_IID"
    - ./deploy_preview.sh "mr-$CI_MERGE_REQUEST_IID" dist/
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    url: https://mr-$CI_MERGE_REQUEST_IID.preview.example.com
    on_stop: stop_review
    auto_stop_in: 7 days
    deployment_tier: development
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

stop_review:
  stage: review
  script:
    - echo "Destruyendo preview mr-$CI_MERGE_REQUEST_IID"
    - ./destroy_preview.sh "mr-$CI_MERGE_REQUEST_IID"
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    action: stop
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: manual
  allow_failure: true
```

## Que pasa en GitLab

1. Alguien abre MR !42. GitLab dispara el pipeline con `CI_PIPELINE_SOURCE == "merge_request_event"` y `CI_MERGE_REQUEST_IID == 42`.
2. `build` compila; `review` ejecuta `deploy_preview.sh mr-42`.
3. GitLab crea el environment `review/mr-42` con URL `https://mr-42.preview.example.com`.
4. El MR !42 muestra el widget "View app" apuntando a esa URL.
5. En **Operate > Environments** aparece la carpeta `review/` con `mr-42` dentro.

## Ciclo de vida del environment

- **Nuevos commits al MR**: cada push vuelve a correr `review`, actualiza el preview, reinicia el reloj de `auto_stop_in`.
- **MR cerrado o mergeado**: GitLab dispara automaticamente `stop_review` (el job declarado en `on_stop:`).
- **7 dias sin actividad**: `auto_stop_in` dispara `stop_review` tambien.
- **Fallo en `stop_review`**: `allow_failure: true` evita bloquear el pipeline; el environment queda `failed_to_stop` y aparece en la UI para intervencion manual.

## Las reglas invisibles de `on_stop:`

- El nombre del environment en `review` y en `stop_review` debe ser **identico** (`review/mr-$CI_MERGE_REQUEST_IID`). Si difieren, GitLab no reconoce la relacion.
- `stop_review` **debe** tener `action: stop`.
- Normalmente lleva `when: manual` o similar — no corre en el flujo "forward" del pipeline; se dispara como handler.
- Buena practica: `allow_failure: true` + un hook externo que vigile `failed_to_stop` para alertar.

## Comparacion con GitHub Actions

En GHA, lo equivalente requiere:

- Un workflow en `on: pull_request` que despliega.
- Un workflow separado en `on: pull_request: types: [closed]` que destruye.
- Un cron workflow (`on: schedule`) que recorre PRs abandonados y los limpia.
- Metadata manual (comentarios, labels) para pegar la URL en el PR.

Suele ser 100-200 lineas repartidas en 3 workflows. En GitLab son ~25 lineas en un solo archivo. **No es que GHA no pueda; es que GitLab lo tiene como primitivo**.

## Lectura recomendada

- `../../theory/lesson.md` §4-5 (Review Apps + `auto_stop_in:`).
