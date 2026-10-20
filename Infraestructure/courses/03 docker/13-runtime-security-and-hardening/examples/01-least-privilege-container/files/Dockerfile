# syntax=docker/dockerfile:1.6
FROM python:3.12-slim AS runtime

RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin app

WORKDIR /app
COPY --chown=app:app app.py /app/app.py

USER 10001:10001
EXPOSE 8000
ENTRYPOINT ["python", "-u", "/app/app.py"]
