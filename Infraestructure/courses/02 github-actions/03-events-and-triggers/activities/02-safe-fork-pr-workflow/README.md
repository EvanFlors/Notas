# gha-03-02 — Procesar PRs de forks sin exponer secretos

## 1. Identificación

- **ID:** `gha-03-02-safe-fork-pr-workflow`
- **Tecnología:** `github-actions`
- **Módulo:** `03-events-and-triggers`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Eres el mantenedor de un proyecto open-source. Recibes PRs desde **forks**. Necesitas:

1. **Correr tests** contra el código del PR (necesita el código, **no** necesita secretos).
2. **Publicar un comentario** en el PR con el resultado de los tests (necesita permisos de escritura y **puede** necesitar un secret — p. ej. un token para subir el reporte a S3).

La trampa: si lo haces con un solo workflow `on: pull_request_target` que haga `actions/checkout` del head del PR, **cualquiera que abra un PR puede ejecutar código con tus secretos**. Es un vector real.

Tu trabajo: diseñar e implementar el **patrón de dos workflows** que resuelve esto correctamente.

## 3. Objetivos

- Separar la ejecución de código del PR (sin secretos) de la publicación de resultados (con secretos).
- Transferir datos entre workflows usando **artefactos**, no ejecución encadenada.
- No crear ningún `.yml` con `pull_request_target` + `actions/checkout` apuntando al head del PR.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` §7 y §8.
- Haber reproducido `examples/03-pull-request-target-safe-pattern/`.
- Software: `bash`, `python3` con `pyyaml`.
- Opcional: `actionlint`.
- Sin cuenta de GitHub ni costos.

## 5. Instrucciones

**No se te da el YAML.** Esta es una actividad independiente.

### Paso 1 — Bootstrap

```bash
bash starter/bootstrap.sh
cd /tmp/safe-fork-pr/workflows
```

Esto crea `/tmp/safe-fork-pr/workflows/` **vacío** salvo por un `README.md` que recuerda el escenario.

### Paso 2 — Diseña el patrón

Crea **al menos** dos archivos `.yml`. Al menos uno debe cumplir:

- **Workflow A** — "corre el código del PR":
  - Trigger `pull_request` (NO `pull_request_target`).
  - `permissions:` declaradas con **mínimo privilegio** (típicamente `contents: read`).
  - Hace `actions/checkout` del PR.
  - Produce un **artefacto** con el resultado (`actions/upload-artifact`) que incluye al menos el número del PR y un reporte.

- **Workflow B** — "publica resultados":
  - Trigger `workflow_run` apuntando al workflow A, con `types: [completed]`.
  - **Nunca** hace `actions/checkout` que descargue código del PR.
  - Declara `pull-requests: write` para poder comentar.
  - Descarga el artefacto del run A (usando `run-id: ${{ github.event.workflow_run.id }}`).
  - Comenta el PR con `gh pr comment` o equivalente.

### Paso 3 — Cosas prohibidas (el validador las detecta)

- Ningún archivo con `pull_request_target` puede contener `actions/checkout` apuntando a `github.event.pull_request.head.*`.
- Ningún archivo con `pull_request_target` puede contener `npm install`, `pip install`, `make`, `bundle install` o similares que ejecutarían código del PR. (El validador aplica un grep conservador: si usas `pull_request_target` + alguno de esos comandos, falla.)

### Paso 4 — Documenta

Crea `workflows/README.md` que explique:

- Qué workflow corre con secretos y cuál no.
- Qué protege el patrón y de qué (describe el anti-patrón que evitas).
- Qué pasaría si fusionaras ambos workflows en uno con `pull_request_target` + checkout del PR.

### Paso 5 — Validar

```bash
bash tests/validate.sh
```

El validador comprueba:

- Hay ≥ 2 archivos `.yml` en `workflows/`.
- Al menos uno usa `on: pull_request` y hace `actions/upload-artifact`.
- Al menos uno usa `on: workflow_run` y declara `pull-requests: write`.
- **Ningún** `.yml` combina `pull_request_target` con `actions/checkout` del head del PR.
- **Ningún** `.yml` combina `pull_request_target` con comandos de ejecución de código del PR (`npm install|pip install|make|bundle install|cargo build|go build`).
- `workflows/README.md` existe y contiene la justificación.
- Si `actionlint` está instalado, lo corre sobre los `.yml`.

## 6. Resultado esperado

- `/tmp/safe-fork-pr/workflows/` con **≥ 2** workflows y un `README.md`.
- Validador reporta `0 FAIL`.

## 7. Criterios de aceptación

- El patrón de dos workflows está implementado correctamente.
- Los secretos solo están disponibles en el workflow B (`workflow_run`).
- El workflow B no ejecuta código del PR bajo ninguna forma.
- Reproducible con `bash starter/bootstrap.sh` + edición + `bash tests/validate.sh`.

## 8. Validación

```bash
bash tests/validate.sh
```

Si quedas atascado, mira:

- `examples/03-pull-request-target-safe-pattern/pr-tests.yml`
- `examples/03-pull-request-target-safe-pattern/pr-test-and-report.yml`

Y por último, la solución de referencia en `solution/`:

```bash
bash solution/solve.sh
bash tests/validate.sh   # debe pasar
```

## 9. Preguntas de reflexión

1. ¿Por qué un `if: github.event.pull_request.head.repo.fork == false` **no** mitiga el riesgo de `pull_request_target` + checkout del PR?
2. ¿Por qué `workflow_run` siempre usa el YAML del default branch? ¿Qué atacarías si no fuera así?
3. ¿Qué cambiarías si tu caso de uso fuera "subir el reporte a S3 con una AWS access key"? ¿Dónde pondrías el `aws-actions/configure-aws-credentials`?
4. En vez de `workflow_run`, ¿sirve `pull_request_target` para la fase de comentar? ¿Qué pierdes y qué ganas?

## 10. Extensiones

- Añade un tercer workflow con `pull_request_target` + `types: [opened]` que **solo** labelee PRs externos con `from-fork` (sin tocar código).
- Añade `concurrency:` a workflow A para cancelar runs anteriores del mismo PR cuando llegan nuevos commits.
- Firma el artefacto en workflow A y verifica la firma en workflow B antes de publicar.

## 11. Limpieza

```bash
rm -rf /tmp/safe-fork-pr
```
