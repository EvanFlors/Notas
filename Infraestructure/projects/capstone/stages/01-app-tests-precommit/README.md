# Capstone — Etapa 1: App + Tests + Pre-commit

> Fase 5 del programa · Dominios tocados: D1 (fundamentos), D4 (versionamiento), D9 (quality gates locales).
> Stack fijado para todo el capstone: **GHA + Terraform + K8s (kind local; EKS/GKE/AKS walkthrough) + Argo CD + Prometheus Operator + OpenTelemetry + cosign/syft/kyverno/falco**.
> Esta etapa es **local-first**: todavía no hay nada en la nube, ni CI, ni contenedores.

---

## 1. Resumen de la etapa

**Objetivo.** Dejar en el repositorio una aplicación FastAPI + PostgreSQL funcional, con suite de pruebas en pytest por encima del 80 % de cobertura y una red de seguridad local vía `pre-commit` que bloquea estilos malos, tipado roto, YAML inválido, espacios al final y secretos antes de que lleguen al remoto.

**Delta vs. "nada previo".** Esta es la primera etapa, no hay delta funcional contra una etapa anterior, pero sí hay un delta explícito contra un *starter* vacío: pasamos de "no hay app" a "la app arranca, responde `/healthz`, persiste tareas en SQLite (local) o Postgres (si está disponible), tiene migraciones Alembic y una suite verde".

**Fuera de scope (lo verás en etapas posteriores).**

- Autenticación de usuarios, RBAC, OAuth → se discutirá cuando entre API Gateway.
- Dockerfile y Compose → Etapa 4.
- CI en GitHub Actions → Etapa 3.
- Firma de artefactos, SBOM, Terraform, Kubernetes, GitOps, observabilidad → etapas 5 en adelante.
- Rate limiting, tracing distribuido, caching → se añaden cuando aporten valor pedagógico.

---

## 2. Arquitectura al cierre de esta etapa

```
+-----------------------------+        +------------------------------+
|       Developer laptop      |        |   Pre-commit hooks (local)   |
|                             |        |                              |
|   $ uvicorn app.main:app    |        |  ruff -> black -> mypy       |
|                v            |        |  detect-secrets -> yamllint  |
|          +-----------+      |        |  trailing-whitespace         |
|   HTTP ->| FastAPI   |      |        +-------------^----------------+
|          |  app      |      |                      | git commit
|          +-----+-----+      |                      |
|                |            |             +--------+--------+
|                v            |             |   git working   |
|          +-----------+      |             |   tree          |
|          | SQLAlchemy|      |             +-----------------+
|          |  + Alembic|      |
|          +-----+-----+      |
|                |            |
|                v            |
|          +-----------+      |          +---------------------+
|          | SQLite    |------+--opt-->  | PostgreSQL 16 local |
|          | app.db    |      |          | (docker/pg_ctl)     |
|          +-----------+      |          +---------------------+
|                             |
|   $ pytest -q               |
|          |                  |
|          v                  |
|   coverage >= 80 %          |
+-----------------------------+
```

**Entradas.** Peticiones HTTP del developer (curl, httpie, Swagger UI en `/docs`).
**Salidas.** Respuestas JSON + filas persistidas + reportes de pytest/coverage/pre-commit en terminal.
**Resource list (local).** Un intérprete Python 3.12, un venv, un fichero SQLite por defecto (opcionalmente un contenedor Postgres si el estudiante quiere ejercitar la ruta real). Cero recursos cloud.

---

## 3. Prerrequisitos verificados

Como es la etapa 1, no hay prerrequisitos de etapas anteriores del capstone. Solo prerrequisitos de entorno:

- [ ] `python3 --version` → 3.12.x
- [ ] `git --version` disponible
- [ ] `pip install --user pre-commit` o `pipx install pre-commit`
- [ ] Opcional: `docker` disponible para levantar Postgres local
- [ ] Opcional: `psql` cliente para verificar la conexión

Si algo falta, cerrar primero esos huecos antes de continuar; esta etapa asume un laptop con Python moderno y git.

---

## 4. Implementación guiada

Los pasos están pensados para hacerse una vez; los *drills* repetibles viven en `activities/`.

### 4.1 Crear el entorno virtual

```bash
cd projects/capstone/stages/01-app-tests-precommit/app
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e '.[dev]'
```

**Por qué `pip install -e '.[dev]'` y no `requirements.txt`:** `pyproject.toml` es la fuente canónica. `-e` deja la app importable desde los tests sin trucos en `PYTHONPATH`, y el extra `dev` separa deps de runtime de deps de calidad.

### 4.2 Levantar la base de datos

Por defecto, la app usa SQLite (`sqlite:///./app.db`), ideal para arrancar sin fricción. Para la ruta Postgres:

```bash
docker run --rm -d \
  --name cap-pg \
  -e POSTGRES_PASSWORD=dummy_pw_change_me \
  -e POSTGRES_USER=capstone \
  -e POSTGRES_DB=capstone \
  -p 5432:5432 \
  postgres:16-alpine

export DATABASE_URL=postgresql+psycopg://capstone:dummy_pw_change_me@localhost:5432/capstone
```

**Por qué `postgresql+psycopg`:** fuerza al driver moderno (`psycopg[binary]==3.x`), no al legacy `psycopg2`.

### 4.3 Ejecutar migraciones

```bash
alembic upgrade head
```

**Por qué Alembic desde la etapa 1:** el esquema va a evolucionar en etapas posteriores (añadiremos campos, tablas, índices). Sin migraciones ahora, dentro de 4 etapas rehacemos todo. Mejor caro-barato-ahora que gratis-ahora-caro-después.

