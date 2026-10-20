# gl-04 — Lección: rules, workflow, needs/DAG, parallel:matrix

Esta lección está pensada para alguien que ya ha completado el curso de **GitHub Actions** (en particular, matrices y `if:` por job) y acaba de aterrizar en GitLab CI. Si eso es tu punto de partida, lo que viene no es "aprender condicionales desde cero"; es **mapear vocabulario** y entender dos cosas que GitLab modela mejor que GHA:

1. **`workflow:` como filtro del pipeline entero** — resuelve el pain point clásico de "pipelines duplicados en MR" sin necesidad de condicionar job por job.
2. **`needs:` como DAG real** — cualquier job puede empezar en cuanto sus dependencias terminan, incluso si están en otro stage. Esto no es "optimización"; es la forma correcta de modelar pipelines no triviales.

---

## 1. El modelo mental: pipeline → stages → jobs → DAG opcional

Un `.gitlab-ci.yml` describe un **pipeline**. El pipeline se evalúa como:

1. **`workflow:`** decide si el pipeline existe. Si ninguna regla matchea (o la que matchea tiene `when: never`), **no se crea pipeline**.
2. Para cada job, **`rules:`** decide si el job existe en el pipeline, y con qué `when:` (`on_success`, `manual`, …).
3. Los jobs se ejecutan por **stages** en orden. Dentro de un stage, los jobs corren en paralelo.
4. Si un job declara **`needs:`**, deja de regirse por stages: arranca en cuanto sus `needs:` terminan OK. El pipeline se convierte en un **DAG**.

Nota de nomenclatura: GitLab llama "pipeline" a la ejecución; "job" al nodo que corre un `script:`. En GHA esto es "run" + "job". Lo relevante es que en GitLab el **stage** es sólo una línea de ordenación por defecto; **no es un objeto fuerte**. Una vez metes `needs:`, los stages pasan a ser decorativos.

---

## 2. `workflow:` top-level — el filtro que GHA no tiene

### 2.1 Problema que resuelve

En GHA, si no condicionas tus workflows con `on: pull_request` + `on: push`, acabas con **dos runs por commit en una PR** (una por push a la branch, otra por el pull_request). En GitLab el problema es el mismo si no haces nada: habría un pipeline por push a la branch y otro por la creación/update del MR. Los dos ejecutando los mismos jobs.

`workflow:` top-level se encarga de ese filtro **antes** de que GitLab construya el pipeline:

```yaml
workflow:
  rules:
    # Si estamos en un MR, correr siempre.
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    # Si estamos en main, correr siempre.
    - if: $CI_COMMIT_BRANCH == "main"
    # Si estamos en una branch que tiene un MR abierto, NO correr pipeline de branch
    # (el pipeline del MR ya cubre esos commits).
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    # Fallback: cualquier otra branch sin MR, correr.
    - if: $CI_COMMIT_BRANCH
```

**Idea clave**: `workflow:` es un filtro *todo-o-nada*. Si matchea una regla sin `when: never`, hay pipeline. Si todas matchean `when: never` o ninguna matchea, **no hay pipeline**. Esto no se puede expresar en GHA sin trucos (`if: github.event_name == 'pull_request' || github.event.pull_request == null`).

### 2.2 Variables útiles para `workflow:`

| Variable | Qué contiene |
|----------|--------------|
| `$CI_PIPELINE_SOURCE` | `push`, `merge_request_event`, `web`, `schedule`, `pipeline`, `trigger`, `api`. |
| `$CI_COMMIT_BRANCH` | Nombre de la branch del commit. Vacío en MR pipelines. |
| `$CI_MERGE_REQUEST_IID` | ID del MR si estamos en un pipeline de MR. |
| `$CI_OPEN_MERGE_REQUESTS` | Lista de MRs abiertos para la branch actual. |
| `$CI_COMMIT_TAG` | Nombre del tag si el push creó un tag. |
| `$CI_DEFAULT_BRANCH` | `main` en la mayoría de repos. |

---

## 3. `rules:` por job — reemplazo moderno de `only/except`

`only:` y `except:` están **legacy** desde GitLab 12. Toda documentación nueva usa `rules:`. Son más expresivos y, sobre todo, **composables**: cada regla puede traer su propio `when:`, `allow_failure:` y variables.

### 3.1 Formas de una regla

```yaml
test:
  stage: test
  script: ./run-tests.sh
  rules:
    # 1) Condición por expresión
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

    # 2) Condición por cambios en archivos
    - changes:
        - "src/**/*"
        - "tests/**/*"

    # 3) Condición por existencia de archivos en el repo
    - exists:
        - "Dockerfile"

    # 4) Combinación: si tocamos src/ en una MR, correr como job manual
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes: ["src/**/*"]
      when: manual
      allow_failure: true
```

### 3.2 Evaluación de reglas

Las reglas se evalúan **de arriba abajo**. La **primera** que matchea gana (incluidas sus `when:` y `allow_failure:`). Si ninguna matchea, el job **no se añade al pipeline** (equivalente a `when: never`).

