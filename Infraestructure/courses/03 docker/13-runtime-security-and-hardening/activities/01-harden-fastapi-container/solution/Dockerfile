# syntax=docker/dockerfile:1.6
FROM python:3.12-slim

RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin app

WORKDIR /app

COPY --chown=app:app app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY --chown=app:app app/ /app/

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
  CMD python -c "import urllib.request,sys; r=urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2); sys.exit(0 if r.status==200 else 1)" || exit 1

ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
