# Lección: matrices, dependencias y outputs entre jobs

> **ID:** `gha-06-matrix-dependencies-outputs` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `gha-02`, `gha-05`.

---

## 1. Introducción intuitiva

Un workflow pequeño es una receta lineal: *lint* → *test* → *build* → *deploy*, un paso detrás de otro. Funciona para un repo nuevo. En cuanto tu proyecto tiene que soportar **tres versiones de Python** en **dos sistemas operativos**, y además querés que *build* corra **una sola vez** después de que las nueve combinaciones de test pasen, y que *deploy* **nunca** se solape consigo mismo porque dos pushes rápidos a `main` encolarían dos despliegues a producción al mismo tiempo — tu "receta lineal" ya no alcanza.

Lo que necesitás es una forma de decirle al scheduler de GitHub:

- *"Corré estos tests en todas las combinaciones de versiones × SO, dejame excluir las que no tienen sentido, y abortá el resto si uno falla."*
- *"Esperá a que todos pasen antes de buildear."*
- *"Pasale al deploy este tag que calculé en el build."*
- *"Si llega un segundo deploy a prod mientras el primero corre, poné el segundo en cola — o cancelá el primero, según el dominio."*

Las primitivas que lo hacen son cuatro: **`strategy.matrix`**, **`needs`**, **`outputs`** y **`concurrency`**. Son el "lenguaje de orquestación" de GitHub Actions. Dominarlas te permite escribir pipelines que escalan sin volverse una sopa de YAML duplicado.

---

## 2. Fundamentos

Tres ideas conceptuales que necesitás tener claras antes de ver sintaxis.

### 2.1 El workflow es un DAG de jobs

Dentro de un workflow, los **jobs** son nodos de un **grafo acíclico dirigido**. Las aristas se declaran con `needs:`. El scheduler calcula el orden topológico y ejecuta en paralelo todo lo que no tenga dependencia pendiente.

```
      ┌───────────┐
      │   lint    │
      └─────┬─────┘
            │
      ┌─────▼─────┐    ┌───────────┐
      │   test    │    │ typecheck │
      └─────┬─────┘    └─────┬─────┘
            │                │
            └────────┬───────┘
                    │
              ┌─────▼─────┐
              │   build   │   (fan-in: espera a ambos)
              └─────┬─────┘
                    │
              ┌─────▼─────┐
              │  deploy   │
              └───────────┘
```

Si no hay `needs:`, todos los jobs arrancan en paralelo al disparo del evento. No es "primero el que está arriba en el YAML" — el orden en el archivo **no importa**.

### 2.2 La matriz es expansión declarativa

`strategy.matrix` **no** es un `for` — es una **declaración** de combinaciones. GitHub expande la matriz en tiempo de scheduling y crea *N* jobs independientes, cada uno con su propio runner y su propio contexto `matrix.*`. En la UI aparecen como ramas de un único "job matrix".

Lo importante:

- Cada combinación es un job **separado**, no un step. Falla una, falla *ese* job (y arrastra a sus dependientes).
- `include` **añade** combinaciones (o atributos a combinaciones existentes). `exclude` **las quita**. Primero se calcula el producto cartesiano, luego se aplica `exclude`, luego `include` añade.
- Las variables de matriz solo existen *dentro* del job matricial. Si querés propagar un resultado derivado al siguiente job, necesitás `outputs`.

### 2.3 Los outputs son strings pasados por el runner

Un job puede declarar `outputs:` a nivel del job (no del step), que luego se consumen en otros jobs con `${{ needs.<job-id>.outputs.<key> }}`. Internamente el runner los escribe en un archivo (`$GITHUB_OUTPUT`) y GitHub los serializa como strings cortos (hay límites de tamaño; para datos grandes usá **artefactos**, cubiertos en `gha-07`).

