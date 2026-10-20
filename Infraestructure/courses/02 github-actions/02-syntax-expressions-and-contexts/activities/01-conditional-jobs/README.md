# Actividad 01 — Workflow con jobs condicionados

## 1. Identificación

- **ID:** `gha-02-01-conditional-jobs`
- **Tecnología:** `github-actions`
- **Módulo:** `02-syntax-expressions-and-contexts`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Casi todos los workflows reales tienen alguna lógica condicional: "esto solo en main", "aquello solo si los tests pasaron", "siempre subir logs al final". Esta actividad te hace **escribir el workflow desde cero** aplicando las tres formas canónicas de condicionar: por **evento + rama**, por **resultado de un job previo** (`needs.X.result`) y con **status functions** (`always()`, `failure()`).

Dos modos:

- **`MODE=local`** (default): validamos el YAML con `actionlint` (si está instalado) + checks estructurales (regex sobre el workflow). No requiere cuenta GitHub.
- **`MODE=live`**: tras pushear el workflow a un repo real, el validador verifica con `gh run list` que corrió con éxito.

## 3. Objetivos

Al terminar:
- Escribes un workflow con **tres jobs** encadenados: `lint`, `test`, `deploy`.
- `lint` corre siempre. `test` depende de `lint`. `deploy` depende de `test` **y** solo corre en `push` a `main`.
- Dentro de `test`: un step con `continue-on-error: true` (advisory), un step condicionado por `steps.*.outcome`, y un step `always()` de cleanup.
- Usas `env:` a los tres niveles para parametrizar `LOG_LEVEL`.
- Validas en `MODE=local` (y opcionalmente `live`).

## 4. Prerrequisitos

- `gha-01` completado.
- Git ≥ 2.30.
- **Recomendado**: `actionlint` instalado (`brew install actionlint` o `go install github.com/rhysd/actionlint/cmd/actionlint@latest`). Sin él los checks estructurales siguen funcionando pero no detectan errores de sintaxis finos.
- Python 3 (para que `pyyaml`-level checks del validador funcionen; usa `python3` del sistema).
- **Modo `live`** (opcional): `gh auth status` OK y un repo propio donde pushear.
- Costo: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha-02-01
```

Esto crea `/tmp/gha-02-01/local/` con un esqueleto de workflow en `.github/workflows/conditional.yml` que **tienes que completar**. Las secciones a rellenar están marcadas con `# TODO`.

### 5.2 Diseñar el workflow

El workflow a construir, en pseudo-estructura:

```
on: push (todas las ramas), pull_request a main

env (workflow): LOG_LEVEL=info

jobs:
  lint:
    runs-on: ubuntu-latest
    env (job): LOG_LEVEL=debug
    steps:
      - checkout
      - step id=check, run: echo "linting at $LOG_LEVEL"
      - step env (step): LOG_LEVEL=trace, run: echo "level=$LOG_LEVEL"

  test:
    needs: lint
    if: siempre (ya cubierto por needs)
    runs-on: ubuntu-latest
    steps:
      - checkout
      - id=flaky, continue-on-error: true, run: exit 1
      - if: steps.flaky.outcome == 'failure', run: echo "flaky failed but we go on"
      - if: failure(), run: echo "something failed"
      - if: always(), run: echo "cleanup"

  deploy:
    needs: test
    if: push a main AND needs.test.result == 'success'
    runs-on: ubuntu-latest
    steps:
      - run: echo "deploying ${{ github.sha }}"
```

Pistas:

- Para "solo push a main": `if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && needs.test.result == 'success' }}`.
- `needs.test.result` puede ser `'success'`, `'failure'`, `'cancelled'` o `'skipped'`.
- Recuerda: comparar strings con comillas **simples** dentro del `${{ ... }}`.

### 5.3 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha-02-01
```

Debe terminar con `RESULT (local): N/N checks OK.`.

### 5.4 (Opcional) MODE=live

En un repo tuyo:

```bash
cp /tmp/gha-02-01/local/.github/workflows/conditional.yml .github/workflows/
git add .github/workflows/conditional.yml
git commit -m "gha-02-01: conditional jobs"
git push

# Esperar que corra y:
MODE=live REPO=<owner/repo> bash tests/validate.sh /tmp/gha-02-01
```

## 6. Resultado esperado

- `/tmp/gha-02-01/local/.github/workflows/conditional.yml` con el workflow completo.
- Sin ocurrencias de `# TODO` en el archivo.
- `actionlint` (si existe) sin errores.
- Checks estructurales que validan: 3 jobs llamados `lint`, `test`, `deploy`; `needs:` presentes; `continue-on-error`; al menos un `if:` con `always()` y uno con `failure()`; env a tres niveles.

## 7. Criterios de aceptación

- [ ] 3 jobs: `lint`, `test`, `deploy`.
- [ ] `test.needs == [lint]` y `deploy.needs == [test]`.
- [ ] `deploy.if` combina `github.event_name == 'push'`, `github.ref == 'refs/heads/main'` y `needs.test.result == 'success'`.
- [ ] En `test`: un step con `continue-on-error: true`, uno con `if: ${{ always() }}`, uno con `if: ${{ failure() }}`.
- [ ] `env:` definido a workflow-level, job-level y step-level.
- [ ] `actionlint` (si disponible) sin errores.
- [ ] No queda ningún `TODO` en el workflow.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha-02-01
# o
MODE=live REPO=<owner/repo> bash tests/validate.sh /tmp/gha-02-01
```

## 9. Preguntas de reflexión

1. ¿Qué pasaría si quitas `needs: lint` del job `test`? ¿En qué orden correrían?
2. ¿Qué pasa si en `deploy` escribes `if: github.ref == 'main'` en lugar de `'refs/heads/main'`? ¿Correrá alguna vez?
3. Si el step `flaky` **no tuviera** `continue-on-error`, ¿correría el step `always()`?
4. ¿Qué diferencia hay entre `needs.test.result` y `needs.test.outputs.*`?
5. ¿Dónde pondrías el `timeout-minutes` para proteger de bucles infinitos sin ser agresivo con tests legítimos?

## 10. Extensiones (opcional)

- **E1** — Añade `strategy.matrix: python-version: ['3.11', '3.12']` al job `test`.
- **E2** — Añade un `concurrency: group: deploy-${{ github.ref }}` al job `deploy` para evitar deploys solapados.
- **E3** — Añade un step que escriba al `$GITHUB_STEP_SUMMARY` un resumen Markdown del run.
- **E4** — Convierte el job `deploy` en condicional sobre un `environment:` con approval (se profundiza en `gha-09`).

## 11. Limpieza

```bash
rm -rf /tmp/gha-02-01
# Y si pusheaste a GitHub, borra el workflow:
# rm .github/workflows/conditional.yml && git commit -am "cleanup" && git push
```
