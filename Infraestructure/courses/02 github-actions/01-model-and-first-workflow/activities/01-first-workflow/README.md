# Actividad 01 — Primer workflow: `ci.yml` que corre en `push` y `pull_request`

## 1. Identificación

- **ID:** `gha-01-01-first-workflow`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-01-model-and-first-workflow`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** guided-lab

## 2. Contexto

Primer workflow "propio". Como GitHub Actions **requiere GitHub** para correr de verdad, pero no queremos obligar a cada estudiante (ni al CI del curso) a tener una cuenta, la actividad soporta **dos modos**:

- **`MODE=local`** (default): valida la *estructura* del YAML y la organización del repo sin ejecutarlo. Usa Python+PyYAML (siempre disponible) y, si existe, `actionlint`.
- **`MODE=live`**: dispara el workflow en GitHub con `gh workflow run` y espera el resultado con `gh run watch`. Requiere `gh auth status` OK y un repo real.

Ambos modos validan **la misma estructura** del YAML; el `live` añade un check de que el run terminó verde.

## 3. Objetivos

Al terminar:

- Creas un repo local con `.github/workflows/ci.yml`.
- El workflow:
  - Se dispara en `push` y en `pull_request`.
  - Tiene al menos un job con `runs-on: ubuntu-latest` (o `ubuntu-22.04`, `ubuntu-24.04`).
  - Su primer step es `uses: actions/checkout@v<N>`.
  - Tiene al menos un step `run:` que imprime algo útil del contexto (`$GITHUB_REPOSITORY`, `$GITHUB_SHA`, `$GITHUB_EVENT_NAME`, o similar).
- Validas con `tests/validate.sh` (modo `local` por default).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` y los dos `examples/`.
- Git ≥ 2.30. Python 3 ≥ 3.9 (para el validador local). PyYAML (`pip install pyyaml` — ya está en el entorno del curso).
- **Modo `live`** (opcional): `gh` instalado y autenticado (`gh auth status`). Costo: $0 (repos free).

## 5. Instrucciones

### 5.1 Preparar

```bash
# Bootstrap del scratch dir (modo local, el por default; sin cuenta GitHub)
bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/starter/bootstrap.sh /tmp/gha-01-first-workflow

# o: modo live (crea el repo en GitHub al final; no borra nada que ya exista en /tmp)
MODE=live bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/starter/bootstrap.sh /tmp/gha-01-first-workflow
```

El bootstrap crea `/tmp/gha-01-first-workflow/repo/` como un repo Git inicializado con un `README.md` y un placeholder `.github/workflows/ci.yml` **que no cumple todavía** los criterios. Tu trabajo es editarlo.

### 5.2 Edita el workflow

Abre `/tmp/gha-01-first-workflow/repo/.github/workflows/ci.yml`. El placeholder contiene instrucciones comentadas. Reemplázalo por un workflow que cumpla:

| Criterio | Qué debe tener |
|----------|----------------|
| Nombre | `name: <algo>` (sugerencia: `ci`). |
| Triggers | `on:` con **`push`** y **`pull_request`**. Pueden ser mapas vacíos o con filtros. |
| Job | Al menos uno. |
| Runner | `runs-on: ubuntu-latest` (acepta también `ubuntu-22.04` / `ubuntu-24.04`). |
| Checkout | Primer step: `uses: actions/checkout@v4` (acepta `@v3` o `@v4`). |
| Run | Al menos un step con `run:` que imprima alguna variable `$GITHUB_...`. |

Ejemplo mínimo que pasa (si quieres primero probar que todo funcione):

```yaml
name: ci

on:
  push:
  pull_request:

jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Info del evento
        run: |
          echo "repo: $GITHUB_REPOSITORY"
          echo "sha:  $GITHUB_SHA"
          echo "evt:  $GITHUB_EVENT_NAME"
```

### 5.3 Commit

```bash
cd /tmp/gha-01-first-workflow/repo
git add .github/workflows/ci.yml
git commit -m "ci: add first workflow"
```

### 5.4 Validar en modo local (default)

```bash
bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/tests/validate.sh /tmp/gha-01-first-workflow
```