```
┌──────────────────┐                        ┌──────────────────┐
│ job: compute     │                        │ job: deploy      │
│                  │  outputs.tag ───────▶  │   needs:         │
│  steps:          │                        │     - compute    │
│   - id: v        │                        │   uses:          │
│     run: echo    │                        │     ${{ needs    │
│      tag=...     │                        │       .compute   │
│      >>$GITHUB_  │                        │       .outputs   │
│      OUTPUT      │                        │       .tag }}    │
└──────────────────┘                        └──────────────────┘
```

Memorizá estas tres ideas: **DAG**, **expansión matricial**, **outputs como strings propagados**. Es toda la orquestación que vas a usar el 90 % del tiempo.

---

## 3. Contexto histórico

GitHub Actions nació en 2018 con una sintaxis basada en HCL (parecida a Terraform). Antes del lanzamiento general en 2019 se migró a YAML, siguiendo la convención de la mayoría de CI/CD de la época (Travis, CircleCI, GitLab).

Dos cambios de diseño relevantes para este módulo ocurrieron después:

- **De `::set-output` a `$GITHUB_OUTPUT` (octubre 2022).** Hasta esa fecha, un step emitía outputs escribiendo "workflow commands" en stdout: `echo "::set-output name=tag::v1.2"`. Era elegante pero **inseguro**: cualquier output de un comando (un `cat` de un archivo controlado por un atacante, por ejemplo) podía inyectar un `::set-output` que el runner interpretaba como legítimo. GitHub deprecó la sintaxis y la reemplazó por escribir a un **archivo** cuya ruta vive en la env var `GITHUB_OUTPUT`. El archivo lo lee el runner al terminar el step; el contenido de stdout ya no se interpreta.
- **`concurrency` nativa (2021).** Antes se simulaba con lockfiles en S3, mutex en un servicio externo, o jobs que se mataban entre sí vía API. En 2021 GitHub introdujo `concurrency:` a nivel workflow y job: definís un grupo nombrado, y GitHub garantiza que **a lo sumo un run** del grupo está activo. Con `cancel-in-progress: true`, llega un segundo y cancela el primero; con `false`, el segundo queda encolado.

Entender *por qué* se hicieron estos cambios ayuda a usar las primitivas correctamente, no solo mecánicamente.

---

## 4. Funcionamiento interno

### 4.1 Expansión de la matriz

Cuando el scheduler lee tu workflow:

1. Toma el producto cartesiano de todas las claves bajo `strategy.matrix` (excepto `include` y `exclude`).
2. Resta las combinaciones listadas en `exclude`.
3. Añade (o enriquece) las combinaciones listadas en `include`.
4. Cada combinación resultante genera **un job** con su propio `matrix` context.

Pseudocódigo:

```
combinations = cartesian_product(matrix.keys_except_include_exclude)
combinations = combinations - matrix.exclude
for extra in matrix.include:
    if matches_existing_combo(extra):
        enrich_combo(extra)        # añade atributos (sin crear job nuevo)
    else:
        combinations.add(extra)    # crea una combinación nueva
schedule_jobs(combinations)
```

Esto explica dos sutilezas que confunden:

- Un `include` que *coincide* con una combinación ya existente **no la duplica**; le **añade** atributos (por ejemplo, un flag `experimental: true` solo para `python-3.13`).
- Un `include` que **no** coincide con ninguna combinación crea una fila nueva, aunque tenga claves que no estén en el `matrix` principal.

### 4.2 `GITHUB_OUTPUT`: cómo funciona por dentro

El runner, antes de ejecutar un step, crea un archivo temporal (por ejemplo `/home/runner/_temp/_runner_file_commands/set_output_abcd`) y expone su ruta como `$GITHUB_OUTPUT`. El step escribe líneas con formato `key=value` (o un bloque heredoc para valores multilínea). Al terminar el step, el runner **lee ese archivo** y asocia los pares `key=value` con el `id` del step. Luego pueden consumirse como `steps.<id>.outputs.<key>` dentro del mismo job, o declararse como `outputs` del job entero para que otros jobs los vean vía `needs.<job>.outputs.<key>`.

Sintaxis correcta:

```yaml
- id: compute
  run: |
    echo "tag=v1.2.$(date +%s)" >> "$GITHUB_OUTPUT"
```

