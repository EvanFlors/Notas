# Actividad 02 — Fan-out / Fan-in con aggregator

## 1. Identificación

- **ID:** `gha-06-02-fan-out-fan-in`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-06-matrix-dependencies-outputs`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Vas a construir un pipeline con esta forma:

```
            ┌──────────┐
            │  build   │   (matriz: target in [alpha, beta, gamma])
            │ [matrix] │   cada uno emite outputs.sha (sha corto propio)
            └────┬─────┘
                 │  fan-in: needs: build (espera a las 3)
                 ▼
            ┌──────────┐
            │aggregate │   consume needs.build.result (y/o outputs),
            │          │   escribe tabla Markdown en $GITHUB_STEP_SUMMARY
            └──────────┘
```

**Nada de solución revelada acá.** Debés diseñar el YAML por tu cuenta siguiendo los criterios de aceptación. Tenés la lección completa y los tres ejemplos como referencia.

## 3. Objetivos

Al terminar:
- Diseñás una matriz 1D con `target: [alpha, beta, gamma]` (3 jobs paralelos).
- Cada combinación computa su propio `sha` corto y lo expone *de alguna forma* al aggregator.
- Un job `aggregate` depende de `build` (todas las combinaciones) y escribe un **resumen Markdown** en `$GITHUB_STEP_SUMMARY` con una **tabla** que lista cada target y su resultado.
- El workflow sigue el baseline de seguridad: `permissions: contents: read` a nivel workflow, acciones oficiales con `@v4`/`@v5`.
- Agregás `concurrency` a nivel workflow con un grupo que incluya `${{ github.ref }}` y `cancel-in-progress: true` (es CI, no CD).

## 4. Prerrequisitos

- `gha-02`, `gha-05`.
- Haber hecho la actividad 01 (recomendado).
- Python 3 con `pyyaml` instalado.
- Opcional: `actionlint`.
- **Modo `live`**: `gh` CLI autenticado + un repo pusheable.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha-06-02
```

El bootstrap deja un repo en `/tmp/gha-06-02/local/` con `.github/workflows/pipeline.yml` como **placeholder vacío**. Vos lo reescribís.

### 5.2 Diseñar y editar

Abrí `/tmp/gha-06-02/local/.github/workflows/pipeline.yml` y escribí el workflow. **Pistas** (no solución):

- La matriz 1D más sencilla es `target: [alpha, beta, gamma]`.
- Para que el `sha` esté disponible al aggregator vía `needs.build.outputs.<key>`, declará un `outputs:` a nivel del job `build`. **Nota**: cuando un job es matricial, `needs.<job>.outputs.<key>` lee el output de **una** combinación (en la práctica, la última que escribió; no es determinista). Para esta actividad basta con eso — el aggregator leerá al menos un valor y lo mostrará como "sample output".
- El resumen debe ser una tabla Markdown. Columnas sugeridas: `target`, `result`.
- `needs.build.result` te da el **conjunto** de la matriz (`success`, `failure`, etc.).

### 5.3 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha-06-02
```

Debe terminar con `OK`.

Opcional live:

```bash
MODE=live bash tests/validate.sh /tmp/gha-06-02
```

## 6. Resultado esperado

- `/tmp/gha-06-02/local/.github/workflows/pipeline.yml` presente y válido.
- Dos jobs: `build` (matricial, 3 combinaciones) y `aggregate` (depende de `build`).
- `aggregate` escribe al menos una tabla Markdown en `$GITHUB_STEP_SUMMARY`.
- `concurrency` definida a nivel workflow con `cancel-in-progress: true` y grupo que incluye `github.ref`.
- (Live) El workflow termina en `success`.

## 7. Criterios de aceptación

- [ ] `permissions.contents: read` a nivel workflow.
- [ ] `concurrency.group` contiene `github.ref` y `concurrency.cancel-in-progress: true`.
- [ ] Job `build` con `strategy.matrix.target` listando ≥ 3 valores.
- [ ] Job `build` declara `outputs:` (al menos una clave) y al menos un step que escribe a `$GITHUB_OUTPUT`.
- [ ] Job `aggregate` con `needs: build`.
- [ ] Job `aggregate` tiene al menos un step que escribe a `$GITHUB_STEP_SUMMARY`.
- [ ] En ese contenido hay sintaxis de tabla Markdown (líneas con `|`).
- [ ] Acciones referenciadas con pin a versión major (`@v4`, `@v5`).

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha-06-02
MODE=live  bash tests/validate.sh /tmp/gha-06-02   # opcional
```

## 9. Preguntas de reflexión

1. Cuando un job matricial tiene 3 combinaciones y declarás `outputs:`, ¿qué valor "gana" cuando el siguiente job lo lee? ¿Es determinista? ¿Qué patrón usarías si necesitás *todos* los outputs?
2. ¿Qué cambia en el pipeline si poner `fail-fast: true` en la matriz `build`? ¿Y en `aggregate`?
3. ¿Por qué `cancel-in-progress: true` acá y no en el ejemplo 03 del módulo?
4. Si `aggregate` necesita datos *individuales* de cada combinación, ¿qué primitiva usarías en vez de outputs? (Pista: módulo siguiente.)
5. ¿Cómo asegurás que `aggregate` corra **incluso si** alguna combinación de `build` falla? ¿Qué `if:` necesitarías?

## 10. Extensiones (opcional)

- **E1** — Hacé que cada `build` suba un pequeño artefacto (p. ej. `build-${{ matrix.target }}.txt` con contenido mínimo) y que `aggregate` los descargue todos y liste los nombres en el summary. (Anticipa `gha-07`.)
- **E2** — Hacé la matriz **dinámica**: un job `plan` previo emite `targets` como JSON en un output y `build` usa `fromJSON(needs.plan.outputs.targets)`.
- **E3** — Añadí un badge SVG al summary (`![status](...)`) con el conclusion del workflow.
- **E4** — Agregá un job `release` después de `aggregate` con `concurrency: group: release-prod, cancel-in-progress: false` y un `environment: production`.

## 11. Limpieza

```bash
rm -rf /tmp/gha-06-02
```
