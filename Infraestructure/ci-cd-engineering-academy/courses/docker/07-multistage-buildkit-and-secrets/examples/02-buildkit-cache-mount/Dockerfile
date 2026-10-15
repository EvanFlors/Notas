# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .

# Mount a BuildKit-managed cache directory at pip's download location.
# Wheels downloaded in a previous build are reused; the cache itself does
# NOT end up in the resulting image layer.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY app.py .

EXPOSE 8000
CMD ["python", "app.py"]
