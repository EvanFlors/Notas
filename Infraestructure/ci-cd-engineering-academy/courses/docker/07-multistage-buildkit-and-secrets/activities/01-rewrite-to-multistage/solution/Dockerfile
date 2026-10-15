# syntax=docker/dockerfile:1

###############################################################################
# Stage 1: builder — toolchain + wheels compilados.
###############################################################################
FROM python:3.12 AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc make libpq-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt

###############################################################################
# Stage 2: runtime — slim, no toolchain.
###############################################################################
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd -r -u 1001 app

WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/*.whl \
 && rm -rf /wheels

COPY --chown=app:app app.py ./

USER app
EXPOSE 8000
CMD ["python", "app.py"]