**Error común**: poner una regla general antes de una específica y preguntarte por qué el job siempre corre. Las reglas son como un `switch` con fall-through al primer `case` que matchea.

### 3.3 `when: manual` y `allow_failure`

- `when: manual` convierte el job en un botón "Run" en la UI. Útil para deploys, data migrations, operaciones destructivas.
- `allow_failure: true` hace que el pipeline siga "verde" aunque el job falle. Combinado con `manual`, el job no bloquea.
- `when: delayed` + `start_in: 10 minutes` espera antes de arrancar — útil para rollouts graduales.

### 3.4 Equivalencias GHA ↔ GitLab

| GitHub Actions | GitLab |
|----------------|--------|
| `if: github.ref == 'refs/heads/main'` | `rules: - if: $CI_COMMIT_BRANCH == "main"` |
| `if: github.event_name == 'pull_request'` | `rules: - if: $CI_PIPELINE_SOURCE == "merge_request_event"` |
| `workflow_dispatch:` + `if:` | `rules: - if: $CI_PIPELINE_SOURCE == "web" when: manual` |
| `paths:` filter en el workflow | `rules: - changes: [...]` |

---

## 4. `needs:` — el DAG que corta wall clock

### 4.1 El modelo por defecto (sin `needs:`)

Sin `needs:`, el pipeline es **estrictamente secuencial por stages**:

```
stage: build     ──────────▶  stage: test     ──────────▶  stage: deploy
   build-amd64 (3m)             unit (5m)                   deploy-stg (2m)
   build-arm64 (3m)             lint (1m)
```

**Wall clock** = `max(stage build)` + `max(stage test)` + `max(stage deploy)` = `3 + 5 + 2 = 10 min`. El `lint` termina en 1 minuto pero bloquea el stage: nada avanza hasta que todo el stage `test` acabe.

### 4.2 Con `needs:` → DAG

```yaml
unit:
  stage: test
  needs: ["build-amd64"]
  script: ./test unit

lint:
  stage: test
  needs: []           # arranca inmediatamente, no espera a build
  script: ./lint

deploy-stg:
  stage: deploy
  needs: ["unit"]     # NO espera a build-arm64 ni a lint
  script: ./deploy stg
```

Ahora `deploy-stg` arranca en cuanto `unit` termina. `lint` no bloquea nada. **Wall clock** típico baja de `10` a `~7` min en este ejemplo. En pipelines reales con 20+ jobs la ganancia suele ser del **20–40%**.

### 4.3 Reglas importantes de `needs:`

1. Un job con `needs:` **sólo** espera a esos jobs. **Ignora los stages**.
2. Si uno de los `needs:` falla, el job se marca `skipped` (como `on_success` por defecto).
3. `needs: []` = "arranca ya, no esperes a nadie". Útil para linters.
4. Puedes pasar artefactos: `needs: - job: build - artifacts: true` (default true).
5. Límite de 50 `needs:` por job (configurable por proyecto).
6. Cross-pipeline `needs:` existe (`needs: - pipeline: $PARENT_PIPELINE_ID`) pero complica la trazabilidad.

### 4.4 Cuándo NO usar `needs:`

- Pipelines pequeños (<5 jobs): el overhead cognitivo no compensa.
- Cuando el orden por stages ya es correcto y nadie va a añadir jobs después.
- Cuando dependes del artefacto de **todo** un stage anterior (poco común en pipelines bien diseñados).

---

## 5. `parallel:` y `parallel: matrix:`

### 5.1 `parallel: N`

```yaml
load-test:
  parallel: 5
  script: ./run-load-test.sh  # usa CI_NODE_INDEX y CI_NODE_TOTAL para repartir
```

Lanza **5 copias** del job con `CI_NODE_INDEX` ∈ {1..5} y `CI_NODE_TOTAL=5`. El `script:` tiene que repartir el trabajo (p. ej. "esta copia corre los tests 2 de cada 5"). Útil para dividir cargas largas en 5 shards.

### 5.2 `parallel: matrix:`

El equivalente directo de `strategy.matrix` en GHA:

```yaml
test:
  stage: test
  image: python:$PY_VERSION
  parallel:
    matrix:
      - PY_VERSION: ["3.11", "3.12", "3.13"]
        OS_TAG: ["linux", "macos"]
  tags:
    - $OS_TAG
  script:
    - python --version
    - pytest -q
```

Esto expande a **6 jobs** (3 × 2) con nombres como `test: [3.11, linux]`, `test: [3.12, macos]`, …

Diferencias prácticas vs GHA:

| GHA | GitLab |
|-----|--------|
| `strategy.matrix.include:` añade combinaciones extra | Lista aparte dentro de `matrix:` (una nueva entrada) |
| `strategy.matrix.exclude:` quita combinaciones | **No existe directamente**; se obtiene duplicando la matriz y omitiendo o usando `rules:` por combinación |
| `strategy.fail-fast: false` | Por defecto GitLab **no es fail-fast**; para serlo: `parallel.matrix` con `allow_failure` en jobs y lógica adicional |
| `max-parallel` | No existe en `parallel: matrix:`; se controla a nivel de runner (concurrencia) |

