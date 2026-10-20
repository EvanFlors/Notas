# Lección — `.gitlab-ci.yml`, pipelines y runners

> **Precondición:** haber completado `gl-01` y tener el mapping GHA ↔ GitLab a mano. Esta lección asume que ya sabes qué es un *workflow* en GHA y un *pipeline* en general.

---

## 1. ¿Qué es `.gitlab-ci.yml`?

Es el **único archivo** que GitLab lee para construir pipelines de un proyecto. Vive en la raíz del repo por default (configurable en *Settings → CI/CD → General pipelines → CI/CD configuration file*). Es un **YAML** con una gramática *schema-less* en apariencia pero muy convencional: hay un conjunto cerrado de **keys top-level reservadas**, y *cualquier otra key del nivel superior se interpreta como el nombre de un job*.

Esto es importante y es diferente a GHA:

- En GHA los jobs viven *dentro de* `jobs:`. Es explícito.
- En GitLab los jobs viven *al mismo nivel* que `stages:`, `variables:`, etc. La única forma de que GitLab sepa "esto es un job" es por descarte: no es una key reservada.

### Keys top-level reservadas (las que necesitas memorizar hoy)

| Key | Qué hace |
|-----|----------|
| `stages:` | Lista ordenada de stages. Default: `[.pre, build, test, deploy, .post]` si no la declaras. |
| `variables:` | Mapa de variables globales inyectadas en el entorno de cada job. |
| `default:` | Defaults aplicados a todos los jobs (p. ej. `image:`, `before_script:`, `tags:`, `retry:`). |
| `workflow:` | Filtra el pipeline *entero* (si no matchea `workflow:rules:`, no se crea ni un job). Se profundiza en `gl-04`. |
| `include:` | Importa fragmentos YAML (local, project, remote, template). Detalle en `gl-05`. |
| `image:` | Imagen Docker por default cuando el executor es `docker`. |
| `services:` | Contenedores sidecar (p. ej. `postgres:16`). |
| `before_script:` / `after_script:` | Hooks que corren antes/después del `script` de cada job. |

Todo lo demás a nivel superior es un **job**. Un job *mínimo* legal:

```yaml
hello:
  script: echo "hola GitLab"
```

Eso solo basta: `hello` es el nombre del job, está en el *default stage* (`test`), corre en cualquier runner compatible, y no tiene `image:` así que depende del executor.

### Keys reservadas pero **menos** usadas al inicio

`concurrency`, `cache`, `artifacts`, `coverage`, `pages`, `trigger`, `inherit`, `retry`, `timeout`, `interruptible`, `environment`, `release`, `secrets`, `id_tokens`. Las verás en módulos posteriores (`gl-03`, `gl-04`, `gl-07`, `gl-08`).

---

## 2. Anatomía de un job

Un job típico de producción:

```yaml
unit-tests:
  stage: test
  image: python:3.12-slim
  tags: [docker, linux]
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'
  before_script:
    - pip install -r requirements-dev.txt
  script:
    - pytest -q
  after_script:
    - echo "Tests done at $(date -Iseconds)"
```

Lectura línea por línea:

- `stage: test` → en qué stage se agrupa este job.
- `image:` → imagen base del contenedor (solo relevante para el executor `docker`; en `shell` executor se ignora).
- `tags: [docker, linux]` → **selector de runner**: solo un runner que tenga *todos* estos tags lo recoge.
- `rules:` → bajo qué condiciones el job existe en el pipeline (reemplazo moderno de `only/except`).
- `before_script`/`script`/`after_script` → **listas de comandos shell** ejecutados en el runner. No es un DSL — es `/bin/sh -c` (o `bash`, dependiendo del executor).

### Error muy común: `script` no es un string, es una lista

```yaml
# MAL
hello:
  script: echo a && echo b

# BIEN
hello:
  script:
    - echo a
    - echo b
```

El primer caso técnicamente funciona (YAML lo acepta como escalar), pero mezclar operadores shell complica el reporting y la lectura del log. Convención: siempre lista.

