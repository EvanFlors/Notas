# Ejemplo 01 — Dockerfile mínimo para una app FastAPI

## Concepto que demuestra

El Dockerfile mínimo correcto para una app Python/FastAPI: base `python:3.12-slim`,
orden `deps-primero`, usuario no-root, `CMD` en exec form, `EXPOSE` documental,
`HEALTHCHECK`.

## Contexto

Primera imagen propia. Objetivo: *leer* y *construir* un Dockerfile real, y
observar las capas con `docker history`.

## Objetivo

Al terminar, podrás responder:
- ¿Qué capas se crean y cuánto pesa cada una?
- ¿Qué pasa si cambio solo el código (y qué si cambio `requirements.txt`)?
- ¿Por qué `USER appuser` y qué protege?
- ¿Por qué `CMD ["uvicorn", ...]` en exec form?

## Prerrequisitos

- Docker 24+ (`docker --version`).
- `curl` para probar el endpoint HTTP.
- Puerto 8000 libre en el host.

## Archivos del ejemplo

Están en `files/`:

```
files/
├── Dockerfile
├── .dockerignore
├── requirements.txt
└── app/
    ├── __init__.py
    └── main.py
```

### `files/Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Deps primero -> capa estable
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Código después
COPY app ./app

# Usuario no-root
RUN groupadd --system --gid 10001 appuser \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home appuser
USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/healthz').status==200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Traducción línea por línea:**

- `# syntax=docker/dockerfile:1` — habilita features modernos de BuildKit.
- `FROM python:3.12-slim` — base Debian minimal con CPython 3.12. En prod se pin por digest.
- `ENV PYTHON...` — `PYTHONUNBUFFERED=1` es **crítico** para ver logs en vivo; el resto reduce ruido.
- `WORKDIR /app` — cwd para instrucciones siguientes y para el runtime.
- `COPY requirements.txt ./` + `RUN pip install ...` — deps en una capa aparte, que solo se invalida cuando cambia `requirements.txt`.
- `COPY app ./app` — código en una capa posterior. Un cambio en código **no** invalida la capa de pip.
- `groupadd` + `useradd` + `USER` — crea un usuario de sistema UID 10001 y cambia a él. A partir de aquí todo corre como no-root.
- `EXPOSE 8000` — documental; no publica el puerto.
- `HEALTHCHECK` — Docker marca el contenedor `healthy` / `unhealthy` según responda `/healthz`.
- `CMD [...]` — **exec form**: `uvicorn` será PID 1 y recibirá `SIGTERM` directamente al `docker stop`.

### `files/.dockerignore`

```
.git/
__pycache__/
*.pyc
.pytest_cache/
.venv/
venv/
.env
.env.*
.vscode/
.idea/
tests/
docs/
```

### `files/requirements.txt`

```
fastapi==0.115.0
uvicorn[standard]==0.30.6
```

### `files/app/main.py`

```python
from fastapi import FastAPI
import os

app = FastAPI(title="fastapi-mini")

@app.get("/")
def root():
    return {"service": "fastapi-mini", "pid": os.getpid(), "uid": os.getuid()}

@app.get("/healthz")
def healthz():
    return {"status": "ok"}
```

## Ejecución

```bash
# Scratch area para no ensuciar
cd /tmp
rm -rf dkr-03-ex-01 && mkdir dkr-03-ex-01 && cd dkr-03-ex-01
cp -r /path/to/examples/01-dockerfile-python-app/files/. .

# Build
docker build -t fastapi-mini:v1 .

# Historial de capas
docker history --no-trunc fastapi-mini:v1

# Inspección del config
docker image inspect fastapi-mini:v1 --format \
  'User={{.Config.User}} Cmd={{.Config.Cmd}} Entrypoint={{.Config.Entrypoint}} ExposedPorts={{.Config.ExposedPorts}}'

# Run
docker run -d --name fm --rm -p 8000:8000 fastapi-mini:v1
sleep 2
curl -s http://localhost:8000/
curl -s http://localhost:8000/healthz

# UID dentro del contenedor
docker exec fm id

# Stop (debería terminar en < 2 s porque uvicorn es PID 1 y recibe SIGTERM)
time docker stop fm
```

## Resultado esperado

- `docker build` termina sin errores.
- `docker history` muestra ~5–7 capas con `pip install` como la más pesada (~40 MB).
- `curl /` responde `{"service":"fastapi-mini","pid":1,"uid":10001}` — PID 1 y UID 10001 confirman exec form + USER no-root.
- `curl /healthz` responde `{"status":"ok"}`.
- `docker ps` muestra `(healthy)` tras ~90 s (3 checks × 30 s).
- `docker stop fm` termina en < 2 s (uvicorn hace shutdown ordenado).

## Interpretación

- **PID 1 = tu proceso**: posible gracias a exec form. Shell form daría PID 1 = `/bin/sh`.
- **UID = 10001**: `USER 10001:10001` lo garantizó. Si fuera root (UID 0), un RCE sería "root dentro del contenedor" — un escalón menos de defensa.
- **El `pip install` es la capa más pesada**: por eso se aisla; cambiar el código no la invalida.
- **El healthcheck usa Python** (no `curl`): la imagen slim no trae `curl` y añadirlo solo para el healthcheck añade ~10 MB. Usar Python nativo es gratis.

## Errores frecuentes

- **`curl: (7) Failed to connect to localhost port 8000`** — olvidaste `-p 8000:8000` en `docker run`. `EXPOSE` solo documenta.
- **`docker stop` tarda 10 s** — tu `CMD` está en shell form (`CMD uvicorn ...`). Cambia a exec form.
- **`id` dentro del contenedor dice `uid=0`** — olvidaste `USER` o lo pusiste después del `CMD` (debe ir antes).
- **`pip install` se re-ejecuta en cada build** — tu `.dockerignore` falta o `COPY . .` está antes de `COPY requirements.txt .`.

## Relación con escenarios reales

Este Dockerfile es el **esqueleto** de cualquier app Python en producción:
`dkr-06` lo refina (caché), `dkr-07` lo convierte en multi-stage, `dkr-09` lo publica,
`dkr-13` lo endurece, `dkr-14` lo firma. La estructura no cambia; se añade.

## Limpieza

```bash
docker stop fm 2>/dev/null || true
docker rmi fastapi-mini:v1 2>/dev/null || true
rm -rf /tmp/dkr-03-ex-01
```
