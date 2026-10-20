# Ejemplo 03 — Traducir conceptos GHA → GitLab

> Objetivo: tener un **traductor** mental listo. Vas a leer `.gitlab-ci.yml` muchas veces en los módulos siguientes; conviene que la traducción sea instantánea.

## 1. Tabla de equivalencias (12 conceptos)

| # | GitHub Actions | GitLab CI/CD | Notas |
|---|----------------|--------------|-------|
| 1 | `workflow` (archivo `.github/workflows/*.yml`) | **`pipeline`** (un `.gitlab-ci.yml` por project; opcional dividir con `include:`) | GitLab tiene *un* archivo canónico; GHA tiene *N*. |
| 2 | `job` | **`job`** | Idéntico semánticamente. |
| 3 | `runs-on: ubuntu-latest` | **`image: ubuntu:22.04`** + `tags: [docker]` (o similar) | GitLab: ejecutor docker usa imagen explícita; `runs-on` ≈ selección por `tags:`. |
| 4 | `strategy.matrix` | **`parallel: matrix:`** | Semántica equivalente; sintaxis distinta. |
| 5 | `needs: [other-job]` | **`needs: [other-job]`** | Idéntico. |
| 6 | `uses: owner/action@v1` | **`extends: .reusable-job`** o **`include: - component: $CI_SERVER_FQDN/path@ver`** | GHA tiene Marketplace; GitLab usa Components + Catalog. |
| 7 | Reusable workflow (`uses: ./.github/workflows/foo.yml@ref`) | **CI/CD Component** con `spec:inputs:` | Equivalente moderno. |
| 8 | Composite action | **`extends:`** sobre hidden job (`.base-job`) o Component | Dos vías; para reuso serio se prefiere Component. |
| 9 | `secrets.FOO` | **`$FOO`** (variable protegida/masked) o **`secrets:` keyword** (desde Vault/SM) | GitLab: niveles Instance/Group/Project/Env/Pipeline. |
| 10 | `id-token: write` + OIDC trust | **`id_tokens:`** por job + trust policy con claims **de GitLab** | Claims distintas (ver §3). |
| 11 | PR event (`pull_request`) | MR event (`$CI_PIPELINE_SOURCE == "merge_request_event"`) | GitLab: Merge Request. |
| 12 | Required workflow (Enterprise) | **Compliance Pipeline** (Ultimate) | Mismo propósito. |

## 2. Ejemplo lado-a-lado: pipeline mínimo lint + test + build

### GHA (`.github/workflows/ci.yml`)

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ruff && ruff check .

  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r requirements.txt && pytest -q

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: python -m build
```

### GitLab (`.gitlab-ci.yml`)

```yaml
stages: [lint, test, build]

default:
  image: python:3.12-slim

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

lint:
  stage: lint
  script:
    - pip install ruff
    - ruff check .

test:
  stage: test
  needs: [lint]
  script:
    - pip install -r requirements.txt
    - pytest -q

build:
  stage: build
  needs: [test]
  script:
    - python -m build
```

Observa:

- **No hay `checkout` explícito**: GitLab lo hace por default al inicio del job (variable `GIT_STRATEGY`).
- **`image:`** es por default `python:3.12-slim` para todos los jobs vía `default:`; en GHA cada job declara `runs-on` individualmente.
- **`workflow:`** reemplaza el `on:` top-level; filtra el pipeline completo. Con `rules:` por job filtras job por job.
- **No hay `uses:`**: para reuso real, se extraería `.base-python` como hidden job o se consumiría un Component.

## 3. Diferencias que muerden al migrar

### 3.1 OIDC claims distintas

GHA JWT (resumido):

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:acme/checkout-api:ref:refs/heads/main",
  "repository": "acme/checkout-api",
  "ref": "refs/heads/main",
  "environment": "production"
}
```

GitLab ID Token (resumido):

```json
{
  "iss": "https://gitlab.com",
  "sub": "project_path:acme/checkout/api:ref_type:branch:ref:main",
  "namespace_path": "acme/checkout",
  "project_path": "acme/checkout/api",
  "ref": "main",
  "ref_type": "branch",
  "environment": "production"
}
```

Al migrar OIDC a AWS/GCP/Azure/Vault: la **trust policy** debe aceptar el nuevo `iss` **y** las nuevas claims. Pinnear por `project_path` + `ref` + `environment` es la práctica recomendada.

### 3.2 Secrets syntax

- GHA: `${{ secrets.FOO }}` (reemplazo en tiempo de template).
- GitLab: `$FOO` (var del entorno del runner). Mismo *riesgo de injection* si lo interpolas en shell sin cuidado.

### 3.3 No hay `uses: owner/action@v1`

En GHA tienes miles de acciones listas. En GitLab, para algo equivalente usas:

- **Templates oficiales** vía `include: - template: Jobs/SAST.gitlab-ci.yml` para scanners.
- **CI/CD Components** del Catalog para patrones reusables.
- `extends:` sobre hidden jobs tuyos para patrones internos.

### 3.4 `on_failure` / `always` / `manual`

- GHA: `if: failure()`, `if: always()`.
- GitLab: `when: on_failure`, `when: always`, `when: manual`, `when: delayed`.

### 3.5 Matrix

GHA:

```yaml
strategy:
  matrix:
    python: ["3.11", "3.12"]
    os: [ubuntu-latest, macos-latest]
```

GitLab:

```yaml
test:
  parallel:
    matrix:
      - PYTHON: ["3.11", "3.12"]
        OS: ["ubuntu", "macos"]
```

(Con la salvedad de que `tags:` elige el runner adecuado, no `runs-on`.)

## 4. Ejercicio mental

Toma un workflow GHA que conozcas (uno simple de tus notas de `github-actions`). Sin escribir nada:

1. Lista sus jobs y sus `needs:`.
2. Traduce `uses:` a `extends:` o `include:` candidato.
3. Decide dónde pondrías los secrets (Project var vs Group var).
4. Decide si el filtro `on:` se vuelve `workflow:` top-level o `rules:` por job.

Si logras hacer esto para 2 workflows reales, estás listo para `gl-02`.
