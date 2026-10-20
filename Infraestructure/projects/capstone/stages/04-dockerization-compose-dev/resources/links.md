# Recursos — Etapa 4 (Dockerización + Compose dev)

## Referencias oficiales

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Compose Specification](https://github.com/compose-spec/compose-spec/blob/main/spec.md)
- [Compose: profiles](https://docs.docker.com/compose/profiles/)
- [Compose: healthcheck](https://docs.docker.com/reference/compose-file/services/#healthcheck)
- [`HEALTHCHECK` en Dockerfile](https://docs.docker.com/reference/dockerfile/#healthcheck)
- [`.dockerignore`](https://docs.docker.com/build/building/context/#dockerignore-files)

## Imágenes base

- [Distroless images (Google)](https://github.com/GoogleContainerTools/distroless)
- [Chainguard Images](https://images.chainguard.dev/)
- [`python:3.12-slim` tags](https://hub.docker.com/_/python)
- [`postgres` official image](https://hub.docker.com/_/postgres)
- [OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib)

## Buenas prácticas

- [OWASP Docker Top 10](https://github.com/OWASP/Docker-Security)
- [Snyk — 10 best practices for Python Docker](https://snyk.io/blog/best-practices-containerizing-python-docker/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

## Lectura complementaria

- *Container Security* — Liz Rice (O'Reilly), capítulos 2 y 6.
- [Why rootless containers matter (Red Hat)](https://www.redhat.com/en/blog/why-rootless-containers-matter)
- [12-factor: Dev/prod parity](https://12factor.net/dev-prod-parity)
