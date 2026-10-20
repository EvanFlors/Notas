# Ejemplo 02 — Healthcheck y `depends_on: condition: service_healthy`

## Concepto que demuestra

La diferencia operativa entre `depends_on` corto (solo espera a **arranque**) y `depends_on` con `condition: service_healthy` (espera a **listo**).

## Contexto

Ejemplo 01 arrancaba `api` antes de que Postgres aceptara conexiones. Si tu app no reintenta, el primer request a `/db` falla. Aquí lo arreglamos declarando un healthcheck sobre Postgres y pidiendo a Compose que **espere a que esté sano** antes de arrancar `api`.

## Objetivo

Al terminar deberías poder responder:

- ¿Qué comando corre dentro del contenedor de Postgres para el healthcheck?
- ¿Qué significan `interval`, `timeout`, `retries`, `start_period`?
- ¿Por qué `curl -s` (sin `-f`) sería un bug sutil en un healthcheck HTTP?

## Archivos

```
02-healthcheck-and-depends-on/
├── README.md
├── compose.yaml
└── app/
    ├── Dockerfile          # idéntico al ejemplo 01
    ├── requirements.txt
    └── main.py
```

### `compose.yaml`

```yaml
services:
  api:
    build: ./app
    ports:
      - "8002:8000"
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
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 2s
      timeout: 3s
      retries: 20
      start_period: 10s
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## Cómo correrlo

```
cd examples/02-healthcheck-and-depends-on
docker compose up -d --build --wait
docker compose ps
curl -fsS http://localhost:8002/db
```

Con `--wait`, el comando no retorna hasta que **todos los servicios con healthcheck** están `healthy` (y los sin healthcheck están `started`). Si `--wait` retorna 0, el primer `curl /db` **siempre** tiene que funcionar.

## Qué observar

- `docker compose ps` muestra `db` con `(healthy)`. Compara con el ejemplo 01 donde no había estado de salud.
- `api` no arranca hasta que `db` está `healthy`. Mira los timestamps en `docker compose logs`.
- Si cambias `test:` a algo que falle (p. ej. `pg_isready -U nouser`) y re-levantas, `db` queda `unhealthy` y `api` nunca arranca — Compose aborta con error.

## Limpieza

```
docker compose down -v
```
