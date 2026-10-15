# dkr-08 — Compose para desarrollo

## Identificación

- **ID:** `dkr-08-compose-for-development`
- **Curso:** `docker`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `dkr-04-storage-volumes-bind-mounts-tmpfs`, `dkr-05-networking-basics`. Opcionalmente `dkr-06` para entender imágenes idiomáticas.

## Objetivo

Modelar **entornos locales reproducibles multi-servicio** con Docker Compose v2: declarar servicios, dependencias con healthchecks reales, perfiles para separar `dev` vs `test`, y override files para ajustar sin editar el archivo base. Al terminar, debes poder levantar y limpiar el stack del capstone (`app` + `postgres` + reverse proxy) con un solo comando y defender por qué Compose **no** es un orquestador de producción.

## Alcance

Este módulo cubre:

- `docker compose` v2 como **plugin oficial** de la CLI (reemplaza al binario legacy `docker-compose`).
- `compose.yaml` — nombre canónico; esquema de la Compose Specification.
- Modelo de proyecto: una network por proyecto, servicios resolubles por nombre DNS.
- `depends_on` en sus dos formas: *forma corta* (solo arranque) y *forma larga* con `condition: service_healthy` (espera a que el healthcheck esté `healthy`).
- `healthcheck`: `test`, `interval`, `timeout`, `retries`, `start_period`, `start_interval`.
- `profiles`: cómo mantener servicios opcionales (seeders, test runners) en el mismo archivo sin que arranquen por default.
- Override files: `compose.override.yaml` auto-cargado; `-f base.yaml -f override.yaml` para componer explícitamente.
- Variables de entorno: `.env` auto-cargado, interpolación `${VAR:?err}`, diferencia entre variables *de Compose* (interpolación en el YAML) y variables *del servicio* (`environment:` dentro del contenedor).
- Ciclo de vida: `up`, `up -d`, `up --build`, `down`, `down -v`, `logs -f`, `ps`, `exec`, `run --rm`.
- **Por qué Compose es para dev**: límites concretos frente a Kubernetes/ECS/Nomad (sin scheduling multi-host, sin self-healing real, sin rolling updates seguros, sin control de recursos a nivel cluster).

Lo que **no** cubre (vendrá después o en otros cursos):

- `docker swarm` / Compose en modo swarm — fuera de alcance, el programa salta directo a Kubernetes.
- Secretos de producción (vendrán en el curso de DevSecOps).
- Deploy multi-host — ver curso de Kubernetes.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones (~3 h de lectura + exploración).
- **`examples/`** — ejemplos reproducibles, cada uno con `compose.yaml` autocontenido:
  - `01-fastapi-postgres-compose/` — stack mínimo: FastAPI + Postgres en una red Compose.
  - `02-healthcheck-and-depends-on/` — demuestra la diferencia entre `depends_on` corto y `condition: service_healthy`.
  - `03-profiles-dev-vs-test/` — mismo `compose.yaml`, perfiles `dev` y `test` activados selectivamente.
- **`activities/`**:
  - `01-full-dev-stack/` — **guided-lab**. Construye el stack del capstone (app + Postgres + reverse proxy Caddy) desde un starter.
  - `02-flaky-startup-fix-with-healthcheck/` — **debug independiente**. Un stack arranca de forma intermitente; diagnostica y arregla sin consultar la solución.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué red crea Compose por proyecto y cómo resuelve DNS entre servicios. Diferenciar `depends_on` corto vs con `condition: service_healthy` y por qué el corto **no espera**. Enumerar al menos tres razones por las que Compose no reemplaza un orquestador en producción. |
| Operativa | Levantar un stack multi-servicio con `docker compose up -d`, verificar healthchecks (`docker compose ps`), inspeccionar logs (`logs -f service`), y limpiarlo íntegramente con `down -v`. Usar `profiles` y override files. |
| Arquitectónica | Diseñar un `compose.yaml` dev-friendly: bind mounts para hot-reload, volúmenes nombrados para datos de Postgres, healthchecks útiles, `.env` para config, perfiles para servicios opcionales. Justificar por qué el mismo archivo no sirve para producción. |

## Criterios de evaluación

- `activities/01-full-dev-stack/tests/validate.sh` pasa: el stack arranca, el healthcheck del app pasa, el reverse proxy responde `200` en `/`, Postgres acepta conexiones autenticadas, y `down -v` limpia volúmenes.
- `activities/02-flaky-startup-fix-with-healthcheck/tests/validate.sh` pasa: el stack arranca **determinísticamente** en 2 de 2 intentos consecutivos (el bug original fallaba ~50% del tiempo).
- Explicación escrita (preguntas de reflexión) sobre por qué Compose no sustituye un orquestador.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero sin consultar nada externo.
2. Reproduce los 3 ejemplos en orden. Observa `docker compose ps` tras cada `up`.
3. Haz la actividad `01-full-dev-stack/` siguiendo las instrucciones.
4. Haz la actividad `02-flaky-startup-fix-with-healthcheck/` **sin mirar `solution/`**. Si te atascas más de 30 min, lee las pistas; si te atascas 60 min, consulta la solución y escribe por qué no la viste.
5. Responde las preguntas de evaluación del final de la lección.

## Siguiente

→ `dkr-09-registries-tags-and-digests`: cómo publicar las imágenes que acabas de orquestar localmente, con qué tagging, y por qué en producción referenciamos por digest y no por tag.
