# Capstone — Etapa 4: Dockerización + Compose para desarrollo

> Stage 4 del proyecto integrador (FastAPI + PostgreSQL). Construye una imagen OCI reproducible y una topología local con Docker Compose que incluye app, base de datos y un collector OpenTelemetry opcional.

## 1. Resumen de la etapa

- **Objetivo.** Empaquetar el servicio FastAPI en una imagen OCI minimalista, no-root, con healthcheck honesto; y orquestar localmente app + Postgres (+ collector opcional) con hot-reload para desarrollo.
- **Delta respecto a la etapa 3.** La CI ya corre lint/test/SAST/SCA/secret-scan. Aquí añadimos **artefacto**: `Dockerfile` multi-stage y `docker-compose.yml` reproducibles. No tocamos pipeline todavía (eso es etapa 5).
- **Fuera de scope.** Firma de imágenes, SBOM, container scan en CI, push a registry remoto, Helm, Kubernetes, observabilidad completa. Todo eso llega en etapas 5, 8–11.

## 2. Arquitectura al cierre de esta etapa

```
   developer host
   ┌──────────────────────────────────────────────────────────────┐
   │  docker compose up                                           │
   │                                                              │
   │  ┌──────────────┐  5432   ┌──────────────┐                   │
   │  │  app (8000)  │────────▶│ db postgres  │                   │
   │  │  FastAPI     │         │  :16-alpine  │                   │
   │  │  non-root    │         └──────────────┘                   │
   │  │  /healthz    │                                            │
   │  └──────┬───────┘                                            │
   │         │ 4318 (OTLP/HTTP)                                   │
   │         ▼                                                    │
   │  ┌──────────────┐   (profile: otel, opcional)                │
   │  │ otel-collector│                                           │
   │  │ debug exporter│                                           │
   │  └──────────────┘                                            │
   └──────────────────────────────────────────────────────────────┘
```

- **Entra:** HTTP en `localhost:8000`.
- **Sale:** Traces OTLP a `otel-collector:4318` cuando el perfil `otel` está activo.
- **Almacena:** volumen nombrado `pgdata` para persistencia local.
- **Recursos:** 3 servicios Compose, 1 volumen, 1 red bridge por defecto.

## 3. Prerrequisitos verificados

Checklist de outputs de etapas 1–3 que esta etapa consume:

- [ ] Etapa 1: paquete Python `app/` con endpoint `GET /healthz` que retorna `200` cuando la app y la conexión a DB están sanas.
- [ ] Etapa 1: `requirements.txt` o `pyproject.toml` con dependencias congeladas.
- [ ] Etapa 2: tags SemVer; `VERSION` o derivado de tags para la etiqueta de imagen (`app:0.y.z` o `app:dev`).
- [ ] Etapa 3: pipeline CI verde (lint, test, SAST, SCA, secret-scan) — no se modifica aquí.

Si cualquiera falta, cerrar la etapa correspondiente antes de continuar.

## 4. Implementación guiada

### 4.1. `Dockerfile` multi-stage

- Builder con `python:3.12-slim`, instala dependencias en un venv y produce wheels.
- Runtime con `gcr.io/distroless/python3-debian12:nonroot` (alternativa Chainguard: `cgr.dev/chainguard/python`), UID `10001`, honra `$PORT` (default `8000`).
- `HEALTHCHECK` HTTP contra `/healthz` cada 30s.

Ver [`Dockerfile`](./Dockerfile).

### 4.2. `.dockerignore`

Excluye `.git`, `.venv`, caches, tests pesados y archivos locales. Ver [`.dockerignore`](./.dockerignore).

### 4.3. `docker-compose.yml` + `docker-compose.override.yml`

- `app`: construye desde el Dockerfile; env `DATABASE_URL`, `PORT`, `OTEL_EXPORTER_OTLP_ENDPOINT`.
- `db`: `postgres:16-alpine`; credenciales dummy (`fake-password`); volumen `pgdata`.
- `otel-collector`: `otel/opentelemetry-collector-contrib:latest` detrás del perfil `otel` (no arranca por defecto).
- `override.yml`: monta `./app` como bind, activa `--reload`, expone 8000 y 5432 al host.

Ver [`docker-compose.yml`](./docker-compose.yml) y [`docker-compose.override.yml`](./docker-compose.override.yml).

### 4.4. Endpoint `/healthz`

