# Multistage Dockerfile for the checkout-api FastAPI sample.
# Builds locally with: docker build -t az04-canary:test .

# --- builder stage ---------------------------------------------------------
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

RUN pip install --prefix=/install \
      "fastapi==0.115.0" \
      "uvicorn[standard]==0.30.6"

# --- final stage -----------------------------------------------------------
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:${PATH}"

# Non-root user.
RUN groupadd --system app && useradd --system --gid app --no-create-home app

COPY --from=builder /install /install
COPY app /app/app

WORKDIR /app
USER app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
