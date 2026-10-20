# Ejemplo 01 — Hello world workflow

## Concepto que demuestra

El workflow mínimo útil: un `on:` que dispara, un `job` que corre en un runner, dos steps (checkout + run).

## Contexto

Primer workflow. Objetivo: *ver* qué pasa en los logs cuando se ejecuta, no "memorizar YAML".

## Objetivo

Al terminar, podrás responder:
- ¿Qué dispara este workflow?
- ¿En qué máquina corre?
- ¿Qué archivos existen en el workspace tras cada step?
- ¿De dónde salen `$GITHUB_REPOSITORY` y `$GITHUB_SHA`?

## Prerrequisitos

- Git ≥ 2.30.
- Para la ejecución *real* en GitHub: una cuenta y un repo de prueba (no obligatorio para leer y analizar el YAML).
- Opcional: `actionlint` para validar sintaxis sin GitHub.

## Archivo del ejemplo

Está en `files/hello.yml`. Léelo línea por línea; cada token tiene su explicación debajo.

```yaml
# .github/workflows/hello.yml
name: hello

on:
  push:
  pull_request:

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Imprimir info del evento
        run: |
          echo "Hola desde $GITHUB_REPOSITORY"
          echo "Commit: $GITHUB_SHA"
          echo "Evento: $GITHUB_EVENT_NAME"
          echo "Actor: $GITHUB_ACTOR"
          echo "--- Contenido del workspace ---"
          ls -la
```

**Traducción línea por línea**:

- `name: hello` — nombre humano que verás en la UI (pestaña Actions). Si lo omites, GitHub usa el nombre del archivo.
- `on: push: / pull_request:` — qué eventos disparan. Sin filtros = cualquier rama, cualquier PR. En producción casi siempre pondrás filtros (`branches:`, `paths:`), tema de `gha-03`.
- `jobs:` — mapping. Cada clave (`greet`) es un ID técnico.
- `runs-on: ubuntu-latest` — tipo de runner. VM Ubuntu hosted por GitHub.
- `steps:` — lista ordenada. Cada step es un objeto YAML.
- `- uses: actions/checkout@v4` — invoca la action oficial `actions/checkout` tag `v4`. Pobla el workspace con el repo en el commit disparador.
- `- name: ...` — nombre visible del step (opcional pero recomendado).
- `run: |` — comandos de shell. El `|` es sintaxis YAML para bloque multilínea literal.

## Ejecución (dos modos)

### Modo lectura (sin GitHub)

Lee `files/hello.yml`. Para cada step, pregúntate:
1. ¿Qué va a hacer?
2. ¿Qué imprimirá?
3. ¿Qué archivos existirán en el workspace cuando llegue el step?

Luego valida tu interpretación con un linter si tienes:

```bash
# Si tienes actionlint instalado:
actionlint courses/github-actions/01-model-and-first-workflow/examples/01-hello-world/files/hello.yml
```

### Modo real (con cuenta GitHub)

Copia `files/hello.yml` a `.github/workflows/hello.yml` de cualquier repo de prueba tuyo. Pushea. Abre la pestaña Actions.

```bash
# En un repo de prueba tuyo, en /tmp/ para no ensuciar nada permanente
cd /tmp
rm -rf gha-hello-demo
mkdir gha-hello-demo && cd gha-hello-demo
git init -b main
mkdir -p .github/workflows
cp /path/to/examples/01-hello-world/files/hello.yml .github/workflows/
git add .
git commit -m "ci: hello workflow"

# Crea el repo en GitHub y pushea
gh repo create gha-hello-demo --private --source=. --remote=origin --push

# Ver runs
gh run list
gh run watch
```

## Resultado esperado

- El workflow aparece en la pestaña Actions.
- Se ejecuta en ~20–40 s.
- El job `greet` queda verde.
- En los logs del segundo step verás algo como:

```
Hola desde tu-usuario/gha-hello-demo
Commit: a1b2c3d4e5f6...
Evento: push
Actor: tu-usuario
--- Contenido del workspace ---
total 16
drwxr-xr-x 3 runner docker 4096 ... .
drwxr-xr-x 3 runner docker 4096 ... ..
drwxr-xr-x 8 runner docker 4096 ... .git
drwxr-xr-x 3 runner docker 4096 ... .github
```

Observa que `.git/` está presente — porque `actions/checkout` lo clonó.

## Interpretación

- El runner llegó limpio. `actions/checkout` pobló `/home/runner/work/<repo>/<repo>` con tu código.
- Las variables `GITHUB_*` las puso el runner agent antes de arrancar los steps; vienen del contexto `github` que a su vez viene del payload del evento.
- El evento es `push` porque fue el disparador; si abrieras un PR, verías `pull_request` en el segundo run.

## Errores frecuentes

- **El workflow no aparece en la UI**: ruta incorrecta. Debe ser `.github/workflows/*.yml` *en la rama disparadora*. Si pusheaste solo a `feature/x`, el workflow lo lee desde `feature/x`.
- **`actions/checkout: Not Found`**: typo en el nombre o versión no publicada (`@v99`).
- **"No jobs defined"**: el `jobs:` está mal indentado o vacío.
- **Workflow se dispara dos veces por un PR**: `on: push:` *y* `on: pull_request:` disparan ambos para la rama que recibe el PR. Normal; se mitiga con filtros o con `concurrency:` (ver `gha-06`).

## Relación con escenarios reales

- Es el *skeleton* de todo pipeline GHA. En proyectos reales suele crecer a lint + test + build en jobs separados.
- Los `echo` del `run:` suelen reemplazarse por comandos reales (`pytest`, `npm test`, etc.), pero el esqueleto no cambia.
- Es común tener un `hello.yml` como *canary* en repos recién creados mientras se construye el pipeline real.

## Limpieza

```bash
# Si creaste un repo de prueba en GitHub:
gh repo delete gha-hello-demo --yes

# Local:
rm -rf /tmp/gha-hello-demo
```