### 4.4 Arrancar la app

```bash
uvicorn app.main:app --reload --port 8000
```

Verificar:

```bash
curl -s localhost:8000/healthz | jq .
curl -s -X POST localhost:8000/tasks -H 'content-type: application/json' \
  -d '{"title":"capstone","done":false}' | jq .
curl -s localhost:8000/tasks | jq .
```

### 4.5 Suite de pruebas

```bash
pytest -q
```

El `pyproject.toml` ya fija `--cov=app --cov-fail-under=80`. Si cae por debajo, pytest falla.

### 4.6 Pre-commit

Desde la raíz del *repo*:

```bash
pre-commit install
pre-commit run --all-files
```

**Por qué estos hooks concretos:**

- `ruff`: lint rápido en Rust, reemplaza flake8+isort+pyupgrade.
- `black`: formato determinista, cero debates de estilo.
- `mypy`: tipado estático; obliga a declarar contratos.
- `detect-secrets`: baseline + diff para que no se cuele un token real.
- `yamllint`: evita YAMLs rotos antes de que lleguen a GHA (etapa 3) o Kubernetes (etapa 7).
- `trailing-whitespace` + `end-of-file-fixer`: higiene básica.

---

## 5. Actividades del estudiante

Viven bajo `activities/`. Cada una es ejecutable independientemente.

| ID activity | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-01-01-bootstrap-app` | guided-lab | 40 min | Levantar la app desde cero, hacer un CRUD de `Task` y responder `/healthz`. |
| `cap-01-02-pytest-coverage` | independent | 50 min | Añadir pruebas hasta superar 80 % de cobertura real; justificar branches no cubiertas. |
| `cap-01-03-precommit-debug` | debug | 35 min | Reparar un `.pre-commit-config.yaml` roto y archivos sucios hasta que `pre-commit run --all-files` quede verde. |

El criterio de "al menos una actividad independent o debug" se cumple con 2 y 3.

---

## 6. Entregables

Al cerrar la etapa el estudiante debe poder mostrar:

1. Carpeta `app/` con `pyproject.toml`, código funcional, migración inicial Alembic, y `tests/` con cobertura ≥ 80 %.
2. `.pre-commit-config.yaml` con los 6 hooks del punto 4.6 pasando limpios.
3. `README.md` del stage (este archivo) marcado como leído y seguido.
4. Las 3 actividades con sus `validate.sh` en verde.
5. Un commit limpio en la rama local (no se requiere push a remoto todavía).

---

## 7. Pruebas y criterios de aceptación

Chequeos automáticos:

- [ ] `pytest -q` sale en 0 con coverage ≥ 80 %.
- [ ] `pre-commit run --all-files` sale en 0.
- [ ] `alembic upgrade head` idempotente (correr dos veces, segunda es no-op).
- [ ] `curl /healthz` devuelve `{"status":"ok"}` con HTTP 200.
- [ ] Cada actividad: su `tests/validate.sh` sale en 0.

Criterios de calidad:

- [ ] Cero secretos reales o plausibles en el árbol (todo lo sensible es `dummy_*`).
- [ ] Deps pineadas en `pyproject.toml`.
- [ ] Tipado explícito en firmas públicas (`mypy --strict` no se exige todavía, pero sí sin errores en modo relajado).

---

## 8. Costos y limpieza

**Costo cloud:** $0.00 — todo corre en el laptop.

**Limpieza:**

```bash
docker rm -f cap-pg 2>/dev/null || true
cd projects/capstone/stages/01-app-tests-precommit/app
rm -rf .venv app.db .pytest_cache .mypy_cache .ruff_cache
rm -rf /tmp/cap-01-*
```

Sin recursos cloud no hay nada que destruir con `terraform` o similar.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El estudiante pelea con `psycopg` nativo en macOS/arm64. | Default a SQLite; Postgres es *opt-in* vía `DATABASE_URL`. |
| Coverage ≥ 80 % se consigue con tests triviales. | La actividad 2 exige justificar branches no cubiertas en un `REFERENCE.md`; se evalúa manualmente también. |
| Un hook de `pre-commit` descarga red y falla offline. | `pre-commit` cachea en `~/.cache/pre-commit`; se corre `pre-commit install-hooks` una vez con red disponible. |

**Hints progresivos** (en caso de atasco, el estudiante los pide en orden):

1. ¿Está `.venv` activado? `which python` debería apuntar dentro de `.venv`.
2. ¿Falla Alembic? Revisa que `DATABASE_URL` apunte al mismo sitio que `alembic.ini` espera (variable `sqlalchemy.url`).
3. ¿Falla `detect-secrets`? Regenera el baseline: `detect-secrets scan > .secrets.baseline`.

---

## 10. Puente con la siguiente etapa

**Qué habilita esta etapa.** La etapa 2 (Versionamiento + releases) asume que ya existe un árbol estable que vale la pena taggear y versionar. Si la suite no es verde o `pre-commit` no corre, no tiene sentido empezar a hablar de SemVer.

**Qué dejamos corriendo.** Nada permanente. El venv y los hooks son reconstruibles.

**Cliffhanger.** Si cada commit ya pasa por `pre-commit`, ¿qué pasa cuando varios developers trabajan en paralelo y el `main` ya acepta merges? ¿Cómo le decimos al mundo que "esto que está en `main` es la versión 0.1.0 que acabamos de probar"? Esa es la etapa 2.
