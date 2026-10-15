# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Deps primero -> capa estable, cacheable
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

# Exec form: uvicorn será PID 1 y recibirá SIGTERM directamente
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