### `script` corre en *una* shell, pero cada comando se *loggea* como step

En la UI de GitLab verás cada línea del `script` como un step colapsable (desde GitLab 17.x — colapsables mejorados en 2024). Esto importa para debugging: comandos cortos y expresivos > un gran `bash -c "..."` monolítico.

---

## 3. Modelo pipeline → stage → job

Un **pipeline** es una ejecución del `.gitlab-ci.yml` disparada por un evento (push, MR, schedule, API, trigger). Agrupa **stages** que agrupan **jobs**.

Reglas de ejecución (sin `needs:`):

1. Los stages corren en el orden de `stages:`.
2. Dentro de un stage, los jobs corren en **paralelo** (limitado por la capacidad del runner/pool).
3. Si **cualquier** job de un stage falla, los stages siguientes no corren (salvo `when: on_failure` o `when: always`).
4. Wall-clock del pipeline ≈ `sum(max(duration of each stage))`.

### Mental model: el stage es una barrera de sincronización

```
stages:
  - lint
  - test
  - build

lint-yaml:    { stage: lint,  script: [yamllint .] }
lint-shell:   { stage: lint,  script: [shellcheck scripts/*.sh] }
unit-tests:   { stage: test,  script: [pytest -q] }
build-image:  { stage: build, script: [docker build -t app .] }
```

`lint-yaml` y `lint-shell` corren a la vez. Cuando *ambos* terminan OK, arranca `unit-tests`. Cuando ese termina, arranca `build-image`. Si `lint-shell` falla, nada más corre.

Esto es el "modelo clásico" de GitLab. Es intuitivo pero **desperdicia tiempo**: `build-image` podría empezar en cuanto `unit-tests` acaba, incluso si otro job hipotético del stage `test` sigue corriendo, si existiera.

El **DAG** con `needs:` rompe esa barrera y es tema de `gl-04`. Por ahora: *piensa en stages como barreras*.

---

## 4. `tags:` — el contrato runner ↔ job

Un **runner** se registra con una lista de **tags** (strings libres: `docker`, `linux`, `gpu`, `k8s-prod`, `arm64`, `windows-2022`, etc.). Un **job** declara `tags:` indicando qué runner lo puede recoger.

Regla de matching:

- Un runner recoge el job si y solo si **tiene todos los tags del job** (y, por default, no está marcado como *untagged*).
- Un job **sin `tags:`** solo lo pueden recoger runners configurados para aceptar jobs sin tags (opción *Run untagged jobs* en el runner).

### Patrón de SaaS runners (`gitlab.com`)

Los *shared SaaS runners* vienen pre-taggeados por GitLab. En 2026 los tags canónicos son algo como:

- `saas-linux-small-amd64`
- `saas-linux-medium-amd64`
- `saas-linux-large-amd64`
- `saas-linux-small-arm64`
- `saas-macos-medium-m1` (gated por plan)
- `saas-windows-medium-amd64` (gated por plan)

Para ejecutar en el default (small Linux amd64) basta con **no poner tags** o poner `tags: [saas-linux-small-amd64]`. Ambos funcionan en `gitlab.com`.

### Patrón de runners propios (self-managed / self-hosted)

Convención común:

- `linux`, `arm64`, `gpu`, `k8s`, `prod`, `tools-image`, `secrets-vault`, `large`.

Nunca metas información sensible en tags: son **públicos** para cualquiera que vea el pipeline. Nunca uses `tags: [token-abc123]`.

---

## 5. Executors — por qué `image:` sí importa

Un runner usa **un executor** declarado en su `config.toml`:

| Executor | Qué hace |
|----------|----------|
| `shell` | Ejecuta `script` directamente en el host del runner (como `bash -c`). Peligroso en runners compartidos (job rompe el host). |
| `docker` | Lanza un contenedor por job. **Usa `image:` del job o del `default:`**. Es el executor más común en SaaS. |
| `kubernetes` | Lanza un pod por job. Igual: respeta `image:`. Es el patrón en K8s on-prem. |
| `docker-machine` | **Deprecado**. Autoescalaba VMs. Reemplazado por **Fleeting** (`gl-06`). |
| `virtualbox` / `ssh` | Nichos. Rara vez. |
| `custom` | Hooks propios (`prepare`, `run`, `cleanup`). Para casos exóticos. |

