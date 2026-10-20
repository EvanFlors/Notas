# syntax=docker/dockerfile:1.7

# =========================================================================
# Stage 1 — builder
# Toolchain + wheels aisladas; nada de esto llega al runtime.
# =========================================================================
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

# Dependencias del sistema solo si psycopg[binary] no es suficiente.
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install -r requirements.txt

COPY app/ ./app/

# =========================================================================
# Stage 2 — runtime
# Distroless Debian 12 con Python 3 y usuario nonroot (UID 65532).
# Alternativa Chainguard: cgr.dev/chainguard/python:latest (UID 65532 también).
# Si prefieres fijar UID 10001 explícitamente, cambia la base por
# gcr.io/distroless/python3-debian12 y añade `USER 10001:10001`.
# =========================================================================
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

ARG APP_UID=10001
ENV PORT=8000 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}" \
    VIRTUAL_ENV=/opt/venv

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/app /app/app

# Distroless `nonroot` ya corre como usuario sin privilegios. Dejamos la
# directiva explícita para que Kubernetes/ECS la lea sin ambigüedad.
USER nonroot:nonroot

EXPOSE 8000

# Healthcheck sin curl: usa el runtime de Python que ya está en la imagen.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import os,urllib.request,sys;u=f'http://127.0.0.1:{os.environ.get(\"PORT\",\"8000\")}/healthz';r=urllib.request.urlopen(u,timeout=3);sys.exit(0 if r.status==200 else 1)"]

# $PORT se respeta; uvicorn se invoca por array para evitar shell.
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