Multilínea con heredoc (necesario si el valor tiene saltos de línea):

```yaml
- id: notes
  run: |
    {
      echo 'notes<<EOF'
      git log --oneline -n5
      echo 'EOF'
    } >> "$GITHUB_OUTPUT"
```

Lo que **no** funciona ya:

```yaml
# DEPRECATED. Desde 2022 rompe con warning y en workflows nuevos puede fallar.
- run: echo "::set-output name=tag::v1.2"
```

### 4.3 `concurrency`: lock nombrado

`concurrency` crea un **grupo nombrado**. GitHub garantiza, a nivel repositorio, que **a lo sumo un run** por grupo esté *in-progress* a la vez.

- Con `cancel-in-progress: false` (default): un segundo run entra en estado *queued/pending* y espera.
- Con `cancel-in-progress: true`: un segundo run cancela al que está activo y toma su lugar.

El grupo se nombra típicamente con una expresión que lo discrimine por contexto:

```yaml
concurrency:
  group: deploy-${{ github.ref }}         # un grupo por branch
  cancel-in-progress: false               # cola, no mates
```

Reglas prácticas:

- En **CI de PRs**, suele ir `cancel-in-progress: true` (si llega un push nuevo al PR, cancelá el CI viejo — no tiene sentido terminarlo). Grupo: `ci-${{ github.workflow }}-${{ github.ref }}`.
- En **CD a producción**, suele ir `cancel-in-progress: false` (dos deploys deben serializarse, no superponerse ni matarse). Grupo: `deploy-prod` (sin `ref` — querés el lock *global*).

### 4.4 Job summary

Cada step tiene disponible `$GITHUB_STEP_SUMMARY`, un archivo donde podés escribir Markdown. Al terminar el run, GitHub lo renderiza en la UI del job como una sección prominente. Es el canal correcto para "resumen humano del build" (tablas de tests, versiones embebidas, enlaces a artefactos).

```yaml
- run: |
    {
      echo "## Build summary"
      echo "- Image: \`ghcr.io/org/app:$TAG\`"
      echo "- Tests: $PASSED/$TOTAL"
    } >> "$GITHUB_STEP_SUMMARY"
```

A diferencia de outputs, el summary **no** se propaga a otros jobs — es puramente para la UI.

---

## 5. Ejemplo mínimo

Pipeline de tres fases: `test` matricial 2×2 → `build` único → `deploy` con lock.

```yaml
name: ci-cd
on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        python: ['3.11', '3.12']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - run: python -c "print('tests OK')"

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.v.outputs.tag }}
    steps:
      - uses: actions/checkout@v4
      - id: v
        run: echo "tag=v$(date +%Y%m%d-%H%M%S)" >> "$GITHUB_OUTPUT"
      - run: echo "Built artifact ${{ steps.v.outputs.tag }}"

  deploy:
    needs: build
    runs-on: ubuntu-latest
    concurrency:
      group: deploy-prod
      cancel-in-progress: false
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.tag }} to prod"
```

Leamos qué pasa cuando llega un push a `main`:

1. Se dispara el workflow. El scheduler ve 4 jobs de `test` (2×2), un `build` que depende de los 4, un `deploy` que depende de `build`.
2. Los 4 `test` arrancan en paralelo (hay runners disponibles de ubuntu y macos).
3. Cuando los 4 verdes, arranca `build`. Computa `tag=vYYYYMMDD-HHMMSS` y lo escribe en `$GITHUB_OUTPUT`. Lo expone como `jobs.build.outputs.tag`.
4. `deploy` recibe `needs.build.outputs.tag`, pero antes de ejecutar steps verifica el grupo de concurrency `deploy-prod`. Si no hay otro run activo del grupo, procede. Si hay, espera (porque `cancel-in-progress: false`).

Si durante el paso 4 llega **otro** push a `main`, se dispara otro workflow completo. Sus jobs `test` y `build` corren normalmente (otro grupo de concurrency, no definido → sin lock). Cuando llegue a `deploy`, verá `deploy-prod` ocupado y esperará en cola. Serialización garantizada hacia prod.

