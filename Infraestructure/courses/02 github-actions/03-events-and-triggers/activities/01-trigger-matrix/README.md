# gha-03-01 — Mini-catálogo propio de triggers

## 1. Identificación

- **ID:** `gha-03-01-trigger-matrix`
- **Tecnología:** `github-actions`
- **Módulo:** `03-events-and-triggers`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Antes de construir pipelines reales conviene fijar el repertorio: cuántos triggers hay, qué filtros admiten y para qué escenarios se eligen. Esta actividad te hace **escribir** 5 workflows pequeños — cada uno con un trigger distinto — y acompañar cada uno con 2–3 líneas de "cuándo usarlo".

El entregable es un directorio `workflows/` dentro de un repo scratch en `/tmp/` con esos 5 YAMLs, estructuralmente válidos y con los filtros correctos.

## 3. Objetivos

- Elegir, para cada uno de 5 escenarios dados, el trigger adecuado con sus filtros.
- Escribir YAML válido para cada trigger.
- Justificar la elección por escrito en un `README.md` propio dentro de `workflows/`.
- Pasar el validador local.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md`.
- Haber reproducido `examples/01-paths-filter/` y `examples/02-manual-dispatch-with-inputs/`.
- Software: `bash`, `python3` con `pyyaml` (`pip install pyyaml`).
- Opcional: `actionlint` instalado (si falta, el validador lo salta).
- No requiere cuenta de GitHub ni cuesta nada.

## 5. Instrucciones

### Paso 1 — Bootstrap

```bash
bash starter/bootstrap.sh
cd /tmp/trigger-matrix/workflows
```

Esto crea el directorio `/tmp/trigger-matrix/workflows/` con **5 esqueletos** vacíos (`01-ci.yml`, `02-release.yml`, `03-nightly-cleanup.yml`, `04-manual-deploy.yml`, `05-pr-labeler.yml`) y un `README.md` plantilla con los 5 escenarios.

### Paso 2 — Escenarios

Rellena cada uno de los 5 archivos para que cumpla su escenario:

| # | Archivo | Escenario | Trigger esperado |
|---|---------|-----------|------------------|
| 1 | `01-ci.yml` | Correr lint+tests en cada PR al default branch, y en cada push a `main`. Debe ignorar cambios que tocan solo `docs/**`. | `push` + `pull_request` con `paths-ignore` |
| 2 | `02-release.yml` | Publicar un artefacto cuando se **publica** un release en GitHub. | `release` con `types: [published]` |
| 3 | `03-nightly-cleanup.yml` | Limpieza nocturna a las 03:00 UTC diaria. Debe ser también invocable a mano. | `schedule` + `workflow_dispatch` |
| 4 | `04-manual-deploy.yml` | Deploy manual que elija `environment` (dev/staging/prod) y acepte una `tag`. | `workflow_dispatch` con inputs tipados (`choice`, `string`) |
| 5 | `05-pr-labeler.yml` | Etiquetar PRs externos cuando se abren. No hace checkout del PR. Permisos de escritura sobre PRs. | `pull_request_target` con `types: [opened]`, `permissions: pull-requests: write`, **sin** `actions/checkout` |

Para cada archivo:

- Declara `name:`.
- Declara `on:` con filtros precisos.
- Declara `permissions:` explícitas (mínimo privilegio).
- Añade al menos un job con un step `run:` o `uses:` que ilustre qué haría.

### Paso 3 — Documenta tus elecciones

Edita `workflows/README.md` y añade, para cada archivo, 2–3 líneas explicando:

- Por qué ese trigger (no otro).
- Qué filtros usas y por qué.
- Qué permisos necesita y por qué.

### Paso 4 — Validar

Desde el directorio de la actividad:

```bash
bash tests/validate.sh
```

El validador comprueba:

- Los 5 archivos existen y parsean como YAML.
- Cada archivo contiene el trigger esperado (`push`, `release`, `schedule`, `workflow_dispatch`, `pull_request_target`).
- `01-ci.yml` tiene `paths-ignore` (o `paths`).
- `02-release.yml` incluye `types: [published]`.
- `03-nightly-cleanup.yml` tiene **ambos** `schedule` y `workflow_dispatch`.
- `04-manual-deploy.yml` declara al menos un input `type: choice` y uno `type: string`.
- `05-pr-labeler.yml` usa `pull_request_target`, declara `pull-requests: write`, y **no** contiene `actions/checkout`.
- `workflows/README.md` existe y menciona los 5 archivos.
- Si `actionlint` está disponible, lo corre sobre los 5.

## 6. Resultado esperado

- `/tmp/trigger-matrix/workflows/` con 5 `.yml` y un `README.md`.
- Validador reporta `0 FAIL`.

## 7. Criterios de aceptación

- Los 5 workflows son YAML válido y disparan solo en los eventos del escenario.
- `pull_request_target` **nunca** aparece junto a `actions/checkout`.
- `README.md` justifica cada elección en prosa breve.
- Reproducible con `bash starter/bootstrap.sh` + edición + `bash tests/validate.sh`.

## 8. Validación

```bash
# tests
bash tests/validate.sh

# comparar con la solución
diff -ru /tmp/trigger-matrix/workflows solution/workflows   # opcional
```

Si quieres ver la solución de referencia:

```bash
ls solution/workflows/
```

## 9. Preguntas de reflexión

1. En el escenario 1, ¿qué diferencia práctica hay entre `paths-ignore: ['docs/**']` y poner un `if:` en el job que mire `github.event.*`?
2. En el escenario 2, ¿cuándo elegirías `on: push` con `tags: ['v*']` en vez de `on: release`?
3. En el escenario 5, ¿qué consecuencia tendría olvidarte de `permissions:` y dejar el default del repo?

## 10. Extensiones

- Añade un sexto workflow con `workflow_run` que dispare al terminar `01-ci.yml`.
- Añade `concurrency:` a `04-manual-deploy.yml` para que no corran dos deploys al mismo `environment` a la vez.
- Instala `actionlint` (`brew install actionlint` / binario) y vuelve a correr el validador.

## 11. Limpieza

```bash
rm -rf /tmp/trigger-matrix
```
