# Ejemplo 02 — Matriz de instrumentation libraries (Python)

Referencia rápida de los paquetes `opentelemetry-instrumentation-*` más usados en el ecosistema Python. La lista no es exhaustiva; el **registry** oficial vive en el repo `opentelemetry-python-contrib` y en `opentelemetry.io/ecosystem/registry/`.

## Convenciones de la tabla

- **Signal**: `T` traces, `M` metrics, `L` logs.
- **Nivel de madurez**: valoración subjetiva basada en uso en producción (verifica siempre contra el status page oficial antes de adoptar).
- **Spans típicos**: qué abre el instrumentor por default.

## Core HTTP / web frameworks

| Paquete | Signal | Madurez | Spans típicos |
|---------|--------|---------|----------------|
| `opentelemetry-instrumentation-fastapi` | T,M | alta | SERVER por request, atributos `http.*` según semconv HTTP v1 |
| `opentelemetry-instrumentation-flask` | T,M | alta | SERVER por request |
| `opentelemetry-instrumentation-django` | T,M | alta | SERVER por request + middleware |
| `opentelemetry-instrumentation-starlette` | T,M | alta | SERVER por request |
| `opentelemetry-instrumentation-asgi` | T | alta | capa baja; FastAPI/Starlette la usan por debajo |
| `opentelemetry-instrumentation-wsgi` | T | alta | capa baja; Flask/Django la usan |

## HTTP clients

| Paquete | Signal | Madurez | Spans típicos |
|---------|--------|---------|----------------|
| `opentelemetry-instrumentation-requests` | T,M | alta | CLIENT por llamada; `http.request.method`, `url.full` |
| `opentelemetry-instrumentation-httpx` | T,M | alta | CLIENT (sync + async) |
| `opentelemetry-instrumentation-urllib` | T | media | CLIENT (stdlib) |
| `opentelemetry-instrumentation-urllib3` | T | alta | CLIENT (base de requests) |
| `opentelemetry-instrumentation-aiohttp-client` | T,M | alta | CLIENT async |

## Databases / drivers

| Paquete | Signal | Madurez | Spans típicos |
|---------|--------|---------|----------------|
| `opentelemetry-instrumentation-psycopg2` | T,M | alta | CLIENT por query, `db.system=postgresql`, `db.statement` |
| `opentelemetry-instrumentation-psycopg` | T,M | alta | ídem para psycopg3 |
| `opentelemetry-instrumentation-pymysql` | T | alta | CLIENT por query, MySQL |
| `opentelemetry-instrumentation-sqlalchemy` | T | alta | CLIENT por sentencia SQL abstracta |
| `opentelemetry-instrumentation-asyncpg` | T | alta | CLIENT async PostgreSQL |
| `opentelemetry-instrumentation-redis` | T,M | alta | CLIENT por comando Redis |
| `opentelemetry-instrumentation-pymongo` | T | alta | CLIENT por operación Mongo |
| `opentelemetry-instrumentation-elasticsearch` | T | alta | CLIENT por query ES |

## Messaging / RPC

| Paquete | Signal | Madurez | Spans típicos |
|---------|--------|---------|----------------|
| `opentelemetry-instrumentation-kafka-python` | T | media | PRODUCER / CONSUMER con propagación por headers |
| `opentelemetry-instrumentation-confluent-kafka` | T | media | ídem para confluent-kafka |
| `opentelemetry-instrumentation-pika` | T | media | RabbitMQ |
| `opentelemetry-instrumentation-grpc` | T,M | alta | CLIENT y SERVER, propagación por metadata |
| `opentelemetry-instrumentation-celery` | T | alta | 1 span por task, propagación entre caller y worker |

## Infra / platform

| Paquete | Signal | Madurez | Qué hace |
|---------|--------|---------|---------|
| `opentelemetry-instrumentation-logging` | L | alta | Inyecta `trace_id` / `span_id` / `trace_flags` en cada LogRecord |
| `opentelemetry-instrumentation-botocore` | T | alta | 1 span CLIENT por llamada boto3/botocore |
| `opentelemetry-instrumentation-system-metrics` | M | media | CPU/memoria/disco/red como métricas |
| `opentelemetry-instrumentation-aws-lambda` | T | alta | SERVER por invocación Lambda |

## Cómo elegir qué instalar

1. Lista las **dependencias runtime** reales del servicio (`pip list`, `pyproject.toml`).
2. Para cada una, busca `opentelemetry-instrumentation-<nombre>` en PyPI o `opentelemetry-python-contrib`.
3. Instala solo los que tus dependencias usan — paquetes de más generan ruido y riesgo de monkey-patch inútil.
4. Con `opentelemetry-instrument` basta tenerlos instalados; se activan por entry points.

## Qué cubren en conjunto

Un servicio típico FastAPI + Postgres + Redis + llamadas HTTP outbound queda cubierto por:

```
opentelemetry-distro
opentelemetry-exporter-otlp
opentelemetry-instrumentation-fastapi
opentelemetry-instrumentation-psycopg2
opentelemetry-instrumentation-redis
opentelemetry-instrumentation-requests
opentelemetry-instrumentation-logging
```

Con esos 7 paquetes y `opentelemetry-instrument uvicorn app:app`, cubres el "80% gratis" del que habla la lección. El 20% restante son spans manuales de dominio (sección 8 de `theory/lesson.md`).
