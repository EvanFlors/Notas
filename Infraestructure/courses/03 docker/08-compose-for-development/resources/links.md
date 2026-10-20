# Recursos — dkr-08 Compose para desarrollo

> Enlaces revisados en octubre 2026. Prioriza siempre la documentación oficial.

## Documentación oficial

- [Compose Specification](https://github.com/compose-spec/compose-spec) — el esquema canónico que implementa `docker compose` v2 (y también Podman Compose).
- [Docker Compose overview](https://docs.docker.com/compose/) — guías introductorias y de referencia de la CLI.
- [Compose file reference](https://docs.docker.com/reference/compose-file/) — todas las claves YAML explicadas (services, networks, volumes, profiles, ...).
- [Migrate to Compose V2](https://docs.docker.com/compose/releases/migrate/) — por qué `docker-compose` v1 está deprecated y cómo migrar.
- [`depends_on` reference](https://docs.docker.com/reference/compose-file/services/#depends_on) — forma corta y larga con condiciones.
- [Healthcheck in Compose](https://docs.docker.com/reference/compose-file/services/#healthcheck) — todas las opciones (`interval`, `timeout`, `retries`, `start_period`, `start_interval`).
- [Profiles](https://docs.docker.com/compose/how-tos/profiles/) — modelo mental y casos de uso.
- [Environment variables precedence](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/) — crítico para no confundir `.env` con `env_file:`.
- [`docker compose` CLI reference](https://docs.docker.com/reference/cli/docker/compose/) — todos los subcomandos.

## Lecturas conceptuales

- [Why not Compose in production?](https://docs.docker.com/get-started/workshop/08_using_compose/) — el workshop oficial lo deja explícito.
- [The 12-factor app, factors III y X](https://12factor.net/config) — por qué separar config y entornos (relevante para `.env` y profiles).
- [Compose spec: project model](https://github.com/compose-spec/compose-spec/blob/main/spec.md#project-model) — qué es un *proyecto* y cómo se derivan prefijos/labels.

## Herramientas complementarias

- [`docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/) — imprime el YAML ya mergeado con overrides e interpolación resuelta. Imprescindible para debug.
- [`docker compose watch`](https://docs.docker.com/compose/how-tos/file-watch/) — sync de archivos sin reconstruir imagen (hot-reload declarativo). Útil para dev modernas.
- [dive](https://github.com/wagoodman/dive) — inspección de capas, útil si tu `build:` produce imágenes gordas.
- [Caddy server](https://caddyserver.com/docs/) — reverse proxy minimalista, excelente para dev stacks.

## Siguiente

→ `dkr-09-registries-tags-and-digests` para aprender a publicar las imágenes que acabas de orquestar.
