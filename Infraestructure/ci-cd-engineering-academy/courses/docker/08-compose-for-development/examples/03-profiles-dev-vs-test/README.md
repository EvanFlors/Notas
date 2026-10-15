# Ejemplo 03 — Profiles: `dev` vs `test`

## Concepto que demuestra

Un mismo `compose.yaml` describe un stack **base** (`api` + `db`) y dos servicios **opcionales**: un `seeder` que carga fixtures (perfil `dev`) y un `tests` que corre pytest (perfil `test`). Un servicio con `profiles:` **no arranca** salvo que actives el perfil al que pertenece.

## Objetivo

Al terminar deberías poder responder:

- ¿Qué servicios se levantan con `docker compose up` sin flags?
- ¿Y con `--profile test`?
- ¿Y con `--profile dev --profile test`?

## Archivos

```
03-profiles-dev-vs-test/
├── README.md
├── compose.yaml
└── app/
    ├── Dockerfile
    ├── requirements.txt
    ├── main.py
    ├── seed.py
    └── test_app.py
```

### `compose.yaml`

```yaml
services:
  api:
    build: ./app
    ports:
      - "8003:8000"
    environment:
      DATABASE_URL: postgresql://postgres:dev@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: dev
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 3s
      retries: 10

  seeder:
    build: ./app
    command: ["python", "seed.py"]
    environment:
      DATABASE_URL: postgresql://postgres:dev@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy
    profiles: ["dev"]

  tests:
    build: ./app
    command: ["pytest", "-q", "test_app.py"]
    environment:
      DATABASE_URL: postgresql://postgres:dev@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy
    profiles: ["test"]
```

## Cómo correrlo

```
# Solo api + db (seeder y tests NO arrancan)
docker compose up -d --build --wait
docker compose ps
docker compose down -v

# Base + seeder (perfil 'dev')
docker compose --profile dev up -d --build --wait
docker compose ps                      # api, db, seeder visibles
docker compose logs seeder             # ver output
docker compose down -v

# Base + tests (perfil 'test') — run efímero
docker compose --profile test run --rm tests
docker compose down -v
```

## Qué observar

- Sin perfiles, `docker compose ps` solo lista `api` y `db`. `seeder` y `tests` no se crean.
- `docker compose --profile dev config` muestra el YAML resuelto con `seeder` incluido.
- Un servicio con `profiles:` sigue existiendo en el YAML aunque nunca lo levantes; solo aparece al activar su perfil.

## Limpieza

```
docker compose --profile dev --profile test down -v
```