Contrato documentado en [`app/healthz.md`](./app/healthz.md). La probe interna del contenedor hace `GET /healthz`; el Dockerfile usa `python -c "urllib..."` para no exigir `curl` en la imagen final.

### 4.5. Comandos de verificación

```bash
# Build local
docker build -t capstone-app:dev .

# Up (sin collector)
docker compose up -d --build
docker compose ps
docker compose exec app python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/healthz').status)"

# Up con collector
docker compose --profile otel up -d --build

# Logs
docker compose logs -f app

# Down + volúmenes
docker compose down -v
```

**Por qué cada decisión.** Multi-stage separa toolchain de runtime (imagen final más chica y con menos superficie). Distroless/Chainguard elimina shell y apt para reducir CVEs. UID fijo `10001` facilita policies en Kubernetes más adelante. `HEALTHCHECK` nativo de Docker alimenta restart policies y, en etapa 7, los probes de ECS/Cloud Run. El collector opcional ensaya el patrón OTEL antes de la etapa 11.

## 5. Actividades del estudiante

| ID | Tipo | Título |
|----|------|--------|
| `cap-04-01-build-and-compose-up` | guided-lab | Construir la imagen, levantar Compose, verificar `/healthz` y limpiar |

Ver [`activities/01-build-and-compose-up/`](./activities/01-build-and-compose-up/).

## 6. Entregables

- `Dockerfile` multi-stage reproducible.
- `.dockerignore` que recorta contexto.
- `docker-compose.yml` + `docker-compose.override.yml` listos para `docker compose up`.
- Captura o salida de `docker compose ps` con los 2 servicios (`app`, `db`) `healthy`.
- Captura de `GET /healthz → 200`.
- `activities/01-build-and-compose-up/` ejecutada y validada.

## 7. Pruebas y criterios de aceptación

- `docker build .` termina en verde con imagen no-root (`docker inspect --format '{{.Config.User}}' capstone-app:dev` = `10001` o `nonroot`).
- `docker compose up -d` deja `app` y `db` en estado `healthy` en < 60 s.
- `curl -fsS http://localhost:8000/healthz` responde `200`.
- La imagen final no contiene toolchain (sin `gcc`, sin `pip`).
- `bash activities/01-build-and-compose-up/tests/validate.sh` imprime `RESULT: PASS`.
- Ninguna credencial real en Git (`grep -R "password" .` solo muestra `fake-password`).

## 8. Costos y limpieza

- Costo: **$0**. Todo corre local.
- Limpieza completa:

```bash
docker compose down -v --remove-orphans
docker image rm capstone-app:dev || true
docker builder prune -f
```

- Guard-rail: `docker system df` antes y después para detectar fuga de capas.

## 9. Riesgos y mitigaciones

1. **La imagen final rompe por falta de libs del sistema.** Distroless no trae `libssl` genérico. Mitigación: validar con `docker run --rm capstone-app:dev python -c "import ssl, psycopg"` antes de dar por buena la build.
2. **Hot-reload no detecta cambios en macOS.** Bind mounts cross-FS son lentos. Mitigación: usar `delegated` en el override o `watchexec` dentro del contenedor; documentado como hint progresivo.
3. **Puerto 5432 ya ocupado por un Postgres local.** Mitigación: el override solo expone `5432:5432` si no existe conflicto; hint: cambiar a `55432:5432`.

Hints progresivos para quien se atasca (sin dar la solución): revisar logs con `docker compose logs app`, inspeccionar healthcheck con `docker inspect`, comparar `.dockerignore` con el contexto enviado (`docker build --progress=plain`).

## 10. Puente con la siguiente etapa

- Habilita: imagen construible y healthcheck confiable que la etapa 5 escaneará y firmará.
- Dejar corriendo: nada en segundo plano; la etapa 5 vive en CI.
- Cliffhanger: *¿cómo garantizamos que la imagen que corrimos en local es exactamente la que llega a producción, y que nadie insertó un binario entre medias?* La próxima etapa responde con SBOM + firma Sigstore + attestations SLSA.

## Archivos de esta etapa

- [`Dockerfile`](./Dockerfile)
- [`.dockerignore`](./.dockerignore)
- [`docker-compose.yml`](./docker-compose.yml)
- [`docker-compose.override.yml`](./docker-compose.override.yml)
- [`app/healthz.md`](./app/healthz.md)
- [`activities/01-build-and-compose-up/`](./activities/01-build-and-compose-up/)
- [`resources/links.md`](./resources/links.md)