---

## 6. Implementación progresiva

Hagamos crecer el pipeline incorporando `include`/`exclude`, outputs multilínea y summary.

### 6.1 Añadir una combinación experimental con `include`

Queremos probar también en `python-3.13` en Ubuntu, marcándolo como experimental (que no falle el pipeline si rompe).

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest]
    python: ['3.11', '3.12']
    include:
      - os: ubuntu-latest
        python: '3.13'
        experimental: true
```

Ahora tenés 5 combinaciones. La quinta tiene un atributo extra `experimental` que las otras no tienen. Lo usás en un step:

```yaml
- name: Run tests
  continue-on-error: ${{ matrix.experimental == true }}
  run: pytest
```

El `continue-on-error` evaluado dinámicamente hace que la combinación experimental marque "fallida" pero *no* arrastre al pipeline.

### 6.2 Quitar combinaciones sin sentido con `exclude`

Supongamos que `macos-latest` + `python-3.11` no es compatible con una dependencia que usás. Quitala:

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest]
    python: ['3.11', '3.12']
    exclude:
      - os: macos-latest
        python: '3.11'
    include:
      - os: ubuntu-latest
        python: '3.13'
        experimental: true
```

Ahora: 4 base − 1 exclude + 1 include = **4 jobs** totales.

### 6.3 Outputs multilínea para release notes

En el job `build`, generamos notes a partir del log de git:

```yaml
build:
  needs: test
  runs-on: ubuntu-latest
  outputs:
    tag: ${{ steps.meta.outputs.tag }}
    notes: ${{ steps.meta.outputs.notes }}
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    - id: meta
      run: |
        TAG="v$(date +%Y%m%d-%H%M%S)"
        echo "tag=$TAG" >> "$GITHUB_OUTPUT"
        {
          echo 'notes<<EOF'
          git log --oneline -n 10
          echo 'EOF'
        } >> "$GITHUB_OUTPUT"
```

El `deploy` las consume:

```yaml
deploy:
  needs: build
  runs-on: ubuntu-latest
  concurrency:
    group: deploy-prod
    cancel-in-progress: false
  steps:
    - run: |
        echo "Deploying ${{ needs.build.outputs.tag }}"
        cat <<'NOTES'
        ${{ needs.build.outputs.notes }}
        NOTES
```

### 6.4 Resumen en `$GITHUB_STEP_SUMMARY`

Al final del `deploy`, imprimimos un resumen humano:

```yaml
- name: Summary
  run: |
    {
      echo "## Deploy summary"
      echo ""
      echo "- **Tag:** \`${{ needs.build.outputs.tag }}\`"
      echo "- **SHA:** \`${{ github.sha }}\`"
      echo "- **Actor:** @${{ github.actor }}"
      echo ""
      echo "### Changes"
      echo '```'
      echo "${{ needs.build.outputs.notes }}"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
```

En la UI del run, el job `deploy` ahora muestra una tarjeta prominente con tag, SHA, actor y cambios. Mucho mejor que buscar en los logs.

---

## 7. Aplicación profesional

En la vida real estas primitivas se combinan en patrones recurrentes.

### 7.1 Patrón fan-out / fan-in

Varios jobs independientes en paralelo (fan-out), un aggregator al final (fan-in). Caso típico: compilar artefactos para N plataformas en paralelo, un release job que los junta y publica.

```
          ┌──────────┐
          │ compute  │   (declara targets como output JSON)
          └────┬─────┘
               │
     fromJSON(…)│  (expande matriz dinámicamente)
       ┌───────┼───────┐
       ▼       ▼       ▼
   ┌─────┐ ┌─────┐ ┌─────┐
   │build│ │build│ │build│   (matriz, un job por target)
   │linux│ │ mac │ │win  │
   └──┬──┘ └──┬──┘ └──┬──┘
      └──────┬┴───────┘
             ▼
       ┌──────────┐
       │ release  │   (needs: build; junta artefactos, publica)
       └──────────┘
