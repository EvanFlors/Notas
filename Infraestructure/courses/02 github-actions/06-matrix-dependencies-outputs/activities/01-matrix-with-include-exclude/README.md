# Actividad 01 — Matriz con `include` y `exclude`

## 1. Identificación

- **ID:** `gha-06-01-matrix-with-include-exclude`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-06-matrix-dependencies-outputs`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a escribir un workflow con una matriz **2D** (OS × versión de Python) que **excluye** una combinación problemática y **añade** una combinación extra marcada como *experimental* (que no debe tirar el build si falla).

Como no se puede ejecutar GitHub Actions sin GitHub, soportamos **dos modos**:

- **`MODE=local`** (default): el validador parsea tu YAML con Python y verifica estructura (claves correctas, matriz bien formada, `exclude`/`include` presentes, `fail-fast`, `continue-on-error` dinámico, `permissions: contents: read`). Si tenés `actionlint` instalado, también lo corre.
- **`MODE=live`**: además de lo anterior, dispara el workflow con `gh workflow run` y espera a que termine con éxito.

## 3. Objetivos

Al terminar:
- Escribís una `strategy.matrix` 2D con dimensiones `os` y `python`.
- Agregás **al menos un `exclude`** justificado por comentario.
- Agregás **al menos un `include`** que añada una combinación nueva con un atributo `experimental: true`.
- Usás `fail-fast: false` y `continue-on-error: ${{ matrix.experimental == true }}`.
- Declarás `permissions: contents: read` a nivel workflow.
- Validás con `tests/validate.sh` en modo `local` (CI) o `live` (contra GitHub).

## 4. Prerrequisitos

- `gha-02` (expresiones, contextos) y `gha-05` (`permissions`).
- Python 3 con `pyyaml` instalado (para el validador local).
- Opcional: [`actionlint`](https://github.com/rhysd/actionlint) en `$PATH` (el validador lo usa si está).
- **Modo `live`**: `gh` CLI autenticado + un repo en GitHub al que podás pushear.

## 5. Instrucciones

### 5.1 Preparar

```bash
# Modo local (lo que correrá el CI del curso):
MODE=local bash starter/bootstrap.sh /tmp/gha-06-01

# Modo live (opcional, requiere gh auth y un repo):
MODE=live bash starter/bootstrap.sh /tmp/gha-06-01
```

El bootstrap crea en `/tmp/gha-06-01/local/` un repo con el esqueleto de un workflow a completar en `.github/workflows/ci.yml` (contiene un placeholder claro).

### 5.2 Editar el workflow

Abrí `/tmp/gha-06-01/local/.github/workflows/ci.yml` y completá la matriz. **Debe cumplir todo esto**:

1. **Nombre** del workflow: `ci` (clave `name:`).
2. Trigger: `on: push` y `on: workflow_dispatch` (ambos).
3. `permissions: contents: read` a nivel workflow.
4. Un único job `test` con `runs-on: ${{ matrix.os }}`.
5. `strategy.fail-fast: false`.
6. `strategy.matrix` con:
   - `os`: lista con al menos `ubuntu-latest` y `macos-latest`.
   - `python`: lista con al menos `'3.11'` y `'3.12'`.
   - **`exclude`**: al menos una entrada que quite una combinación (con un comentario `#` que lo justifique).
   - **`include`**: al menos una entrada que añada una combinación con `experimental: true`.
7. Steps:
   - `actions/checkout@v4`.
   - `actions/setup-python@v5` con `python-version: ${{ matrix.python }}`.
   - Un step que ejecute algo (`python --version`, por ejemplo) con `continue-on-error: ${{ matrix.experimental == true }}`.

### 5.3 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha-06-01
```

Debe terminar con `OK`.

Si tenés `gh` autenticado y un repo donde pushear, también:

```bash
MODE=live bash tests/validate.sh /tmp/gha-06-01
```

(este modo asume que el workflow ya está pusheado al repo y usa `gh workflow run` + `gh run watch`).

## 6. Resultado esperado

- `/tmp/gha-06-01/local/.github/workflows/ci.yml` presente y válido.
- El YAML parsea sin errores.
- La estructura cumple todos los checks del validador.
- (Live) El workflow termina `conclusion: success` en GitHub.

## 7. Criterios de aceptación

- [ ] `name: ci`.
- [ ] `on:` incluye `push` y `workflow_dispatch`.
- [ ] `permissions: contents: read` a nivel workflow.
- [ ] `jobs.test.strategy.fail-fast == false`.
- [ ] `jobs.test.strategy.matrix.os` tiene ≥ 2 OS.
- [ ] `jobs.test.strategy.matrix.python` tiene ≥ 2 versiones.
- [ ] `jobs.test.strategy.matrix.exclude` tiene ≥ 1 entrada.
- [ ] `jobs.test.strategy.matrix.include` tiene ≥ 1 entrada con `experimental: true`.
- [ ] Hay un step con `continue-on-error: ${{ matrix.experimental == true }}`.
- [ ] Usa `actions/checkout@v4` y `actions/setup-python@v5`.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha-06-01
MODE=live  bash tests/validate.sh /tmp/gha-06-01   # opcional
```

El script imprime cada check con `OK`/`FAIL` y un resumen `RESULT`.

## 9. Preguntas de reflexión

1. ¿Cuántos jobs totales genera tu matriz? Desglosalo: cartesiano − exclude + include.
2. ¿Qué pasaría si cambiás `fail-fast` a `true`? ¿En qué escenarios tiene sentido?
3. Si el `include` coincide **exactamente** con una combinación del cartesiano, ¿crea una nueva o enriquece la existente? Probalo (modificando el `include`) y observá el total de jobs.
4. En `MODE=local` el validador parsea el YAML. ¿Qué cosas **no** puede validar sin ejecutar el workflow en GitHub?
5. ¿Por qué dejamos `permissions: contents: read` aunque el workflow no haga nada que requiera `write`? (Pista: defense-in-depth, baseline del repo.)

## 10. Extensiones (opcional)

- **E1** — Añadí una tercera dimensión (`arch: [x64, arm64]`) y un `exclude` que quite `macos-latest + arm64` para `python-3.11`. Recalculá el total.
- **E2** — Hacé que el nombre del job sea dinámico: `name: test (${{ matrix.os }} / py${{ matrix.python }})`.
- **E3** — Agregá `max-parallel: 2` y comentá por qué podrías querer limitarlo (minutos, rate limits, saturar el runner self-hosted).
- **E4** — Si tenés `actionlint` instalado, corré `actionlint .github/workflows/ci.yml` directamente y resolvé cualquier warning.

## 11. Limpieza

```bash
rm -rf /tmp/gha-06-01
```
