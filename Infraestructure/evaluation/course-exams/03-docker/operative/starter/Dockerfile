# Starter Dockerfile — DELIBERADAMENTE DEFICIENTE.
# Tu trabajo es reescribirlo en operative/solution/Dockerfile.
# Problemas intencionales:
#   - Base image pesada y por tag mutable (:latest).
#   - COPY . . antes de instalar deps (rompe caché).
#   - Un solo stage: toolchain de build queda en runtime.
#   - Corre como root.
#   - Usa ARG para inyectar un token (anti-patrón: queda en history).
#   - CMD en forma shell (rompe señales a PID 1).
#   - Sin healthcheck ni labels OCI.

FROM python:latest

ARG GH_TOKEN
ENV PIP_INDEX_URL=https://x-access-token:${GH_TOKEN}@pypi.internal.acme.local/simple

WORKDIR /app
COPY . .

RUN apt-get update && apt-get install -y gcc build-essential curl
RUN pip install -r requirements.txt

EXPOSE 8000
CMD uvicorn app.main:app --host 0.0.0.0 --port 8000