```

El `needs:` del `release` apunta al **nombre del job matricial completo**, no a cada combinación. GitHub espera a que *todas* las combinaciones terminen antes de continuar. Si alguna falla y `fail-fast: false`, `release` **se saltea** por default (porque `needs:` implica `success()`); podés forzar con `if: always()` + chequeo explícito del resultado.

### 7.2 Matriz dinámica desde JSON

Hay casos donde la lista de combinaciones **no se conoce al escribir el YAML** — se calcula en un job previo (p. ej. "qué paquetes del monorepo cambiaron"). El patrón:

```yaml
jobs:
  compute:
    runs-on: ubuntu-latest
    outputs:
      targets: ${{ steps.gen.outputs.targets }}
    steps:
      - id: gen
        run: echo 'targets=["pkg-a","pkg-b","pkg-c"]' >> "$GITHUB_OUTPUT"

  build:
    needs: compute
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target: ${{ fromJSON(needs.compute.outputs.targets) }}
    steps:
      - run: echo "Building ${{ matrix.target }}"
```

`fromJSON(...)` se evalúa en tiempo de *scheduling* del job dependiente — por eso **tiene** que llegar en un `output` del job previo, no en una variable de env.

### 7.3 Concurrencia estratificada

- `ci-${{ github.ref }}` con `cancel-in-progress: true` para CI de PRs y feature branches.
- `deploy-${{ environment }}` con `cancel-in-progress: false` para CD por environment.
- Si tu release genera assets (p. ej. imágenes firmadas, SBOMs), **nunca** uses `cancel-in-progress: true` en ese grupo — podés dejar un release a medias y recursos inconsistentes.

### 7.4 Permisos mínimos por workflow

A nivel workflow:

```yaml
permissions:
  contents: read
```

Y escalada **por job** solo donde se necesite (ej. un job que crea un release necesita `contents: write`, otro que publica a GHCR necesita `packages: write`). Es doctrina de `gha-05` que acá se refuerza — en pipelines con muchos jobs, la tentación de un `permissions: write-all` global es alta y mala.

---

## 8. Trade-offs

### 8.1 `fail-fast: true` vs `false`

| Dimensión | `fail-fast: true` (default) | `fail-fast: false` |
|-----------|-----------------------------|---------------------|
| Minutos consumidos | Menos (aborta hermanas al primer fallo) | Más (deja todas terminar) |
| Diagnóstico | Peor (no sabés si el fallo es una combinación o varias) | Mejor (ves qué combinaciones rompen) |
| Caso típico | PR CI con feedback rápido | Release-grade: querés el panorama completo |

### 8.2 `cancel-in-progress: true` vs `false`

| Dimensión | `true` | `false` |
|-----------|--------|---------|
| Carga de infra | Menos (mata runs obsoletos) | Más (todos terminan) |
| Riesgo en CD | Alto (deja deploys a medias) | Bajo (serializa) |
| CI de PRs | Correcto (push nuevo deprecia el viejo) | Desperdicia minutos |
| CD a prod | Peligroso | Correcto |

### 8.3 Matriz estática vs dinámica

- **Estática** (lista en el YAML): simple, auditable con `git diff`, no requiere job previo.
- **Dinámica** (via `fromJSON` desde un output): necesaria para monorepos y pipelines condicionales, pero añade un hop (job de cómputo) y requiere disciplina para no filtrar strings maliciosos.

### 8.4 Outputs vs artefactos

- **Outputs**: strings cortos, en banda, sin almacenamiento adicional. Perfectos para tags, URLs, booleanos computados.
- **Artefactos** (`gha-07`): bytes arbitrarios, almacenados en el repo, con retención configurable. Para binarios, reports, SBOMs.

Regla: si cabe en una línea y es parte del "contrato lógico" entre jobs → output. Si es un archivo → artefacto.

---

## 9. Errores frecuentes

### 9.1 "El job dependiente nunca corre"

```yaml
build:
  needs: test