El executor **lo elige el administrador del runner**, no el YAML del pipeline. El YAML solo *pide*: "quiero esta `image:` y estos `services:`". Si el executor es `docker` o `kubernetes`, los honra. Si es `shell`, los ignora.

### `services:` — sidecars al estilo docker-compose simplificado

```yaml
pytest:
  image: python:3.12-slim
  services:
    - postgres:16
  variables:
    POSTGRES_PASSWORD: test
    POSTGRES_DB: app
    DATABASE_URL: postgres://postgres:test@postgres:5432/app
  script:
    - pip install -r requirements.txt
    - pytest -q
```

Cada `service` arranca como contenedor sidecar en la misma red del job. El hostname por default es el nombre de la imagen (`postgres`). Útil para integration tests.

---

## 6. Tipos de runner

Tres **scopes** de runner:

| Scope | Dónde se configura | Quién lo ve |
|-------|--------------------|-------------|
| **Shared (Instance)** | Admin de la instancia (en SaaS: GitLab) | Todos los proyectos de la instancia |
| **Group** | Settings de un group/subgroup | Todos los proyectos del group y sus subgroups |
| **Project** | Settings de un project | Solo ese project |

Mental model:

- *Shared SaaS* = "runners de la casa", gratis-con-cuota en Free, elásticos.
- *Group runners* = pool compartido por un group (típicamente una org o un BU). Útil para runners con **tooling específico** (p. ej. runner con `terraform` y `jq` preinstalados) o con **secretos de infra** restringidos a ese group.
- *Project runners* = dedicados. Útiles para workloads *muy* específicos o con requerimientos de aislamiento (p. ej. runner que solo monta un VPN hacia una cuenta AWS determinada).

### Shared SaaS vs Group runner propio — el eje de decisión

| Criterio | Shared SaaS | Group runner propio |
|----------|-------------|---------------------|
| Setup | Cero | Alto (VM/K8s + registro + mantenimiento) |
| Coste directo | Minutos CI/CD (free tier + overage) | Infra (VM/K8s pod) + tiempo de operar |
| Red privada | No por default | Sí (puedes meter el runner en tu VPC) |
| Secretos a mano | Vía variables de GitLab | Puedes montar Vault/sidecar/IMDS |
| Autoscaling | Automático y transparente | Fleeting / K8s cluster autoscaler |
| Compliance / aire acotado | Difícil (shared pool) | Fácil (tus runners, tu política) |

Esto da pie a la actividad 02 (ADR shared vs group).

---

## 7. Registration tokens vs authentication tokens

Historia breve:

- **Registration tokens** — forma clásica. Un token por *scope* (instance/group/project). Cualquiera con el token podía registrar un runner.
- **Authentication tokens** — forma moderna (GitLab 16+). Primero *creas* el runner en la UI o con `glab runner create`, obtienes un **auth token específico de ese runner**, y lo usas para arrancar el `gitlab-runner` daemon.

**Registration tokens están deprecados**. En GitLab 17+ se puede *desactivar* su uso a nivel instancia. La vía recomendada en 2026 es:

```bash
# 1. En GitLab UI (o glab): crea el runner, obtén $RUNNER_TOKEN
glab runner create --group acme/platform --tag-list docker,linux --executor docker

# 2. En el host del runner:
gitlab-runner register \
  --non-interactive \
  --url https://gitlab.com \
  --token "$RUNNER_TOKEN" \
  --executor docker \
  --docker-image alpine:3.20
```

El token es *por runner*, revocable, y no permite registrar otros runners.

---

## 8. Pending jobs — las 3 causas que verás 80% del tiempo

