# dkr-08-01 — Full dev stack (capstone)

## 1. Identificación

- **ID:** `dkr-08-01-full-dev-stack`
- **Tecnología:** docker
- **Módulo:** `08-compose-for-development`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir el **stack dev del capstone**: una app FastAPI que lee de Postgres, detrás de un reverse proxy **Caddy**. Es el mismo patrón que usarán los módulos siguientes (publicación de imágenes, pipeline en Actions). Compose declara los tres servicios en una red única del proyecto, con healthchecks reales y `depends_on` sobre los healthchecks.

## 3. Objetivos

- Modelar tres servicios (`api`, `db`, `proxy`) en un único `compose.yaml`.
- Usar `depends_on` con `condition: service_healthy` para encadenar arranques.
- Configurar un healthcheck para la app (`/health`) y para Postgres (`pg_isready`).
- Levantar el stack con `docker compose up -d --wait` y limpiarlo con `down -v`.
- Validar end-to-end: el reverse proxy debe responder `200` en `/` y en `/db`.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` y reproducido los 3 ejemplos.
- `docker` y `docker compose` v2 instalados.
- Puerto `8080` del host libre.
- Sin costos externos (todo local).

## 5. Instrucciones

### 5.1 Copiar el starter a /tmp

Trabajamos siempre en `/tmp` para no ensuciar el repo del curso.

```bash
BASE=/tmp/dkr-08-01-full-dev-stack
rm -rf "$BASE" && mkdir -p "$BASE"
cp -R starter/. "$BASE/"
cd "$BASE"
ls
# compose.yaml  app/  Caddyfile  README-notes.md
```

### 5.2 Leer `compose.yaml` del starter

El starter ya trae un `compose.yaml` **incompleto**: define los tres servicios pero le faltan piezas:

- `db` **no tiene healthcheck**.
- `api` usa `depends_on: - db` (forma corta) en vez de la larga con `condition: service_healthy`.
- `api` **no tiene** su propio healthcheck.
- `proxy` apunta a `api` pero no espera a que esté sano.

### 5.3 Tu tarea

Edita `compose.yaml` para:

1. Añadir `healthcheck` a `db` usando `pg_isready -U postgres` (interval 2s, retries 20, start_period 10s).
2. Añadir `healthcheck` a `api` que pegue `/health` con `curl -fsS` (interval 2s, retries 10, start_period 5s). Pista: `python:3.12-slim` no trae `curl`; o lo instalas (añadiendo `curl` al apt) **o** usas `python -c "import urllib.request;urllib.request.urlopen('http://localhost:8000/health').read()"` en el `test:`.
3. Cambiar `depends_on` de `api` a la forma larga: espera `db` `service_healthy`.
4. Añadir `depends_on` a `proxy`: espera `api` `service_healthy`.
5. Verificar que `proxy` publica el puerto `8080:80` del host, y que el `Caddyfile` apunta a `api:8000` (nombre DNS del servicio Compose).

### 5.4 Arrancar y validar

```bash
cd /tmp/dkr-08-01-full-dev-stack
docker compose up -d --build --wait --wait-timeout 120
docker compose ps
curl -fsS http://localhost:8080/
curl -fsS http://localhost:8080/db
```

Los tres servicios deben aparecer `(healthy)`. El reverse proxy debe devolver JSON desde `api`.

### 5.5 Ejecutar el validador

Desde el directorio del módulo (donde está este README):

```bash
bash tests/validate.sh
```

Debe reportar todos los checks en OK.

## 6. Resultado esperado

- `compose.yaml` final con los 3 servicios saludables, encadenados por healthchecks.
- `curl http://localhost:8080/` devuelve `{"status":"ok", ...}`.
- `curl http://localhost:8080/db` devuelve `{"db":"ok","result":1}`.
- `docker compose ps` muestra los 3 contenedores `Up ... (healthy)`.
- `docker compose down -v` limpia todo (contenedores, red, volumen).

## 7. Criterios de aceptación

- **Funcional**: `tests/validate.sh` sale con 0 y los dos endpoints responden `200`.
- **Correctness**: `db` tiene healthcheck real; `api` espera a `db` sano; `proxy` espera a `api` sano.
- **Reproducibilidad**: dos ejecuciones consecutivas (`down -v && up --wait`) deben pasar las dos.
- **Limpieza**: tras `down -v`, no quedan contenedores, redes ni volúmenes del proyecto.
- **Sin secretos**: la password de Postgres es `dev` (dummy), no se usan credenciales reales.

## 8. Validación

```bash
bash tests/validate.sh
```

El script:
1. Verifica que `docker` y `docker compose` v2 estén instalados (si no, hace `SKIP`).
2. Copia el `compose.yaml` **del alumno** (desde `/tmp/dkr-08-01-full-dev-stack`) y lo levanta.
3. Espera a que todos los servicios estén `healthy` (hasta 120 s).
4. Hace `curl` a los endpoints vía el proxy.
5. Comprueba vía `docker inspect` que `db` tiene healthcheck declarado.
6. Limpia con `down -v`.

## 9. Preguntas de reflexión

- ¿Qué pasa si quitas el healthcheck de `db` y mantienes `condition: service_healthy` en `api`? Pruébalo (`docker compose up` debería fallar explícitamente).
- Caddy resuelve `api:8000`. ¿De dónde sale ese `api`? ¿Qué devuelve `docker compose exec proxy getent hosts api`?
- ¿Qué pasa si cambias el `start_period` de Postgres a `0s`? ¿Qué garantiza en realidad?
- Si querés levantar solo `db` (p. ej. para conectar un cliente SQL del host), ¿cómo lo haces con Compose?
- ¿Por qué este `compose.yaml` **no** servirá en producción? Enumera tres razones concretas de la sección 12 de la lección.

## 10. Extensiones

1. Añade un servicio `pgadmin` detrás de un perfil `admin`. Solo arranca con `--profile admin`.
2. Mueve el password de Postgres a un `.env` y usa `${POSTGRES_PASSWORD:?required}` en el YAML.
3. Añade un `compose.override.yaml` que exponga el puerto `5432` del host **solo en dev** (para conectar DBeaver). El `compose.yaml` base no debe exponerlo.
4. Añade un segundo endpoint `/items` que persista en una tabla; añade un servicio `seeder` detrás de perfil `dev` que la pueble.

## 11. Limpieza

```bash
cd /tmp/dkr-08-01-full-dev-stack
docker compose down -v --remove-orphans
rm -rf /tmp/dkr-08-01-full-dev-stack
```