```

`needs: test` implica `if: success()`. Si **cualquier** combinación de la matriz `test` falla (y no es experimental con `continue-on-error`), `build` se saltea. Si querés que siempre corra con lógica propia:

```yaml
build:
  needs: test
  if: always() && !cancelled()
```

### 9.2 "El output llega vacío al siguiente job"

Tres causas comunes:

1. **Olvidaste declarar `outputs:` a nivel del job.** `steps.<id>.outputs.<key>` existe *dentro* del job, pero no se propaga automáticamente.
2. **Escribiste a stdout en vez de a `$GITHUB_OUTPUT`.** `echo "tag=v1"` sin `>> "$GITHUB_OUTPUT"` no persiste nada.
3. **El step no tiene `id:`.** Sin `id`, no podés referenciarlo como `steps.<id>.outputs.<key>`.

### 9.3 "El `include` crea jobs que no quería"

Un `include` que no coincide con ninguna combinación del producto cartesiano **añade** una fila nueva. Si solo querés *enriquecer* una combinación existente, el `include` debe coincidir *exactamente* en todas las claves originales de la matriz.

### 9.4 "Dos deploys corrieron a la vez igual"

Causa: definiste `concurrency` a nivel **step** (no existe) o solo en el workflow (afecta a *todos* los jobs, no solo deploy). La forma correcta es ponerlo a nivel **job** `deploy:`:

```yaml
deploy:
  concurrency:
    group: deploy-prod
    cancel-in-progress: false
```

### 9.5 "Mis outputs tienen saltos de línea raros"

Un `echo "key=$(comando)"` donde `comando` imprime varias líneas rompe el parseo (una línea = un par). Para valores multilínea, usá el formato heredoc:

```bash
{
  echo 'key<<EOF'
  comando_multilinea
  echo 'EOF'
} >> "$GITHUB_OUTPUT"
```

### 9.6 "`::set-output` deja warning"

Es la sintaxis vieja. Reemplazala por `>> "$GITHUB_OUTPUT"`. En workflows nuevos puede dejar de funcionar directamente.

### 9.7 Script injection por outputs no sanitizados

Si un output se construye con datos no confiables (p. ej. título de un issue), interpolarlo directamente en un `run:` es inyección de shell:

```yaml
# PELIGROSO
- run: echo "${{ needs.scan.outputs.title }}"
```

Pasalo por env var y usá `"$VAR"` entre comillas:

```yaml
- env:
    TITLE: ${{ needs.scan.outputs.title }}
  run: echo "$TITLE"
