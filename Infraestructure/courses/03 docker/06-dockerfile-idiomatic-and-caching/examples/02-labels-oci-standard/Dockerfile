# syntax=docker/dockerfile:1
FROM alpine:3.20

ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG APP_VERSION=0.1.0

LABEL org.opencontainers.image.title="labels-demo" \
      org.opencontainers.image.description="Minimal image demonstrating OCI standard annotations" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.authors="CI/CD Academy <academy@example.com>" \
      org.opencontainers.image.source="https://github.com/example/ci-cd-engineering-academy" \
      org.opencontainers.image.documentation="https://github.com/example/ci-cd-engineering-academy#readme" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.vendor="CI/CD Academy"

CMD ["sh", "-c", "echo 'labels-demo running'; sleep 3600"]
