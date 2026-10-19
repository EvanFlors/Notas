# Multi-stage, slim, non-root. Buildable with `docker build .` locally.
# Honors $PORT so the same image runs under `docker run` and under Cloud Run.
FROM python:3.12-slim-bookworm AS deps
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim-bookworm
WORKDIR /app
# Copy site-packages from the deps stage to keep the final image small.
COPY --from=deps /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin
COPY main.py .

# Non-root user — Cloud Run also runs non-root by default; align locally.
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
USER 10001

ENV PORT=8080
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