```

Esto es doctrina de `gha-02` que acá reaparece.

---

## 10. Buenas prácticas

- **Un workflow = un propósito.** `ci.yml` (lint/test), `release.yml` (build/publish), `deploy.yml` (CD). No un monolito con 30 jobs.
- **`permissions: contents: read` a nivel workflow.** Escalada mínima por job.
- **`fail-fast: false` en matrices donde el diagnóstico importa** (releases, matrices largas). `true` en PR CI.
- **`cancel-in-progress: true` en CI de PRs**, **`false` en CD a producción**.
- **Un output por idea.** No metas JSON gigantes en un output; propagá piezas simples.
- **Dale `id:` a todo step cuyo output te interese.** Es gratis y evita rework.
- **Siempre heredoc para valores multilínea.** Nunca `echo "notes=$(git log ...)"`.
- **Resumí en `$GITHUB_STEP_SUMMARY`.** Un run con summary útil ahorra lectura de logs.
- **Nombrá los grupos de `concurrency` con intención.** `deploy-prod` ≠ `deploy-${{ github.ref }}` — son modelos distintos.
- **Documentá qué `include`/`exclude` representan.** En seis meses nadie va a recordar por qué `macos-latest` + `python-3.11` estaba excluido. Comentario en el YAML.
- **Nunca interpoles input no confiable** (títulos de PR, nombres de rama controlados por el autor) en `run:`. Pasá por env y referenciá con `"$VAR"`.

---

## 11. Ejercicios recomendados

1. **`examples/01-matrix-python-os/`** — leer, entender la expansión, correr opcionalmente.
2. **`examples/02-needs-and-outputs/`** — ver el flujo del valor de un job a otro.
3. **`examples/03-concurrency-deploy-lock/`** — leer los dos escenarios documentados.
4. **`activities/01-matrix-with-include-exclude/`** — guided-lab, construir una matriz 2D con `include`/`exclude`. Dual-mode (local valida el YAML, live lo ejecuta).
5. **`activities/02-fan-out-fan-in/`** — **independent**. Construir un pipeline con fan-out matricial + aggregator con summary. Es la que valida la competencia real.

---

## 12. Evaluación

Respondé sin consultar la lección. Si tenés que buscar, releé la sección correspondiente.

**P1.** `strategy.matrix` con 3 dimensiones de 3 valores cada una (sin `include` ni `exclude`) genera cuántos jobs:
   - [ ] 3
   - [ ] 9
   - [ ] 27
   - [ ] Depende del `max-parallel`.

**P2.** Explicá en 2–3 frases por qué `::set-output` fue reemplazado por `$GITHUB_OUTPUT`. Nombrá la clase de vulnerabilidad que mitiga el cambio.

**P3.** Verdadero / falso:
   - [ ] `needs: test` implica `if: success()` por default.
   - [ ] Un `include` que coincide con una combinación existente la duplica.
   - [ ] `concurrency` a nivel step existe y funciona.
   - [ ] Dos ramas que empujan a la vez compiten por el mismo grupo `deploy-${{ github.ref }}`.
   - [ ] `$GITHUB_STEP_SUMMARY` se propaga como output al siguiente job.

**P4.** Dos pushes a `main` llegan con 10 segundos de diferencia. El workflow tiene:

```yaml
jobs:
  deploy:
    concurrency:
      group: deploy-prod
      cancel-in-progress: true
```

Explicá qué pasa con el run #1 y qué pasa con el run #2 (y en qué momento de cada uno).

**P5.** Un step produce `tag=v1.2.3` y querés que un job posterior lo use. Escribí el YAML mínimo necesario (step, declaración del output del job, referencia desde el otro job).

**P6.** Dado el fragmento:

```yaml
matrix:
  os: [ubuntu-latest, macos-latest]
  node: [18, 20]
  exclude:
    - os: macos-latest
      node: 18
  include:
    - os: ubuntu-latest
      node: 21
      experimental: true
```

Listá las combinaciones **exactas** que genera. ¿Cuántos jobs son?

**P7.** Diseño: tenés un monorepo con 15 paquetes. Un push toca 3. Querés buildearlos en paralelo con una matriz, luego publicar un release único si todos pasan. Describí la estructura de jobs (nombres, `needs`, qué job declara qué output). No escribas el YAML; describilo en texto.

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- **Workflow syntax** — <https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions>
- **`jobs.<id>.strategy.matrix`** — <https://docs.github.com/actions/using-jobs/using-a-matrix-for-your-jobs>
- **`jobs.<id>.needs`** — <https://docs.github.com/actions/using-jobs/using-jobs-in-a-workflow#defining-prerequisite-jobs>
- **`jobs.<id>.outputs`** — <https://docs.github.com/actions/using-jobs/defining-outputs-for-jobs>
- **Workflow commands and environment files** (`GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY`) — <https://docs.github.com/actions/using-workflows/workflow-commands-for-github-actions>
- **`concurrency`** — <https://docs.github.com/actions/using-jobs/using-concurrency>
- **Expressions and functions** (`fromJSON`, `toJSON`) — <https://docs.github.com/actions/learn-github-actions/expressions>

Lectura complementaria:

- GitHub Changelog, *"GitHub Actions: Deprecating `save-state` and `set-output` commands"* (octubre 2022).
- GitHub Blog, *"Prevent duplicate deployments with Actions concurrency"*.
- Blog de seguridad: patrones de **script injection** en Actions (Legit Security, Praetorian, Snyk — todos tienen posts verificables).