Un job queda `pending` cuando **ningún runner lo recoge**. Causas, en orden de frecuencia:

1. **Tags mismatch**: el job pide `tags: [docker, prod-tools]` y ningún runner tiene *todos* esos tags.
2. **Runner offline**: el daemon `gitlab-runner` no está corriendo en el host, o perdió conectividad.
3. **Cuota agotada** (SaaS Free): se consumieron los minutos CI/CD del mes.

Diagnóstico:

- *Settings → CI/CD → Runners*: ver qué runners están online y qué tags expone cada uno.
- UI del job: en el panel derecho hay un bloque "runners" que lista qué runners *podrían* haberlo recogido.
- Si usas `tags: [X]` y no hay runner con `X`, GitLab avisa (desde 16.x) con un mensaje claro.

### Mental model

> Un job sin `tags:` **espera un runner que acepte jobs sin tags**. En `gitlab.com` eso lo cumplen los shared runners por default. En self-managed, no siempre: hay admins que exigen que todos los jobs lleven tags.

---

## 9. Mapping desde GitHub Actions (consolidación)

| GHA | GitLab |
|-----|--------|
| `.github/workflows/ci.yml` | `.gitlab-ci.yml` |
| `jobs: { build: {...} }` | `build: {...}` (job al nivel superior) |
| `jobs.build.steps: - run: ...` | `build.script: - ...` |
| `jobs.build.runs-on: ubuntu-latest` | `tags: [saas-linux-small-amd64]` (o sin tags en SaaS) |
| `jobs.build.container: python:3.12` | `image: python:3.12` |
| `jobs.build.services: postgres: image: postgres` | `services: [postgres:16]` |
| `needs: [lint]` | `stage: build` (clásico) o `needs: [lint]` (DAG, `gl-04`) |
| `if: github.event_name == 'pull_request'` | `rules: - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` |

### Divergencias que importan

1. **No hay `uses:`**. GitLab no tiene "Marketplace de Actions". Reuso = `include:` (y en `gl-05`, **CI/CD Components**).
2. **No hay `strategy.matrix`** en la raíz del job: lo equivalente es `parallel: matrix:` (`gl-04`).
3. **El job es la unidad de reporting**, no el step. En GitLab un job es un contenedor con un `script` que es una lista de comandos. En GHA cada `step` es más granular.
4. **Permisos**. En GHA tienes `permissions:` en el workflow para el `GITHUB_TOKEN`. En GitLab el equivalente del token OIDC es **ID Tokens** (`gl-03`); el `CI_JOB_TOKEN` es por job y tiene su propia política de scopes (`gl-03`).

---

## 10. Checklist mental antes de empujar un `.gitlab-ci.yml`

- [ ] ¿Declaré `stages:` explícitamente? (Buena práctica, aunque el default existe.)
- [ ] ¿Cada job tiene `stage:`? (Si no, cae en `test` por default.)
- [ ] ¿Cada job tiene `script:` como **lista**?
- [ ] ¿`image:` acorde al executor del runner que lo recogerá?
- [ ] ¿`tags:` acorde a los runners disponibles? Si tengo dudas en SaaS → sin tags.
- [ ] ¿Reemplacé cualquier `only/except` por `rules:` (si estoy portando algo viejo)?
- [ ] ¿El pipeline hace sentido como DAG mental? (Si el stage `build` depende de `test`, OK. Si `build` *no* depende de `test`, considera `needs:` — pero eso es `gl-04`.)
- [ ] ¿Verifiqué localmente con `python3 -c 'import yaml; yaml.safe_load(open(".gitlab-ci.yml"))'`? (El lint oficial es `gitlab-ci-lint`; si no lo tienes, el parse de YAML + revisión manual cubre el 90%.)

---

## Lectura complementaria

- `examples/01-first-pipeline/` — el YAML minimalista.
- `examples/02-stages-and-jobs/` — 3 stages y jobs paralelos.
- `examples/03-docker-executor-image/` — `image:` y `services:`.
- `resources/links.md` — documentación oficial.