**Nota importante** sobre `exclude`: GitLab no tiene equivalente puro. El patrón recomendado es escribir **dos entradas** en `matrix:` cubriendo sólo las combinaciones válidas, en lugar de una entrada grande con exclusiones. Es más verboso pero más explícito.

### 5.3 Variables disponibles

| Variable | Qué contiene |
|----------|--------------|
| `CI_NODE_INDEX` | Posición de esta instancia (1-based si `parallel: N`; vacío con `matrix:` — usa las vars de la matriz). |
| `CI_NODE_TOTAL` | Total de instancias. |
| Variables de la matriz | Expuestas como env vars con el nombre declarado (p. ej. `$PY_VERSION`). |

---

## 6. Child/parent pipelines (introducción)

Cuando el DAG crece a 50+ jobs, GitLab permite **dividirlo**:

```yaml
trigger-mobile:
  stage: build
  trigger:
    include: mobile/.gitlab-ci.yml
    strategy: depend   # el parent espera al child
```

Esto crea un pipeline **hijo** con su propio `.gitlab-ci.yml`. Útil para monorepos o para equipos que gestionan su propio pipeline. Se profundiza en `gl-05`.

---

## 7. Patrones y antipatrones

**Patrón 1 — `workflow:` + `rules:` cada job**: el `workflow:` filtra pipelines; cada job decide si corre dentro del pipeline. Divide responsabilidades.

**Patrón 2 — `needs: []` en linters**: cualquier job que sólo lea el repo debe arrancar ya, no esperar a `build`.

**Patrón 3 — `rules: changes:` para evitar correr tests cuando sólo cambia la documentación**:

```yaml
unit:
  rules:
    - changes: ["src/**/*", "tests/**/*", "pyproject.toml"]
```

**Antipatrón 1 — mezclar `only/except` y `rules:` en el mismo job**: no está soportado. Elige uno (y que sea `rules:`).

**Antipatrón 2 — stages lineales con 15 jobs y sin `needs:`**: cada stage espera al anterior entero. El wall clock se dispara. Si cada job sabe de qué depende, declara `needs:`.

**Antipatrón 3 — matrices gigantes con `exclude:` imaginario**: GitLab no tiene `exclude`. Si lo intentas replicar con `rules:` por combinación, el pipeline se vuelve ilegible. Mejor dos entradas chicas en `matrix:`.

---

## 8. Validación local sin runner

Para iterar sobre `.gitlab-ci.yml` sin un GitLab real:

- **Parse YAML**: `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" .gitlab-ci.yml`.
- **CI Lint API** (requiere un GitLab accesible): `glab ci lint` o `curl -X POST --form "content=@.gitlab-ci.yml" https://gitlab.com/api/v4/ci/lint`.
- **GitLab UI**: `Build → Pipeline editor → Validate` (misma API detrás).

En este módulo los validadores estructurales **sólo** usan `python3 + PyYAML`, nada remoto. Son suficientes para los casos conceptuales que practicamos.

---

## 9. Mapeo rápido GHA ↔ GitLab (resumen)

| GHA | GitLab | Notas |
|-----|--------|-------|
| `on:` top-level | `workflow:` + `rules:` por job | GitLab permite filtrar el pipeline entero. |
| `jobs.<name>.if:` | `rules: - if:` | Mismo rol; sintaxis distinta. |
| `jobs.<name>.needs:` | `needs:` | Igual concepto; GitLab exige mismo pipeline (o child). |
| `strategy.matrix:` | `parallel: matrix:` | Sin `exclude:` directo. |
| `strategy.fail-fast` | No tiene equivalente directo | Default no es fail-fast. |
| `concurrency:` | `resource_group:` | Serializa jobs con mismo nombre. |
| `permissions:` | `id_tokens:` + `secrets:` | OIDC se tratará en `gl-06`. |

---

## 10. Para fijar

- `workflow:` filtra pipeline; `rules:` filtran jobs. No mezcles responsabilidades.
- `only/except` están deprecated. Si lo ves en un repo heredado, migra a `rules:`.
- `needs:` es la pieza que convierte "pipeline con stages" en "DAG real". Es la mayor ganancia de performance de este módulo.
- `parallel: matrix:` es casi `strategy.matrix` de GHA, salvo por `exclude:`.
- `CI_NODE_INDEX`/`CI_NODE_TOTAL` reparten carga en `parallel: N`; las vars de la matriz se exponen con su nombre en `parallel: matrix:`.

Siguiente paso recomendado: hacer la actividad 02 (DAG con `needs:`) **primero** si vienes fuerte de GHA — el ejercicio concreto fija el modelo antes que la teoría de `rules:`.
