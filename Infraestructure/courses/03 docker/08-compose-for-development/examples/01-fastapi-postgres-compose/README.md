# Ejemplo 01 — FastAPI + Postgres con Compose

## Concepto que demuestra

El `compose.yaml` **mínimo útil** para un stack real de dev: una app FastAPI que lee de una base Postgres, con dependencias declaradas, red implícita del proyecto y volumen nombrado para persistir datos.

## Contexto

Es el punto de partida de todo el módulo. Entenderlo bien hace triviales los otros dos ejemplos.

## Objetivo

Al terminar deberías poder responder:

- ¿Qué recursos crea Compose al ejecutar `docker compose up -d`?
- ¿Cómo resuelve `api` el hostname `db`?
- ¿Dónde quedan los datos de Postgres cuando ejecutas `docker compose down`? ¿Y con `down -v`?

## Prerrequisitos

- Docker Engine o Docker Desktop recientes con el plugin `compose` v2.
- Verifica con `docker compose version` (debe decir `v2.x`).

## Archivos del ejemplo

```
01-fastapi-postgres-compose/
├── README.md
├── compose.yaml
└── app/
    ├── Dockerfile
    ├── requirements.txt
    └── main.py
```

### `compose.yaml`

```yaml
# compose.yaml
# Nota: NO declarar `version:` — Compose v2 lo ignora y emite warning.
services:
  api:
    build: ./app
    ports:
      - "8001:8000"
    environment:
      DATABASE_URL: postgresql://postgres:dev@db:5432/postgres
    depends_on:
      - db

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: dev
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

> Nota: aquí usamos `depends_on` en **forma corta** a propósito. Verás en los logs
> que `api` arranca antes de que Postgres acepte conexiones y hay que reintentar.
> El ejemplo 02 arregla esto con `condition: service_healthy`.

### `app/main.py`

Mini-app FastAPI con dos endpoints: `/` (hola) y `/db` (chequea conexión a Postgres).

### `app/Dockerfile`

Base `python:3.12-slim`, instala `fastapi`, `uvicorn`, `psycopg[binary]`, copia el código, expone 8000.

## Cómo correrlo

```
cd examples/01-fastapi-postgres-compose
docker compose up -d --build
docker compose ps
curl -fsS http://localhost:8001/
curl -fsS http://localhost:8001/db
docker compose logs api | tail -20
```

## Qué observar

1. `docker compose ps` muestra `api` y `db`. El primer intento de `curl /db` puede fallar si Postgres aún no está listo — reintenta.
2. `docker network ls` muestra `01-fastapi-postgres-compose_default` (o similar, dependiente del nombre de dir).
3. `docker volume ls` muestra `01-fastapi-postgres-compose_pgdata`.
4. `docker compose exec api getent hosts db` resuelve a la IP del contenedor de Postgres.

## Limpieza

```
docker compose down -v
```

Esto borra contenedores, network y el volumen `pgdata`. Si solo haces `down` (sin `-v`), el volumen persiste y re-usar `up` lo monta otra vez.
