# REFERENCE — gl-07-01-review-apps-end-to-end

> Una **referencia** razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

## `.gitlab-ci.yml`

```yaml
stages:
  - build
  - review

variables:
  PREVIEW_HOST_SUFFIX: "preview.example.com"

build:
  stage: build
  image: node:20-alpine
  script:
    - echo "Compilando frontend para MR !$CI_MERGE_REQUEST_IID"
    - mkdir -p dist && echo "mr-$CI_MERGE_REQUEST_IID @ $CI_COMMIT_SHORT_SHA" > dist/index.html
  artifacts:
    paths:
      - dist/
    expire_in: 1 day
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

review:
  stage: review
  needs: [build]
  script:
    - echo "Desplegando preview mr-$CI_MERGE_REQUEST_IID"
    - ./deploy_preview.sh "mr-$CI_MERGE_REQUEST_IID" dist/
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    url: https://mr-$CI_MERGE_REQUEST_IID.$PREVIEW_HOST_SUFFIX
    on_stop: stop_review
    auto_stop_in: 3 days
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

Decisiones:

- `auto_stop_in: 3 days`: suficiente para cubrir fin de semana + lunes, corto para no dejar previews zombies si el MR queda abandonado.
- `environment.name` identico en `review` y `stop_review` — requisito para que `on_stop:` funcione.
- `stop_review` con `when: manual` + `allow_failure: true`: no bloquea el pipeline y permite re-dispararlo desde la UI si el teardown falla.
- `needs: [build]` en `review`: DAG para que `review` arranque cuando `build` termine, sin esperar al stage completo.

---

# ADR 001 — Review Apps por MR en GitLab

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras feedback del equipo frontend y materializado con los scripts `deploy_preview.sh` + `destroy_preview.sh` ya existentes.

## Contexto

El equipo frontend de 6 ingenieros abre 10-20 MRs/semana en `web-frontend`. Hoy, para revisar visualmente un MR, el reviewer debe:

1. Hacer `git fetch` y `git checkout` de la rama.
2. `pnpm install` (tarda 2-4 min por lockfile grande).
3. `pnpm dev` (tarda 1-2 min adicionales).
4. Resolver conflictos de puerto si ya tenia otro MR abierto.

Esto rompe el contexto del reviewer y, en la practica, hace que los reviews se vuelvan "pattern matching del diff" en lugar de verificaciones reales del comportamiento. Queremos un **preview URL por MR** automatico, con URL estable (`https://mr-<N>.preview.example.com`), que se actualice en cada push y se destruya al cerrar el MR.

Constraints:

- El bucket S3 por preview cuesta ~0.1 USD/mes, pero un bucket vivo olvidado durante un año son 12 USD × N previews. Con 20 MRs/mes historicos, el riesgo es real.
- No tenemos presupuesto para montar un servicio de preview propio (y mantenerlo).
- El equipo ya usa GitLab SaaS; no vamos a migrar.

## Decision

Usar **Review Apps nativas de GitLab** con el patron canonico:

```yaml
review:
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    url: https://mr-$CI_MERGE_REQUEST_IID.preview.example.com
    on_stop: stop_review
    auto_stop_in: 3 days
```

Puntos de la decision:

- **`CI_MERGE_REQUEST_IID`** como identificador estable del environment — garantiza unicidad por MR y colisiona 0.
- **`on_stop: stop_review`** engancha el teardown al cierre del MR y a la expiracion de `auto_stop_in`.
- **`auto_stop_in: 3 days`** elegido como balance entre "no se apaga durante un review que tarda el fin de semana" y "no acumula coste si el MR queda abandonado".
- **`allow_failure: true` en `stop_review`** para que un fallo de teardown no bloquee pipelines futuros; se vigila `failed_to_stop` en la UI.

Pipeline completo documentado en el `.gitlab-ci.yml` adjunto.

## Consecuencias

Positivas:

- Reviewer entra al MR, aprieta "View app" y ve el cambio en 5 segundos.
- Tiempo de review por MR cae de ~15 min a ~5 min estimado (equipo valida).
- Las `auto_stop_in` + `on_stop:` resuelven la higiene de recursos sin cron jobs externos.
- El dia que escalemos a 50+ MRs/semana, el patron no cambia.

Negativas / costo:

- Cada MR activo consume minutos de runner adicionales (el `review` job tarda ~2 min; con 50 MRs/mes son ~100 min/mes extra).
- Si `destroy_preview.sh` falla y nadie mira `failed_to_stop`, se acumulan buckets. Mitigacion: alerta semanal de Grafana sobre `gitlab_environment_failed_to_stop_total`.
- El URL es publico (no hay auth basica delante). Si el preview tuviera secretos reales seria un problema; aqui son datos sinteticos. Documentar en el runbook.

## Alternativas descartadas

### 1. Patron equivalente en GitHub Actions

Replicar el patron en GHA requeriria:

- Workflow en `on: pull_request` para desplegar.
- Workflow separado en `on: pull_request: types: [closed]` para destruir.
- Workflow `on: schedule` (cron diario) para limpiar previews que escaparon.
- Comentarios bot en el PR para pegar la URL.

~150 lineas repartidas en 3 workflows + logica de recuperacion. Descartado porque **ya estamos en GitLab**; la alternativa solo tendria sentido en una migracion planeada a GitHub, que no esta en el roadmap.

### 2. Preview manual via `docker compose` en la laptop del reviewer

Es el status quo. Descartado porque:

- Rompe el flujo del reviewer (context switch de 10-15 min).
- No permite compartir el preview con un stakeholder no tecnico (producto, diseño).
- Requiere que el reviewer tenga Node y el stack local funcionando, lo cual rompe cada vez que subimos version mayor.

### 3. Servicio de preview propio (Vercel-like interno)

Montar un servicio que escuche webhooks de GitLab y despliegue a un cluster propio. Descartado por coste de operacion (al menos 0.5 FTE para mantenerlo) y porque reinventa lo que `environment: + on_stop: + auto_stop_in:` ya hace nativamente.

---

## Notas de implementacion

- Los scripts `deploy_preview.sh` y `destroy_preview.sh` ya existen en `tools/` del repo.
- Las variables `AWS_*` para que el runner autentique a S3 se montan via **ID Token / OIDC** (ver `gl-03` y `gl-06`); no se hardcodean.
- Revisar en 30 dias si `auto_stop_in: 3 days` es correcto. Si vemos previews apagados durante reviews activos, subir a `5 days`.
