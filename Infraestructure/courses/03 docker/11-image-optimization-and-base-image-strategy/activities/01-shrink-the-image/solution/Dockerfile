# syntax=docker/dockerfile:1
# Reference solution for dkr-11-01-shrink-the-image.
# Multi-stage: python-slim builder + distroless runtime.

FROM python:3.11-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.txt .
# distroless/python3-debian12 ships python 3.11 — match it exactly.
# --target installs packages flat into /install (no lib/pythonX.Y nesting).
RUN pip install --target=/install -r requirements.txt && \
    # drop pyc caches and dist-info to shrink
    find /install -type d -name '__pycache__' -prune -exec rm -rf {} + && \
    find /install -type d -name '*.dist-info' -prune -exec rm -rf {} +

FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app
# distroless python has /usr/lib/python3.11 on sys.path (not .../site-packages).
# Copy our deps there so `import cryptography` works.
COPY --from=builder /install /usr/lib/python3.11
COPY app.py /app/app.py
USER nonroot
# distroless python's ENTRYPOINT is python3; we just pass the script path.
CMD ["/app/app.py"]