Debe terminar con `OK`. El validador parsea el YAML con PyYAML, verifica la estructura, y si `actionlint` está en el PATH también corre el linter oficial.

### 5.5 (Opcional) Validar en modo live

```bash
# Si tu bootstrap fue en modo live, ya tienes el repo creado en GitHub.
# Si no, puedes crearlo ahora:
cd /tmp/gha-01-first-workflow/repo
gh repo create gha-01-first-workflow-$(date +%s) --private --source=. --remote=origin --push

MODE=live bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/tests/validate.sh /tmp/gha-01-first-workflow
```

El validador en modo live:
1. Reutiliza las validaciones de estructura del modo local.
2. Chequea `gh auth status`.
3. Dispara el workflow con `gh workflow run ci.yml --ref main` (o detecta la rama).
4. Espera con `gh run watch` y chequea que el estado final sea `completed/success`.

### 5.6 Explorar la UI (modo live)

Con el workflow corrido, abre la pestaña Actions en el navegador (`gh repo view --web`) y familiarízate con:
- Lista de runs.
- Un run abierto: jobs → steps → logs.
- Botón "Re-run jobs".
- Checkmarks verdes/rojos en el commit y en el PR.

## 6. Resultado esperado

- `/tmp/gha-01-first-workflow/repo/` es un repo Git con rama `main`.
- `.github/workflows/ci.yml` existe y cumple los criterios.
- Al menos 1 commit (base) + 1 commit propio tuyo (añadiendo o reemplazando el workflow).
- `tests/validate.sh` termina con `OK` en modo `local`.
- (Opcional) En modo `live`, el último run del workflow terminó verde.

## 7. Criterios de aceptación

- [ ] Archivo `.github/workflows/ci.yml` existe en la ruta exacta.
- [ ] YAML parseable (sin errores de sintaxis).
- [ ] Clave raíz `on:` con `push` y `pull_request` presentes.
- [ ] Al menos un `job` con `runs-on` que empieza por `ubuntu-`.
- [ ] Primer step del primer job es `uses: actions/checkout@v3` o `@v4`.
- [ ] Al menos un step con `run:` que menciona alguna variable `$GITHUB_...`.
- [ ] Working tree limpio.
- [ ] (Modo live) último run `completed/success`.

## 8. Validación

```bash
# modo local
bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/tests/validate.sh /tmp/gha-01-first-workflow

# modo live
MODE=live bash courses/github-actions/01-model-and-first-workflow/activities/01-first-workflow/tests/validate.sh /tmp/gha-01-first-workflow
```

El validador imprime un reporte por check con `OK` / `FAIL`.

## 9. Preguntas de reflexión

1. ¿Por qué el workflow tiene que estar en `.github/workflows/`? ¿Qué pasaría si lo movieras a `workflows/ci.yml`?
2. ¿Qué diferencia habría en comportamiento si quitaras el step `actions/checkout`? ¿Y si lo pusieras en el *segundo* lugar en vez del primero?
3. ¿Qué pasa si pusheas una rama `feature/x` con un `ci.yml` nuevo que **no** existe en `main`? ¿Se ejecuta?
4. En `MODE=live`, abre el run en la UI y re-ejecuta "all jobs". ¿Qué YAML usa? ¿El actual de `main` o el del commit disparador del run original?
5. ¿Qué variables del contexto `github` imprimirías si quisieras que un log te diga en qué PR corrió el workflow?

## 10. Extensiones (opcional)

- **E1** — Añade un segundo job (`lint`) sin dependencia; obsérvalo correr en paralelo.
- **E2** — Añade `name:` a cada step y compara la legibilidad de los logs antes/después.
- **E3** — Añade `permissions: contents: read` a nivel workflow y describe (sin aún leer `gha-05`) qué crees que cambia.
- **E4** — Instala `actionlint` localmente y hazlo correr sobre tu YAML. ¿Qué cosas detecta que PyYAML solo no detectaría?

## 11. Limpieza

```bash
# Local
rm -rf /tmp/gha-01-first-workflow

# Live
gh repo delete gha-01-first-workflow-<timestamp> --yes
```
